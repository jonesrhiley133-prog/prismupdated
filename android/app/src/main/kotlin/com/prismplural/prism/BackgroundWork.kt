package com.prismplural.prism

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Long-running work the person started (e.g. a Dictionary import from a
 * wiki). While it runs, a progress notification is shown and this
 * foreground service keeps Prism's process — and so the Dart code doing
 * the work — alive when the app is in the background.
 */
object BackgroundWork {
    const val CHANNEL = "prism_background_work"
    const val NOTIFICATION_ID = 7341
    const val DONE_NOTIFICATION_ID = 7342

    @Volatile var title: String = "Prism"
    @Volatile var text: String = ""
    @Volatile var progress: Int = 0
    @Volatile var max: Int = 0

    fun ensureChannel(context: Context, name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
            },
        )
    }

    private fun openApp(context: Context): PendingIntent? {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        return PendingIntent.getActivity(context, 7341, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    fun build(context: Context): Notification =
        NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(max, progress.coerceAtMost(max), max <= 0)
            .setContentIntent(openApp(context))
            .build()

    fun update(context: Context, title: String, text: String, progress: Int, max: Int) {
        this.title = title
        this.text = text
        this.progress = progress
        this.max = max
        if (BackgroundWorkService.running) {
            try {
                NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, build(context))
            } catch (_: SecurityException) {
            }
        } else {
            BackgroundWorkService.start(context)
        }
    }

    fun finish(context: Context, title: String?, text: String?) {
        BackgroundWorkService.stop(context)
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        if (title.isNullOrEmpty()) return
        try {
            NotificationManagerCompat.from(context).notify(
                DONE_NOTIFICATION_ID,
                NotificationCompat.Builder(context, CHANNEL)
                    .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .setContentTitle(title)
                    .setContentText(text ?: "")
                    .setAutoCancel(true)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setContentIntent(openApp(context))
                    .build(),
            )
        } catch (_: SecurityException) {
        }
    }
}

class BackgroundWorkService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            ServiceCompat.startForeground(
                this,
                BackgroundWork.NOTIFICATION_ID,
                BackgroundWork.build(this),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                } else {
                    0
                },
            )
            running = true
        } catch (_: Exception) {
            // Not allowed right now (e.g. started from the background): show
            // the progress as a normal notification; the work still runs
            // while Android keeps the app alive.
            try {
                NotificationManagerCompat.from(this).notify(BackgroundWork.NOTIFICATION_ID, BackgroundWork.build(this))
            } catch (_: SecurityException) {
            }
            stopSelf()
            return START_NOT_STICKY
        }
        // Not sticky: if Android kills the process, Prism resumes the import
        // the next time it opens.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Android 15 limits dataSync services; stop cleanly. The import is
        // saved and resumes when Prism is opened again.
        running = false
        stopSelf()
    }

    companion object {
        @Volatile var running = false

        fun start(context: Context) {
            try {
                ContextCompat.startForegroundService(context, Intent(context, BackgroundWorkService::class.java))
            } catch (_: Exception) {
                try {
                    NotificationManagerCompat.from(context).notify(BackgroundWork.NOTIFICATION_ID, BackgroundWork.build(context))
                } catch (_: SecurityException) {
                }
            }
        }

        fun stop(context: Context) {
            running = false
            context.stopService(Intent(context, BackgroundWorkService::class.java))
        }
    }
}
