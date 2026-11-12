package com.prismplural.prism

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * Base provider: draws from the cached model and tells Prism (if running)
 * that widgets were added, resized or removed so it can refresh them.
 * One subclass per widget type exists so each shows up separately in the
 * launcher's widget picker.
 */
open class PrismWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) PrismWidgets.render(context, mgr, id)
        PrismWidgets.channel?.invokeMethod("widgetsChanged", null)
    }

    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, newOptions: Bundle) {
        PrismWidgets.render(context, mgr, id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        for (id in ids) PrismWidgets.deleteModel(context, id)
        PrismWidgets.channel?.invokeMethod("widgetsChanged", null)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
    }
}

/** Handles background taps (quick front, mood, check items, refresh). */
class PrismWidgetActionReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != PrismWidgets.ACTION_DATA) return
        val id = intent.getIntExtra(PrismWidgets.EXTRA_WIDGET_ID, -1)
        val action = intent.getStringExtra(PrismWidgets.EXTRA_ACTION) ?: return
        PrismWidgets.handleDataAction(context, id, action, intent.getStringExtra("optimistic"))
    }
}

/**
 * Opened by the launcher's "Widget settings": hands over to Prism's widget
 * studio for this widget.
 */
class PrismWidgetConfigureActivity : android.app.Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
        if (id != AppWidgetManager.INVALID_APPWIDGET_ID) {
            PrismWidgets.render(this, AppWidgetManager.getInstance(this), id)
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra(PrismWidgets.EXTRA_ACTION, "configure:$id")
                    .putExtra(PrismWidgets.EXTRA_WIDGET_ID, id),
            )
        }
        finish()
    }
}
