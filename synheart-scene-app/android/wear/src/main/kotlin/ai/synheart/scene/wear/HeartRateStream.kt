package ai.synheart.scene.wear

import android.content.Context
import android.content.pm.PackageManager
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DeltaDataType
import java.time.Instant

/** Live heart rate from Wear OS Health Services' MeasureClient. */
internal class HeartRateStream(context: Context, private val onSample: (bpm: Double, timestampMs: Long) -> Unit) {
    private val appContext = context.applicationContext
    private val client = try {
        HealthServices.getClient(appContext).measureClient
    } catch (e: Exception) {
        Log.e(TAG, "Health Services unavailable: ${e.message}")
        null
    }
    private var callback: MeasureCallback? = null

    /** Returns an error message, or null when streaming started. */
    fun start(): String? {
        if (callback != null) return null
        val measure = client ?: return "This watch has no Health Services."
        if (ContextCompat.checkSelfPermission(appContext, WatchPermissions.heartRate()) != PackageManager.PERMISSION_GRANTED) {
            return "Heart-rate permission is not granted."
        }
        val cb = object : MeasureCallback {
            override fun onAvailabilityChanged(dataType: DeltaDataType<*, *>, availability: Availability) {
                Log.d(TAG, "HR availability: $availability")
            }

            override fun onDataReceived(data: DataPointContainer) {
                // Each point carries its own time since boot. Health Services
                // batches delivery when the watch is idle, so stamping points with
                // the delivery time would collapse a batch to one instant.
                val boot = Instant.ofEpochMilli(System.currentTimeMillis() - SystemClock.elapsedRealtime())
                for (dp in data.getData(DataType.HEART_RATE_BPM)) {
                    if (dp.value > 0) onSample(dp.value, dp.getTimeInstant(boot).toEpochMilli())
                }
            }
        }
        return try {
            measure.registerMeasureCallback(DataType.HEART_RATE_BPM, cb)
            callback = cb
            null
        } catch (e: Exception) {
            "Could not start heart rate: ${e.message}"
        }
    }

    fun stop() {
        val cb = callback ?: return
        try {
            client?.unregisterMeasureCallbackAsync(DataType.HEART_RATE_BPM, cb)
        } catch (e: Exception) {
            Log.w(TAG, "unregister failed: ${e.message}")
        }
        callback = null
    }

    private companion object {
        const val TAG = "SceneHeartRate"
    }
}
