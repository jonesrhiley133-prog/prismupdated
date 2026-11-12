package com.prismplural.prism

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.os.Build
import android.os.Bundle
import android.text.format.DateUtils
import android.util.Base64
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Renders every Prism home-screen widget from a JSON model that the Flutter
 * side prepares (and caches on disk, so widgets keep showing data while
 * Prism is closed). One generic, responsive template covers all widget
 * types: header, optional image, rows, buttons — sized small/medium/large.
 */
object PrismWidgets {
    const val EXTRA_ACTION = "prism_widget_action"
    const val EXTRA_WIDGET_ID = "prism_widget_id"
    const val EXTRA_CONFIGURE = "prism_widget_configure"
    const val ACTION_DATA = "com.prismplural.prism.WIDGET_DATA_ACTION"
    private const val PREFS = "prism_widgets"
    private const val KEY_QUEUE = "queue"

    /** Channel to the running Flutter engine, or null when Prism is closed. */
    @Volatile
    var channel: MethodChannel? = null

    /** provider class simple name -> widget type key */
    val types: Map<String, String> = mapOf(
        "RecentFrontersWidget" to "recent_fronters",
        "CurrentFronterWidget" to "current_fronter",
        "QuickFrontWidget" to "quick_front",
        "EventsWidget" to "events",
        "JournalWidget" to "journal",
        "CycleWidget" to "cycle",
        "MoodWidget" to "mood",
        "LocationWidget" to "location",
        "SleepWidget" to "sleep",
        "FitnessWidget" to "fitness",
        "TodoWidget" to "todo",
        "SchoolWidget" to "school",
        "FinanceWidget" to "finance",
        "CountdownWidget" to "countdown",
        "RelationshipsWidget" to "relationships",
        "AchievementsWidget" to "achievements",
        "HeadspaceWidget" to "headspace",
        "NotesWidget" to "notes",
        "SubsystemsWidget" to "subsystems",
        "StatsWidget" to "stats",
    )

    private fun dir(context: Context): File = File(context.filesDir, "widgets").apply { mkdirs() }

    fun saveModel(context: Context, id: Int, json: String) {
        File(dir(context), "$id.json").writeText(json)
    }

    fun loadModel(context: Context, id: Int): JSONObject? {
        val f = File(dir(context), "$id.json")
        if (!f.exists()) return null
        return try { JSONObject(f.readText()) } catch (_: Exception) { null }
    }

    fun deleteModel(context: Context, id: Int) {
        File(dir(context), "$id.json").delete()
    }

    fun allPlaced(context: Context): List<Pair<Int, String>> {
        val mgr = AppWidgetManager.getInstance(context)
        val out = mutableListOf<Pair<Int, String>>()
        for ((cls, type) in types) {
            val cn = ComponentName(context, "com.prismplural.prism.widgets.$cls")
            for (id in mgr.getAppWidgetIds(cn)) out.add(id to type)
        }
        return out
    }

    fun typeOf(context: Context, id: Int): String? {
        val info = AppWidgetManager.getInstance(context).getAppWidgetInfo(id) ?: return null
        return types[info.provider.className.substringAfterLast('.')]
    }

    // ---------------------------------------------------------------- queue

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enqueue(context: Context, widgetId: Int, action: String) {
        val p = prefs(context)
        val arr = try { JSONArray(p.getString(KEY_QUEUE, "[]")) } catch (_: Exception) { JSONArray() }
        arr.put(JSONObject().put("id", widgetId).put("action", action).put("at", System.currentTimeMillis()))
        p.edit().putString(KEY_QUEUE, arr.toString()).apply()
    }

    fun takeQueue(context: Context): String {
        val p = prefs(context)
        val s = p.getString(KEY_QUEUE, "[]") ?: "[]"
        p.edit().putString(KEY_QUEUE, "[]").apply()
        return s
    }

    // ------------------------------------------------------------- intents

    private fun activityIntent(context: Context, widgetId: Int, action: String, code: Int): PendingIntent {
        val i = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ACTION, action)
            putExtra(EXTRA_WIDGET_ID, widgetId)
            data = android.net.Uri.parse("prism-widget://$widgetId/$code")
        }
        return PendingIntent.getActivity(context, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun dataIntent(context: Context, widgetId: Int, action: String, optimistic: JSONObject?, code: Int): PendingIntent {
        val i = Intent(context, PrismWidgetActionReceiver::class.java).apply {
            this.action = ACTION_DATA
            putExtra(EXTRA_ACTION, action)
            putExtra(EXTRA_WIDGET_ID, widgetId)
            if (optimistic != null) putExtra("optimistic", optimistic.toString())
            data = android.net.Uri.parse("prism-widget-data://$widgetId/$code")
        }
        return PendingIntent.getBroadcast(context, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun intentFor(context: Context, widgetId: Int, a: JSONObject?, code: Int): PendingIntent? {
        if (a == null) return null
        val action = a.optString("action", "")
        if (action.isEmpty()) return null
        return if (a.optBoolean("background", false)) {
            dataIntent(context, widgetId, action, a.optJSONObject("optimistic"), code)
        } else {
            activityIntent(context, widgetId, action, code)
        }
    }

    // --------------------------------------------------------------- drawing

    private fun dp(context: Context, v: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, context.resources.displayMetrics)

    private fun decode(b64: String?): Bitmap? {
        if (b64.isNullOrEmpty()) return null
        return try {
            val bytes = Base64.decode(b64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (_: Exception) { null }
    }

    private fun shaped(src: Bitmap, shape: String, sizePx: Int): Bitmap {
        val out = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val s = min(src.width, src.height).toFloat()
        val m = Matrix().apply {
            setScale(sizePx / s, sizePx / s)
            preTranslate(-(src.width - s) / 2f, -(src.height - s) / 2f)
        }
        val shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply { setLocalMatrix(m) }
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.shader = shader }
        val r = RectF(0f, 0f, sizePx.toFloat(), sizePx.toFloat())
        when (shape) {
            "square" -> c.drawRect(r, p)
            "rounded" -> c.drawRoundRect(r, sizePx * 0.22f, sizePx * 0.22f, p)
            else -> c.drawOval(r, p)
        }
        return out
    }

    private class Palette(val bg1: Int, val bg2: Int, val text: Int, val text2: Int, val accent: Int, val border: Int)

    private fun palette(context: Context, style: JSONObject): Palette {
        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val key = when (style.optString("theme", "system")) {
            "light" -> "light"
            "dark", "amoled" -> "dark"
            else -> if (night) "dark" else "light"
        }
        val p = style.optJSONObject(key) ?: style.optJSONObject("dark") ?: JSONObject()
        fun c(k: String, d: Long) = (if (p.has(k)) p.optLong(k) else d).toInt()
        return Palette(
            c("bg1", 0xFF1E1A24), c("bg2", 0xFF1E1A24), c("text", 0xFFFFFFFF),
            c("text2", 0xB3FFFFFF), c("accent", 0xFFB39DDB), c("border", 0x00000000),
        )
    }

    private fun background(context: Context, style: JSONObject, pal: Palette, wDp: Float, hDp: Float): Bitmap {
        val scale = min(1f, 720f / dp(context, maxOf(wDp, hDp)))
        val w = (dp(context, wDp) * scale).toInt().coerceAtLeast(8)
        val h = (dp(context, hDp) * scale).toInt().coerceAtLeast(8)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val radius = dp(context, style.optDouble("radius", 24.0).toFloat()) * scale
        val border = dp(context, style.optDouble("borderWidth", 0.0).toFloat()) * scale
        val alpha = (style.optDouble("opacity", 1.0).coerceIn(0.0, 1.0) * 255).toInt()
        val rect = RectF(border / 2, border / 2, w - border / 2, h - border / 2)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val image = decode(style.optString("bgImage", ""))
        if (image != null) {
            val s = maxOf(w / image.width.toFloat(), h / image.height.toFloat())
            val m = Matrix().apply {
                setScale(s, s)
                postTranslate((w - image.width * s) / 2f, (h - image.height * s) / 2f)
            }
            paint.shader = BitmapShader(image, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply { setLocalMatrix(m) }
            paint.alpha = alpha
            c.drawRoundRect(rect, radius, radius, paint)
            paint.shader = null
            paint.color = pal.bg1
            paint.alpha = (style.optDouble("imageDim", 0.35).coerceIn(0.0, 1.0) * 255).toInt()
            c.drawRoundRect(rect, radius, radius, paint)
        } else {
            val angle = Math.toRadians(style.optDouble("gradientAngle", 135.0))
            val dx = cos(angle).toFloat() * w / 2
            val dy = sin(angle).toFloat() * h / 2
            paint.shader = LinearGradient(w / 2f - dx, h / 2f - dy, w / 2f + dx, h / 2f + dy, pal.bg1, pal.bg2, Shader.TileMode.CLAMP)
            paint.alpha = alpha
            c.drawRoundRect(rect, radius, radius, paint)
        }
        if (border > 0 && (pal.border ushr 24) != 0) {
            val bp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.style = Paint.Style.STROKE
                strokeWidth = border
                color = pal.border
            }
            c.drawRoundRect(rect, radius, radius, bp)
        }
        return bmp
    }

    private fun layoutsFor(font: String): Triple<Int, Int, Int> = when (font) {
        "serif" -> Triple(R.layout.prism_widget_header_serif, R.layout.prism_widget_row_serif, R.layout.prism_widget_button_serif)
        "mono" -> Triple(R.layout.prism_widget_header_mono, R.layout.prism_widget_row_mono, R.layout.prism_widget_button_mono)
        "condensed" -> Triple(R.layout.prism_widget_header_condensed, R.layout.prism_widget_row_condensed, R.layout.prism_widget_button_condensed)
        else -> Triple(R.layout.prism_widget_header_sans, R.layout.prism_widget_row_sans, R.layout.prism_widget_button_sans)
    }

    private fun formatTime(context: Context, ms: Long, style: String): String {
        if (ms <= 0) return ""
        return when (style) {
            "clock" -> android.text.format.DateFormat.getTimeFormat(context).format(java.util.Date(ms))
            "date" -> DateUtils.formatDateTime(context, ms, DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH)
            "days" -> {
                val today = java.time.LocalDate.now()
                val target = java.time.Instant.ofEpochMilli(ms).atZone(java.time.ZoneId.systemDefault()).toLocalDate()
                val d = java.time.temporal.ChronoUnit.DAYS.between(today, target)
                when {
                    d == 0L -> context.getString(R.string.widget_today)
                    d == 1L -> context.getString(R.string.widget_tomorrow)
                    d > 0 -> context.resources.getQuantityString(R.plurals.widget_in_days, d.toInt(), d.toInt())
                    else -> context.resources.getQuantityString(R.plurals.widget_days_ago, (-d).toInt(), (-d).toInt())
                }
            }
            else -> DateUtils.getRelativeTimeSpanString(ms, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS, DateUtils.FORMAT_ABBREV_RELATIVE).toString()
        }
    }

    private fun sizeClass(wDp: Float, hDp: Float): String = when {
        wDp >= 250 && hDp >= 230 -> "large"
        wDp < 180 || hDp < 100 -> "small"
        else -> "medium"
    }

    private fun build(context: Context, id: Int, model: JSONObject?, size: String, wDp: Float, hDp: Float): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.prism_widget)
        if (model == null) {
            views.setImageViewBitmap(R.id.widget_bg, background(context, JSONObject(), palette(context, JSONObject()), wDp, hDp))
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_empty, context.getString(R.string.widget_setup))
            views.setViewVisibility(R.id.widget_rows, View.GONE)
            views.setOnClickPendingIntent(R.id.widget_root, activityIntent(context, id, "configure:$id", id * 100))
            return views
        }
        val style = model.optJSONObject("style") ?: JSONObject()
        val pal = palette(context, style)
        val scale = style.optDouble("textScale", 1.0).toFloat().coerceIn(0.7f, 1.6f)
        val (headerLayout, rowLayout, buttonLayout) = layoutsFor(style.optString("font", "sans"))
        val avatarShape = style.optString("avatarShape", "circle")
        val compact = style.optBoolean("compact", false)
        views.setImageViewBitmap(R.id.widget_bg, background(context, style, pal, wDp, hDp))
        val pad = dp(context, if (compact || size == "small") 10f else 14f).toInt()
        views.setViewPadding(R.id.widget_content, pad, pad, pad, pad)

        var code = id * 100
        model.optJSONObject("tap")?.let { tap -> intentFor(context, id, tap, code++)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) } }

        // Header
        views.removeAllViews(R.id.widget_header)
        val header = model.optJSONObject("header")
        if (header != null && !(size == "small" && style.optBoolean("hideHeaderSmall", false))) {
            val h = RemoteViews(context.packageName, headerLayout)
            h.setTextViewText(R.id.header_title, header.optString("title"))
            h.setTextColor(R.id.header_title, pal.text)
            h.setTextViewTextSize(R.id.header_title, TypedValue.COMPLEX_UNIT_SP, 14f * scale)
            val sub = header.optString("subtitle", "")
            if (sub.isNotEmpty() && size != "small" || (size == "small" && header.optBoolean("subtitleSmall", false) && sub.isNotEmpty())) {
                h.setTextViewText(R.id.header_subtitle, sub)
                h.setTextColor(R.id.header_subtitle, pal.text2)
                h.setTextViewTextSize(R.id.header_subtitle, TypedValue.COMPLEX_UNIT_SP, 12f * scale)
                h.setViewVisibility(R.id.header_subtitle, View.VISIBLE)
            } else h.setViewVisibility(R.id.header_subtitle, View.GONE)
            val icon = decode(header.optString("image", ""))
            val emoji = header.optString("emoji", "")
            if (icon != null) {
                h.setImageViewBitmap(R.id.header_icon, shaped(icon, avatarShape, dp(context, 36f).toInt()))
                h.setViewVisibility(R.id.header_icon, View.VISIBLE)
                h.setViewVisibility(R.id.header_emoji, View.GONE)
            } else if (emoji.isNotEmpty()) {
                h.setTextViewText(R.id.header_emoji, emoji)
                h.setTextViewTextSize(R.id.header_emoji, TypedValue.COMPLEX_UNIT_SP, 20f * scale)
                h.setViewVisibility(R.id.header_emoji, View.VISIBLE)
                h.setViewVisibility(R.id.header_icon, View.GONE)
            } else {
                h.setViewVisibility(R.id.header_icon, View.GONE)
                h.setViewVisibility(R.id.header_emoji, View.GONE)
            }
            val trailing = header.optString("trailing", "").ifEmpty { formatTime(context, header.optLong("time", 0), header.optString("timeStyle", "relative")) }
            h.setTextViewText(R.id.header_trailing, trailing)
            h.setTextColor(R.id.header_trailing, pal.accent)
            h.setViewVisibility(R.id.header_trailing, if (trailing.isEmpty()) View.GONE else View.VISIBLE)
            if (style.optBoolean("showRefresh", true) && size != "small") {
                h.setViewVisibility(R.id.header_refresh, View.VISIBLE)
                h.setInt(R.id.header_refresh, "setColorFilter", pal.text2)
                h.setOnClickPendingIntent(R.id.header_refresh, dataIntent(context, id, "refresh", null, code++))
            } else h.setViewVisibility(R.id.header_refresh, View.GONE)
            if (style.optString("align") == "center") h.setInt(R.id.header_text_column, "setGravity", android.view.Gravity.CENTER_HORIZONTAL)
            views.addView(R.id.widget_header, h)
        }

        // Image (headspace map, charts)
        val image = decode(model.optString("image", ""))
        if (image != null && (size != "small" || model.optBoolean("imageSmall", false))) {
            views.setImageViewBitmap(R.id.widget_image, image)
            views.setViewVisibility(R.id.widget_image, View.VISIBLE)
        } else views.setViewVisibility(R.id.widget_image, View.GONE)

        // Rows
        views.removeAllViews(R.id.widget_rows)
        val rows = model.optJSONArray("rows") ?: JSONArray()
        val maxRows = when (size) {
            "small" -> model.optInt("rowsSmall", 2)
            "medium" -> model.optInt("rowsMedium", if (image != null) 1 else 4)
            else -> model.optInt("rowsLarge", if (image != null) 3 else 8)
        }
        val shown = min(rows.length(), maxRows)
        for (i in 0 until shown) {
            val r = rows.optJSONObject(i) ?: continue
            val rv = RemoteViews(context.packageName, rowLayout)
            rv.setTextViewText(R.id.row_title, r.optString("title"))
            rv.setTextColor(R.id.row_title, pal.text)
            rv.setTextViewTextSize(R.id.row_title, TypedValue.COMPLEX_UNIT_SP, (if (compact) 12f else 13f) * scale)
            val sub = r.optString("subtitle", "")
            if (sub.isNotEmpty() && !(compact && size == "small")) {
                rv.setTextViewText(R.id.row_subtitle, sub)
                rv.setTextColor(R.id.row_subtitle, pal.text2)
                rv.setTextViewTextSize(R.id.row_subtitle, TypedValue.COMPLEX_UNIT_SP, 11f * scale)
                rv.setViewVisibility(R.id.row_subtitle, View.VISIBLE)
            } else rv.setViewVisibility(R.id.row_subtitle, View.GONE)
            val trailing = r.optString("trailing", "").ifEmpty { formatTime(context, r.optLong("time", 0), r.optString("timeStyle", "relative")) }
            rv.setTextViewText(R.id.row_trailing, trailing)
            rv.setTextColor(R.id.row_trailing, pal.text2)
            rv.setTextViewTextSize(R.id.row_trailing, TypedValue.COMPLEX_UNIT_SP, 11f * scale)
            rv.setViewVisibility(R.id.row_trailing, if (trailing.isEmpty()) View.GONE else View.VISIBLE)
            val avatar = decode(r.optString("image", ""))
            val emoji = r.optString("emoji", "")
            val showAvatars = style.optBoolean("showAvatars", true)
            if (showAvatars && avatar != null) {
                rv.setImageViewBitmap(R.id.row_avatar, shaped(avatar, avatarShape, dp(context, 28f).toInt()))
                rv.setViewVisibility(R.id.row_avatar, View.VISIBLE)
                rv.setViewVisibility(R.id.row_emoji, View.GONE)
            } else if (showAvatars && emoji.isNotEmpty()) {
                rv.setTextViewText(R.id.row_emoji, emoji)
                rv.setTextViewTextSize(R.id.row_emoji, TypedValue.COMPLEX_UNIT_SP, 16f * scale)
                rv.setViewVisibility(R.id.row_emoji, View.VISIBLE)
                rv.setViewVisibility(R.id.row_avatar, View.GONE)
            } else {
                rv.setViewVisibility(R.id.row_avatar, View.GONE)
                rv.setViewVisibility(R.id.row_emoji, View.GONE)
            }
            if (r.has("progress")) {
                rv.setProgressBar(R.id.row_progress, 1000, (r.optDouble("progress", 0.0).coerceIn(0.0, 1.0) * 1000).toInt(), false)
                rv.setViewVisibility(R.id.row_progress, View.VISIBLE)
            } else rv.setViewVisibility(R.id.row_progress, View.GONE)
            if (r.has("checked")) {
                rv.setImageViewResource(R.id.row_check, if (r.optBoolean("checked")) R.drawable.ic_widget_checked else R.drawable.ic_widget_unchecked)
                rv.setInt(R.id.row_check, "setColorFilter", if (r.optBoolean("checked")) pal.accent else pal.text2)
                rv.setViewVisibility(R.id.row_check, View.VISIBLE)
            } else rv.setViewVisibility(R.id.row_check, View.GONE)
            intentFor(context, id, r.optJSONObject("action"), code++)?.let { rv.setOnClickPendingIntent(R.id.row_root, it) }
            views.addView(R.id.widget_rows, rv)
        }
        val empty = model.optString("empty", "")
        if (shown == 0 && empty.isNotEmpty() && image == null) {
            views.setTextViewText(R.id.widget_empty, empty)
            views.setTextColor(R.id.widget_empty, pal.text2)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_rows, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_empty, View.GONE)
            // Rows take the space left over, so buttons stay pinned at the bottom.
            views.setViewVisibility(R.id.widget_rows, if (shown == 0 && image != null) View.GONE else View.VISIBLE)
        }

        // Buttons
        views.removeAllViews(R.id.widget_buttons)
        val buttons = model.optJSONArray("buttons") ?: JSONArray()
        val maxButtons = when (size) { "small" -> model.optInt("buttonsSmall", 2); "medium" -> 3; else -> 5 }
        val bShown = min(buttons.length(), maxButtons)
        for (i in 0 until bShown) {
            val b = buttons.optJSONObject(i) ?: continue
            val bv = RemoteViews(context.packageName, buttonLayout)
            val label = if (size == "small" && b.optString("emoji").isNotEmpty()) b.optString("emoji")
                else listOf(b.optString("emoji"), b.optString("label")).filter { it.isNotEmpty() }.joinToString(" ")
            bv.setTextViewText(R.id.button_label, label)
            bv.setTextColor(R.id.button_label, pal.text)
            bv.setTextViewTextSize(R.id.button_label, TypedValue.COMPLEX_UNIT_SP, 12f * scale)
            intentFor(context, id, b, code++)?.let { bv.setOnClickPendingIntent(R.id.button_root, it) }
            views.addView(R.id.widget_buttons, bv)
        }
        views.setViewVisibility(R.id.widget_buttons, if (bShown == 0) View.GONE else View.VISIBLE)
        return views
    }

    fun render(context: Context, mgr: AppWidgetManager, id: Int) {
        val model = loadModel(context, id)
        val views: RemoteViews = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            RemoteViews(
                mapOf(
                    SizeF(110f, 110f) to build(context, id, model, "small", 160f, 160f),
                    SizeF(250f, 110f) to build(context, id, model, "medium", 320f, 160f),
                    SizeF(250f, 250f) to build(context, id, model, "large", 320f, 320f),
                ),
            )
        } else {
            val o: Bundle = mgr.getAppWidgetOptions(id)
            val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250).toFloat()
            val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110).toFloat()
            val size = sizeClass(w, h)
            build(context, id, model, size, w.coerceAtLeast(110f), h.coerceAtLeast(110f))
        }
        try {
            mgr.updateAppWidget(id, views)
        } catch (_: Exception) {
            // Bitmap budget exceeded on very old launchers; drop the image.
            model?.remove("image")
        }
    }

    fun renderAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        for ((id, _) in allPlaced(context)) render(context, mgr, id)
    }

    /** Applies an instant visual change before Prism saves the action. */
    fun applyOptimistic(context: Context, id: Int, optimistic: JSONObject) {
        val model = loadModel(context, id) ?: return
        if (optimistic.has("toggleRow")) {
            val rows = model.optJSONArray("rows")
            val r = rows?.optJSONObject(optimistic.optInt("toggleRow"))
            if (r != null && r.has("checked")) r.put("checked", !r.optBoolean("checked"))
        }
        if (optimistic.has("subtitle")) {
            model.optJSONObject("header")?.put("subtitle", optimistic.optString("subtitle"))
        }
        if (optimistic.has("trailing")) {
            model.optJSONObject("header")?.put("trailing", optimistic.optString("trailing"))
        }
        saveModel(context, id, model.toString())
        render(context, AppWidgetManager.getInstance(context), id)
    }

    fun handleDataAction(context: Context, id: Int, action: String, optimistic: String?) {
        if (optimistic != null) {
            try { applyOptimistic(context, id, JSONObject(optimistic)) } catch (_: Exception) {}
        }
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("widgetAction", mapOf("id" to id, "action" to action))
        } else if (action != "refresh") {
            enqueue(context, id, action)
        } else {
            render(context, AppWidgetManager.getInstance(context), id)
        }
    }
}
