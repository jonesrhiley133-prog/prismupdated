package com.prismplural.prism

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restores the notification after reboot/app update and records swipes. */
class FrontingStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> FrontingStatus.restore(context)
            FrontingStatus.ACTION_DISMISSED -> FrontingStatus.markDismissed(context)
        }
    }
}
