package ai.synheart.scene.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/** What the watch screen shows. */
data class StreamStatus(
    val streaming: Boolean = false,
    val bpm: Double? = null,
    val sent: Int = 0,
    val phoneReachable: Boolean = true,
    val error: String? = null,
)

/**
 * A health-type foreground service, so heart rate keeps streaming to the phone
 * with the screen off. Stops when the user taps Stop on the watch or the phone
 * sends stopHrStream.
 */
class StreamService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var stream: HeartRateStream? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        if (stream == null) {
            val hr = HeartRateStream(this) { bpm, ts ->
                scope.launch {
                    val reached = PhoneLink.sendHeartRate(this@StreamService, bpm, ts)
                    val s = mutableStatus.value
                    mutableStatus.value = s.copy(bpm = bpm, sent = s.sent + if (reached) 1 else 0, phoneReachable = reached)
                }
            }
            val error = hr.start()
            if (error != null) {
                mutableStatus.value = StreamStatus(error = error)
                scope.launch { PhoneLink.sendEvent(this@StreamService, "stream_error", error) }
                stopSelf()
                return START_NOT_STICKY
            }
            stream = hr
            mutableStatus.value = StreamStatus(streaming = true)
            scope.launch { PhoneLink.sendEvent(this@StreamService, "stream_started") }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stream?.stop()
        stream = null
        mutableStatus.value = mutableStatus.value.copy(streaming = false)
        // Tell the phone before the scope goes away.
        CoroutineScope(Dispatchers.IO).launch { PhoneLink.sendEvent(applicationContext, "stream_stopped") }
        scope.cancel()
        super.onDestroy()
    }

    private fun notification(): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Heart-rate streaming", NotificationManager.IMPORTANCE_LOW))
        return NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle("Scene")
            .setContentText("Sending heart rate to your phone")
            .setSmallIcon(R.drawable.ic_heart)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL = "scene_stream"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_STOP = "ai.synheart.scene.wear.STOP"

        private val mutableStatus = MutableStateFlow(StreamStatus())
        val status: StateFlow<StreamStatus> = mutableStatus

        fun start(context: Context) = ContextCompat.startForegroundService(context, Intent(context, StreamService::class.java))

        fun stop(context: Context) {
            context.startService(Intent(context, StreamService::class.java).setAction(ACTION_STOP))
        }
    }
}
