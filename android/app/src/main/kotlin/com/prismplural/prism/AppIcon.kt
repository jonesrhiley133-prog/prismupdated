package com.prismplural.prism

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

/**
 * Switchable launcher icons. Each preset is an activity-alias
 * (".Launcher<Name>") pointing at MainActivity; exactly one is enabled.
 */
object AppIcon {
    val ids = listOf(
        "classic", "nebula", "aurora", "halo", "lunar", "ember", "abyss", "bloom", "void", "spectrum", "frost", "twilight", "verdant", "starlight", "solstice",
        "eclipse", "opal", "obsidian", "ultraviolet", "tide", "constellation", "facets", "moons", "chrysalis", "headspace", "harmony", "garden", "reflection", "murmuration", "threads", "lanterns", "chorus",
        "original", "monoBlack", "monoWhite", "outline", "softMinimal", "glass", "frosted", "matte", "chrome", "iridescent", "galactic", "nebula2", "lunar2", "solar", "constellation2", "saturn", "stardust", "cosmicCrystal", "midnight", "aurora2", "cyberpunk", "holographic", "pixel", "frutigerAero", "y2k", "circuit", "neon", "retroComputer", "digitalGlass", "futuristic", "cottagecore", "botanical", "mushroom", "forest", "ocean", "cloud", "knitted", "wooden", "floral", "rainyWindow", "watercolor", "sketchbook", "scrapbook", "gothic", "grunge", "punk", "artDeco", "victorian", "stainedGlass", "paperCutout", "kawaii", "pastel", "plush", "candy", "ribbon", "notebook", "music", "arcade", "dreamcore", "fairycore",
    )

    private fun component(context: Context, id: String) =
        ComponentName(context.packageName, "com.prismplural.prism.Launcher" + id.replaceFirstChar { it.uppercase() })

    private fun isEnabled(context: Context, id: String): Boolean =
        when (context.packageManager.getComponentEnabledSetting(component(context, id))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> id == "classic"
            else -> false
        }

    fun current(context: Context): String = ids.firstOrNull { isEnabled(context, it) } ?: "classic"

    /** Enables [id] first, then disables the others, so there is never a moment with no icon. */
    fun set(context: Context, id: String): Boolean {
        if (id !in ids) return false
        val pm = context.packageManager
        pm.setComponentEnabledSetting(
            component(context, id),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        // Only touch aliases that are actually on: with 90+ designs, turning
        // every other one off on each switch would be needlessly slow.
        for (other in ids) {
            if (other == id || !isEnabled(context, other)) continue
            pm.setComponentEnabledSetting(
                component(context, other),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        return true
    }

    /**
     * Refreshes the icon of Prism's pinned shortcut (custom or seasonal)
     * without asking anything; does nothing if it was never pinned.
     */
    fun updatePinnedShortcut(context: Context, png: ByteArray, label: String): Boolean {
        val bitmap = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return false
        val pinned = ShortcutManagerCompat.getShortcuts(context, ShortcutManagerCompat.FLAG_MATCH_PINNED)
            .any { it.id == "prism_custom_icon" }
        if (!pinned) return false
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_MAIN).setClassName(context.packageName, "com.prismplural.prism.MainActivity")
        launch.action = Intent.ACTION_MAIN
        val info = ShortcutInfoCompat.Builder(context, "prism_custom_icon")
            .setShortLabel(label)
            .setIcon(IconCompat.createWithAdaptiveBitmap(bitmap))
            .setIntent(launch)
            .build()
        return ShortcutManagerCompat.updateShortcuts(context, listOf(info))
    }

    /**
     * Custom icons: launchers can only switch between icons built into the
     * app, so a custom design is added as a pinned home-screen shortcut
     * (Android shows a confirmation). Updating keeps the same shortcut.
     */
    fun pinCustomShortcut(context: Context, png: ByteArray, label: String): Boolean {
        val bitmap = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return false
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_MAIN).setClassName(context.packageName, "com.prismplural.prism.MainActivity")
        launch.action = Intent.ACTION_MAIN
        val info = ShortcutInfoCompat.Builder(context, "prism_custom_icon")
            .setShortLabel(label)
            .setIcon(IconCompat.createWithAdaptiveBitmap(bitmap))
            .setIntent(launch)
            .build()
        // Refresh an already-pinned shortcut's icon, then ask to pin (no-op if pinned).
        try {
            ShortcutManagerCompat.updateShortcuts(context, listOf(info))
        } catch (_: Exception) {
        }
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(context)) return false
        return ShortcutManagerCompat.requestPinShortcut(context, info, null)
    }
}
