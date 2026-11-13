package com.prismplural.prism

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.MethodChannel

/**
 * System media controls for Prism's music player: a MediaSession (lock
 * screen, headset buttons, One UI media panel) plus a media notification
 * kept by a foreground service so playback continues with the screen off.
 * Audio itself is played by the Flutter side; this only mirrors its state
 * and forwards button presses.
 */
object MusicPlayback {
    const val CHANNEL_ID = "music_playback"
    const val NOTIFICATION_ID = 7420
    const val ACTION = "com.prismplural.prism.MUSIC_ACTION"
    const val EXTRA = "music_action"

    @Volatile
    var channel: MethodChannel? = null

    private var session: MediaSession? = null
    private var title = ""
    private var artist = ""
    private var album = ""
    private var art: Bitmap? = null
    private var artPath: String? = null
    private var playing = false
    private var positionMs = 0L
    private var durationMs = 0L
    private var serviceRunning = false
    private val main = Handler(Looper.getMainLooper())

    private fun send(action: String, positionMs: Long? = null) {
        main.post {
            channel?.invokeMethod(action, if (positionMs == null) null else mapOf("positionMs" to positionMs.toInt()))
        }
    }

    private fun ensureChannel(context: Context) {
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
            val ch = NotificationChannel(CHANNEL_ID, context.getString(R.string.music_channel_name), NotificationManager.IMPORTANCE_LOW)
            ch.setShowBadge(false)
            ch.setSound(null, null)
            mgr.createNotificationChannel(ch)
        }
    }

    private fun ensureSession(context: Context): MediaSession {
        session?.let { return it }
        val s = MediaSession(context.applicationContext, "PrismMusic")
        s.setCallback(object : MediaSession.Callback() {
            override fun onPlay() = send("play")
            override fun onPause() = send("pause")
            override fun onSkipToNext() = send("next")
            override fun onSkipToPrevious() = send("previous")
            override fun onSeekTo(pos: Long) = send("seek", pos)
            override fun onStop() = send("stop")
        })
        s.isActive = true
        session = s
        return s
    }

    private fun actionIntent(context: Context, action: String, code: Int): PendingIntent {
        val i = Intent(context, MusicActionReceiver::class.java).setAction(ACTION).putExtra(EXTRA, action)
        return PendingIntent.getBroadcast(context, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun action(context: Context, icon: Int, label: Int, name: String, code: Int): Notification.Action =
        Notification.Action.Builder(Icon.createWithResource(context, icon), context.getString(label), actionIntent(context, name, code)).build()

    fun buildNotification(context: Context): Notification {
        ensureChannel(context)
        val s = ensureSession(context)
        val open = PendingIntent.getActivity(
            context,
            7421,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val b = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_music)
            .setContentTitle(title)
            .setContentText(listOf(artist, album).filter { it.isNotEmpty() }.joinToString(" · "))
            .setContentIntent(open)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setOngoing(playing)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setDeleteIntent(actionIntent(context, "stop", 5))
            .addAction(action(context, android.R.drawable.ic_media_previous, R.string.music_previous, "previous", 1))
            .addAction(
                if (playing) action(context, android.R.drawable.ic_media_pause, R.string.music_pause, "pause", 2)
                else action(context, android.R.drawable.ic_media_play, R.string.music_play, "play", 3),
            )
            .addAction(action(context, android.R.drawable.ic_media_next, R.string.music_next, "next", 4))
            .setStyle(Notification.MediaStyle().setMediaSession(s.sessionToken).setShowActionsInCompactView(0, 1, 2))
        art?.let { b.setLargeIcon(it) }
        return b.build()
    }

    fun update(context: Context, args: Map<*, *>) {
        title = args["title"] as? String ?: ""
        artist = args["artist"] as? String ?: ""
        album = args["album"] as? String ?: ""
        playing = args["playing"] as? Boolean ?: false
        positionMs = (args["positionMs"] as? Number)?.toLong() ?: 0L
        durationMs = (args["durationMs"] as? Number)?.toLong() ?: 0L
        val path = args["artPath"] as? String
        if (path != artPath) {
            artPath = path
            art = if (path == null) null else try {
                val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, o)
                var sample = 1
                while (o.outWidth / sample > 640 || o.outHeight / sample > 640) sample *= 2
                BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            } catch (_: Throwable) {
                null
            }
        }
        val s = ensureSession(context)
        val meta = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, album)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)
        art?.let { meta.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it) }
        s.setMetadata(meta.build())
        s.setPlaybackState(
            PlaybackState.Builder()
                .setActions(
                    PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or
                        PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackState.ACTION_SEEK_TO or PlaybackState.ACTION_STOP,
                )
                .setState(
                    if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                    positionMs,
                    if (playing) 1f else 0f,
                    SystemClock.elapsedRealtime(),
                )
                .build(),
        )
        s.isActive = true
        if (serviceRunning) {
            try {
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .notify(NOTIFICATION_ID, buildNotification(context))
            } catch (_: SecurityException) {
            }
        } else if (playing) {
            try {
                context.startForegroundService(Intent(context, MusicPlaybackService::class.java))
            } catch (_: Exception) {
                // Not allowed right now; playback continues without the notification.
            }
        }
    }

    fun clear(context: Context) {
        try {
            context.stopService(Intent(context, MusicPlaybackService::class.java))
        } catch (_: Exception) {
        }
        serviceRunning = false
        session?.let {
            it.isActive = false
            it.release()
        }
        session = null
        art = null
        artPath = null
        try {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION_ID)
        } catch (_: Exception) {
        }
    }

    fun onServiceStarted() {
        serviceRunning = true
    }

    fun onServiceStopped() {
        serviceRunning = false
    }

    fun handle(action: String) = send(action)
}

class MusicPlaybackService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val n = MusicPlayback.buildNotification(this)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(MusicPlayback.NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(MusicPlayback.NOTIFICATION_ID, n)
            }
            MusicPlayback.onServiceStarted()
        } catch (_: Exception) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Prism was swiped away: the audio engine is gone, so tidy up.
        MusicPlayback.clear(this)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        MusicPlayback.onServiceStopped()
        super.onDestroy()
    }
}

class MusicActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != MusicPlayback.ACTION) return
        val action = intent.getStringExtra(MusicPlayback.EXTRA) ?: return
        if (MusicPlayback.channel == null && action == "stop") {
            MusicPlayback.clear(context)
        } else {
            MusicPlayback.handle(action)
        }
    }
}
