package com.prismplural.prism

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.os.Build
import android.util.Base64
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Builds and posts Prism's persistent "who is fronting" notification.
 *
 * The Flutter side computes a snapshot (texts, icon, colours, actions …) and
 * hands it over; this object keeps the latest one in SharedPreferences so the
 * foreground service and the boot receiver can rebuild the exact same
 * notification without the Flutter engine. Everything is posted under one
 * fixed id, so updates replace the notification instead of stacking.
 */
object FrontingStatus {
    const val NOTIFICATION_ID = 7314
    const val CHANNEL = "fronting_status"
    const val CHANNEL_DND = "fronting_status_dnd"
    const val ACTION_EXTRA = "prism_fronting_action"
    const val ACTION_DISMISSED = "com.prismplural.prism.FRONTING_STATUS_DISMISSED"
    private const val PREFS = "prism_fronting_status"
    private const val KEY_SNAPSHOT = "snapshot"
    private const val KEY_DISMISSED = "dismissed"

    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveSnapshot(context: Context, json: JSONObject) {
        prefs(context).edit().putString(KEY_SNAPSHOT, json.toString()).putBoolean(KEY_DISMISSED, false).apply()
    }

    fun loadSnapshot(context: Context): JSONObject? =
        prefs(context).getString(KEY_SNAPSHOT, null)?.let {
            try { JSONObject(it) } catch (_: Exception) { null }
        }

    fun clearSnapshot(context: Context) {
        prefs(context).edit().remove(KEY_SNAPSHOT).apply()
    }

    fun markDismissed(context: Context) {
        prefs(context).edit().putBoolean(KEY_DISMISSED, true).apply()
    }

    fun wasDismissed(context: Context) = prefs(context).getBoolean(KEY_DISMISSED, false)

    fun ensureChannels(context: Context, name: String, dndName: String, description: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        val normal = NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_LOW).apply {
            this.description = description
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        val dnd = NotificationChannel(CHANNEL_DND, dndName, NotificationManager.IMPORTANCE_LOW).apply {
            this.description = description
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        nm.createNotificationChannels(listOf(normal, dnd))
    }

    private fun smallIconRes(key: String?): Int = when (key) {
        "heart" -> R.drawable.ic_stat_fronting_heart
        "star" -> R.drawable.ic_stat_fronting_star
        "moon" -> R.drawable.ic_stat_fronting_moon
        "sparkle" -> R.drawable.ic_stat_fronting_sparkle
        "leaf" -> R.drawable.ic_stat_fronting_leaf
        "group" -> R.drawable.ic_stat_fronting_group
        else -> R.drawable.ic_stat_fronting_person
    }

    private fun circle(src: Bitmap): Bitmap {
        val size = minOf(src.width, src.height)
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        val left = (src.width - size) / 2
        val top = (src.height - size) / 2
        canvas.drawBitmap(src, Rect(left, top, left + size, top + size), Rect(0, 0, size, size), paint)
        return out
    }

    private fun largeIcon(json: JSONObject): Bitmap? {
        val b64 = json.optString("largeIcon", "")
        if (b64.isEmpty()) return null
        return try {
            val bytes = Base64.decode(b64, Base64.DEFAULT)
            val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
            if (json.optBoolean("largeIconCircle", false)) circle(bmp) else bmp
        } catch (_: Exception) {
            null
        }
    }

    private fun launchIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(ACTION_EXTRA, action)
        }
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun strings(arr: JSONArray?): List<String> =
        if (arr == null) emptyList() else (0 until arr.length()).map { arr.optString(it) }

    private fun color(json: JSONObject, key: String): Int? =
        if (json.has(key) && !json.isNull(key)) json.optLong(key).toInt() else null

    private fun customView(
        context: Context,
        json: JSONObject,
        expanded: Boolean,
        icon: Bitmap?,
    ): RemoteViews {
        val views = RemoteViews(
            context.packageName,
            if (expanded) R.layout.notification_fronting_expanded else R.layout.notification_fronting_compact,
        )
        val bg = color(json, "backgroundColor")
        val fg = color(json, "textColor")
        val accent = color(json, "accentColor")
        if (bg != null) views.setInt(R.id.fronting_root, "setBackgroundColor", bg)
        views.setTextViewText(R.id.fronting_title, json.optString("title"))
        views.setTextViewText(R.id.fronting_text, json.optString("text"))
        if (fg != null) {
            views.setTextColor(R.id.fronting_title, fg)
            views.setTextColor(R.id.fronting_text, (fg and 0x00FFFFFF) or (0xCC shl 24))
        }
        if (icon != null) {
            views.setImageViewBitmap(R.id.fronting_icon, icon)
            views.setViewVisibility(R.id.fronting_icon, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.fronting_icon, View.GONE)
        }
        val base = json.optLong("chronometerBase", 0L)
        if (base > 0 && json.optBoolean("showChronometer", false)) {
            val elapsedBase = android.os.SystemClock.elapsedRealtime() - (System.currentTimeMillis() - base)
            views.setChronometer(R.id.fronting_timer, elapsedBase, null, true)
            views.setViewVisibility(R.id.fronting_timer, View.VISIBLE)
            if (fg != null) views.setTextColor(R.id.fronting_timer, fg)
            else if (accent != null) views.setTextColor(R.id.fronting_timer, accent)
        } else {
            views.setViewVisibility(R.id.fronting_timer, View.GONE)
        }
        if (expanded) {
            val lines = strings(json.optJSONArray("lines"))
            views.setTextViewText(R.id.fronting_lines, lines.joinToString("\n"))
            if (fg != null) views.setTextColor(R.id.fronting_lines, fg)
            views.setViewVisibility(R.id.fronting_lines, if (lines.isEmpty()) View.GONE else View.VISIBLE)
        }
        return views
    }

    fun build(context: Context, json: JSONObject): Notification {
        val channel = if (json.optBoolean("bypassDnd", false)) CHANNEL_DND else CHANNEL
        val title = json.optString("title")
        val text = json.optString("text")
        val lines = strings(json.optJSONArray("lines"))
        val layout = json.optString("layout", "expanded")
        val icon = if (layout == "minimal") null else largeIcon(json)
        val accent = color(json, "accentColor")
        val builder = NotificationCompat.Builder(context, channel)
            .setSmallIcon(smallIconRes(json.optString("smallIcon")))
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(json.optBoolean("ongoing", true))
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(launchIntent(context, json.optString("tapAction", "open"), 0))
            .setDeleteIntent(
                PendingIntent.getBroadcast(
                    context, 1,
                    Intent(context, FrontingStatusReceiver::class.java).setAction(ACTION_DISMISSED),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        }
        if (accent != null) builder.setColor(accent)
        if (json.optBoolean("colorized", false)) builder.setColorized(true)
        val sub = json.optString("subText", "")
        if (sub.isNotEmpty()) builder.setSubText(sub)
        val base = json.optLong("chronometerBase", 0L)
        if (base > 0 && json.optBoolean("showChronometer", false)) {
            builder.setWhen(base).setShowWhen(true).setUsesChronometer(true)
        }
        if (icon != null) builder.setLargeIcon(icon)

        if (json.optString("style") == "custom") {
            builder.setStyle(NotificationCompat.DecoratedCustomViewStyle())
            builder.setCustomContentView(customView(context, json, false, icon))
            if (layout != "compact" && layout != "minimal") {
                builder.setCustomBigContentView(customView(context, json, true, icon))
            }
        } else {
            when (layout) {
                "detailed" -> {
                    val style = NotificationCompat.InboxStyle().setBigContentTitle(title)
                    lines.forEach { style.addLine(it) }
                    if (sub.isNotEmpty()) style.setSummaryText(sub)
                    builder.setStyle(style)
                }
                "expanded" -> builder.setStyle(
                    NotificationCompat.BigTextStyle().setBigContentTitle(title)
                        .bigText(if (lines.isEmpty()) text else lines.joinToString("\n")),
                )
                else -> {}
            }
        }

        val actions = json.optJSONArray("actions")
        if (actions != null) {
            for (i in 0 until minOf(actions.length(), 3)) {
                val a = actions.optJSONObject(i) ?: continue
                builder.addAction(0, a.optString("label"), launchIntent(context, a.optString("id"), 10 + i))
            }
        }

        val visibility = when (json.optString("visibility", "private")) {
            "public" -> NotificationCompat.VISIBILITY_PUBLIC
            "secret" -> NotificationCompat.VISIBILITY_SECRET
            else -> NotificationCompat.VISIBILITY_PRIVATE
        }
        builder.setVisibility(visibility)
        if (visibility == NotificationCompat.VISIBILITY_PRIVATE) {
            val publicVersion = NotificationCompat.Builder(context, channel)
                .setSmallIcon(smallIconRes(json.optString("smallIcon")))
                .setContentTitle(json.optString("publicTitle", "Prism"))
                .setContentText(json.optString("publicText", ""))
                .setOngoing(true)
                .setSilent(true)
                .build()
            builder.setPublicVersion(publicVersion)
        }
        return builder.build()
    }

    fun canPost(context: Context): Boolean = NotificationManagerCompat.from(context).areNotificationsEnabled()

    /** Posts (or replaces) the notification; starts the service if asked. */
    fun show(context: Context, json: JSONObject) {
        saveSnapshot(context, json)
        if (json.optBoolean("foreground", false)) {
            FrontingStatusService.start(context)
            return
        }
        FrontingStatusService.stop(context)
        if (!canPost(context)) return
        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, build(context, json))
        } catch (_: SecurityException) {
            // Notification permission revoked; nothing to show.
        }
    }

    fun cancel(context: Context) {
        clearSnapshot(context)
        FrontingStatusService.stop(context)
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    /** Re-posts the stored notification (boot, update, service restart). */
    fun restore(context: Context) {
        val json = loadSnapshot(context) ?: return
        if (!json.optBoolean("restoreOnBoot", true)) return
        show(context, json)
    }

    fun isShowing(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return loadSnapshot(context) != null
        val nm = context.getSystemService(NotificationManager::class.java) ?: return false
        return nm.activeNotifications.any { it.id == NOTIFICATION_ID }
    }
}
