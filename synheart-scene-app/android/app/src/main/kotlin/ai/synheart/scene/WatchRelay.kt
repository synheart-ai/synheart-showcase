package ai.synheart.scene

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Bridges the Scene watch app (Wear OS Data Layer) to Flutter. Messages
 * arrive only through [PhoneWearListenerService]; registering a MessageClient
 * listener as well would deliver each one twice.
 */
class WatchRelay private constructor(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // The nearest connected watch's name, or null when none is connected.
            "connectedWatch" -> Wearable.getNodeClient(context).connectedNodes
                .addOnSuccessListener { nodes ->
                    val node = nodes.sortedByDescending { it.isNearby }.firstOrNull()
                    result.success(node?.displayName?.ifBlank { "Wear OS watch" })
                }
                .addOnFailureListener { result.success(null) }
            "startStream" -> sendCommand("startHrStream", result)
            "stopStream" -> sendCommand("stopHrStream", result)
            else -> result.notImplemented()
        }
    }

    private fun sendCommand(command: String, result: MethodChannel.Result) {
        val payload = JSONObject().put("command", command).toString().toByteArray()
        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes ->
                nodes.forEach { Wearable.getMessageClient(context).sendMessage(it.id, PATH_COMMAND, payload) }
                result.success(nodes.isNotEmpty())
            }
            .addOnFailureListener { result.success(false) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun handle(path: String, bytes: ByteArray) {
        val json = try {
            JSONObject(String(bytes))
        } catch (e: Exception) {
            Log.w(TAG, "bad message on $path: ${e.message}")
            return
        }
        val event: Map<String, Any?> = when (path) {
            PATH_HR_SAMPLE -> mapOf(
                "type" to "hr_sample",
                "bpm" to json.optDouble("bpm", 0.0),
                "timestamp" to json.optLong("timestamp", System.currentTimeMillis()),
            )
            PATH_EVENT -> mapOf("type" to json.optString("type"), "message" to json.optString("message").ifBlank { null })
            else -> return
        }
        main.post { sink?.success(event) }
    }

    companion object {
        private const val TAG = "SceneWatchRelay"
        const val PATH_HR_SAMPLE = "/synheart/session/hr_sample"
        const val PATH_EVENT = "/synheart/session/event"
        const val PATH_COMMAND = "/synheart/session/command"

        @Volatile private var active: WatchRelay? = null

        fun register(messenger: BinaryMessenger, context: Context) {
            val relay = WatchRelay(context)
            active = relay
            MethodChannel(messenger, "ai.synheart.scene/watch").setMethodCallHandler(relay)
            EventChannel(messenger, "ai.synheart.scene/watch_events").setStreamHandler(relay)
        }

        /** Called by [PhoneWearListenerService]. Dropped if Flutter is not running. */
        fun dispatch(path: String, bytes: ByteArray) {
            val relay = active
            if (relay == null) {
                Log.w(TAG, "dropped $path: Flutter not attached")
                return
            }
            relay.handle(path, bytes)
        }
    }
}
