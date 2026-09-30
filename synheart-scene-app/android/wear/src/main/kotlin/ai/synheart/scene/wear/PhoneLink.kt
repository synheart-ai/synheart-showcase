package ai.synheart.scene.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

/**
 * Sends to the Scene phone app over the Wearable Data Layer, on the
 * `/synheart/session/…` paths the phone relay listens on.
 */
internal object PhoneLink {
    const val PATH_HR_SAMPLE = "/synheart/session/hr_sample"
    const val PATH_EVENT = "/synheart/session/event"
    const val PATH_COMMAND = "/synheart/session/command"
    private const val TAG = "ScenePhoneLink"

    /** Heart rate only: Health Services' HEART_RATE_BPM carries no RR intervals. */
    suspend fun sendHeartRate(context: Context, bpm: Double, timestampMs: Long): Boolean =
        send(context, PATH_HR_SAMPLE, JSONObject().put("bpm", bpm).put("timestamp", timestampMs).put("source", "wear_health_services"))

    suspend fun sendEvent(context: Context, type: String, message: String? = null): Boolean =
        send(context, PATH_EVENT, JSONObject().put("type", type).apply { if (message != null) put("message", message) })

    /** True when at least one phone received it. */
    private suspend fun send(context: Context, path: String, json: JSONObject): Boolean = try {
        val nodes = Wearable.getNodeClient(context).connectedNodes.await()
        val client = Wearable.getMessageClient(context)
        nodes.forEach { client.sendMessage(it.id, path, json.toString().toByteArray()).await() }
        nodes.isNotEmpty()
    } catch (e: Exception) {
        Log.w(TAG, "send $path failed: ${e.message}")
        false
    }
}
