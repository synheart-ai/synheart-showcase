package ai.synheart.scene

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
import androidx.core.app.ServiceCompat

/**
 * Keeps Scene's process alive while it collects the current state in the
 * background: heart rate from the chosen source and behavior signals (app
 * switches, notification and call events, motion). The person sees an ongoing
 * notification the whole time; withdrawing consent in Settings stops it.
 *
 * Type `health`: the data is heart rate and body motion. Its prerequisite is
 * satisfied by HIGH_SAMPLING_RATE_SENSORS (a normal permission) or the Health
 * Connect heart-rate permission.
 */
class SceneForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            running = false
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(this), type)
        running = true
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "scene_state"
        private const val NOTIFICATION_ID = 7301
        private const val ACTION_STOP = "ai.synheart.scene.STOP_STATE"
        private const val NORMAL_TEXT = "Heart rate and how you use your phone, never content. Stop it in Scene's Settings."

        @Volatile private var running = false

        /** A problem to show instead of the normal line (e.g. the watch went quiet); null clears it. */
        @Volatile private var problem: String? = null

        fun start(context: Context) {
            val intent = Intent(context, SceneForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
        }

        fun stop(context: Context) {
            problem = null
            context.startService(Intent(context, SceneForegroundService::class.java).setAction(ACTION_STOP))
        }

        fun setProblem(context: Context, text: String?) {
            if (problem == text) return
            problem = text
            if (!running) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, notification(context))
        }

        private fun notification(context: Context): Notification {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Current state", NotificationManager.IMPORTANCE_LOW).apply {
                        description = "Shown while Scene reads your current state in the background."
                    },
                )
            }
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE,
            )
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle("Scene is reading your current state")
                .setContentText(problem ?: NORMAL_TEXT)
                .setOnlyAlertOnce(true)
                // The logo's play-button "i" as a white silhouette; tinted with its red.
                .setSmallIcon(R.drawable.ic_stat_scene)
                .setColor(0xFFDC1929.toInt())
                .setOngoing(true)
                .setContentIntent(open)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .build()
        }
    }
}
