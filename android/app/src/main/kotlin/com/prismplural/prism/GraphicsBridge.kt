package com.prismplural.prism

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.view.Display
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Graphics & Performance support for Prism's adaptive graphics engine:
 *  - chooses the Flutter renderer at launch (with automatic rollback if a
 *    launch never draws its first frame),
 *  - asks the display for a refresh rate,
 *  - reports memory class, low-RAM status, thermal state and battery saver.
 */
object GraphicsBridge {
    private const val CHANNEL = "prism/graphics"
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY_RENDERER = "flutter.prism.graphics.renderer"
    private const val GUARD_PREFS = "prism_graphics"
    private const val KEY_PENDING = "renderer_pending"

    /** The renderer this launch actually uses. */
    var activeRenderer: String = "auto"
        private set

    /**
     * Called before FlutterFragmentActivity.onCreate: Flutter reads its
     * shell arguments from the launch intent. A non-default renderer that
     * didn't reach its first frame last time is rolled back to automatic.
     */
    fun applyRenderer(activity: Activity) {
        val flutterPrefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val guard = activity.getSharedPreferences(GUARD_PREFS, Context.MODE_PRIVATE)
        var mode = flutterPrefs.getString(KEY_RENDERER, "auto") ?: "auto"
        if (mode != "auto" && guard.getBoolean(KEY_PENDING, false)) {
            // The last launch with this renderer never rendered: go back.
            mode = "auto"
            flutterPrefs.edit().putString(KEY_RENDERER, "auto").apply()
            guard.edit().putBoolean(KEY_PENDING, false).apply()
        }
        val intent: Intent = activity.intent ?: Intent()
        when (mode) {
            "compatibility" -> intent.putExtra("enable-impeller", false)
            "software" -> intent.putExtra("enable-software-rendering", true)
        }
        if (mode != "auto") guard.edit().putBoolean(KEY_PENDING, true).commit()
        activity.intent = intent
        activeRenderer = mode
    }

    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> result.success(info(activity))
                "setFrameRate" -> {
                    setFrameRate(activity, call.argument<Int>("fps") ?: 0)
                    result.success(null)
                }
                "markRendered" -> {
                    activity.getSharedPreferences(GUARD_PREFS, Context.MODE_PRIVATE)
                        .edit().putBoolean(KEY_PENDING, false).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun display(activity: Activity): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) activity.display
        else activity.windowManager.defaultDisplay

    private fun info(activity: Activity): Map<String, Any?> {
        val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mem = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        val rates = mutableSetOf<Float>()
        val d = display(activity)
        if (d != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val cur = d.mode
            for (m in d.supportedModes) {
                if (m.physicalWidth == cur.physicalWidth && m.physicalHeight == cur.physicalHeight) {
                    rates.add(m.refreshRate)
                }
            }
        } else if (d != null) {
            rates.add(d.refreshRate)
        }
        val thermal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) pm.currentThermalStatus else 0
        return mapOf(
            "lowRam" to am.isLowRamDevice,
            "memoryClass" to am.memoryClass,
            "totalRamMb" to (mem.totalMem / (1024 * 1024)),
            "refreshRates" to rates.map { it.toDouble() },
            "thermal" to thermal,
            "powerSave" to pm.isPowerSaveMode,
            "renderer" to activeRenderer,
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    /**
     * Picks the supported display mode (same resolution) whose refresh
     * rate is closest to [fps]; 0 returns control to the system.
     */
    private fun setFrameRate(activity: Activity, fps: Int) {
        val d = display(activity) ?: return
        activity.runOnUiThread {
            val attrs = activity.window.attributes
            if (fps <= 0) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) attrs.preferredDisplayModeId = 0
                attrs.preferredRefreshRate = 0f
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val cur = d.mode
                val best = d.supportedModes
                    .filter { it.physicalWidth == cur.physicalWidth && it.physicalHeight == cur.physicalHeight }
                    .minByOrNull { kotlin.math.abs(it.refreshRate - fps) }
                if (best != null) attrs.preferredDisplayModeId = best.modeId
                attrs.preferredRefreshRate = fps.toFloat()
            } else {
                attrs.preferredRefreshRate = fps.toFloat()
            }
            activity.window.attributes = attrs
        }
    }
}
