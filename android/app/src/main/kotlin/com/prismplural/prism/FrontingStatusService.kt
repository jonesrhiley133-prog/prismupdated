package com.prismplural.prism

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Optional foreground service that keeps the fronting notification pinned
 * and Prism's process alive so synced front changes from other devices can
 * update it. It always uses the same notification id as the plain
 * notification, so switching between modes never shows two.
 */
class FrontingStatusService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val json = FrontingStatus.loadSnapshot(this)
        if (json == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        val notification = FrontingStatus.build(this, json)
        try {
            ServiceCompat.startForeground(
                this,
                FrontingStatus.NOTIFICATION_ID,
                notification,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                } else {
                    0
                },
            )
        } catch (_: Exception) {
            // Not allowed to start in the foreground right now (e.g. started
            // from the background on Android 12+): fall back to a plain
            // ongoing notification with the same id.
            try {
                androidx.core.app.NotificationManagerCompat.from(this)
                    .notify(FrontingStatus.NOTIFICATION_ID, notification)
            } catch (_: SecurityException) {
            }
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    companion object {
        fun start(context: Context) {
            try {
                ContextCompat.startForegroundService(context, Intent(context, FrontingStatusService::class.java))
            } catch (_: Exception) {
                val json = FrontingStatus.loadSnapshot(context) ?: return
                try {
                    androidx.core.app.NotificationManagerCompat.from(context)
                        .notify(FrontingStatus.NOTIFICATION_ID, FrontingStatus.build(context, json))
                } catch (_: SecurityException) {
                }
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FrontingStatusService::class.java))
        }
    }
}
