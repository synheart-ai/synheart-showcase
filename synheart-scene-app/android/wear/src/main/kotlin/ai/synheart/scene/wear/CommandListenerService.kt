package ai.synheart.scene.wear

import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Start / stop commands from the phone. Android may refuse to start a
 * foreground service from the background; the phone is then told to ask the
 * user to open Scene on the watch.
 */
class CommandListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != PhoneLink.PATH_COMMAND) return
        val command = try {
            JSONObject(String(event.data)).optString("command")
        } catch (_: Exception) {
            return
        }
        when (command) {
            "startHrStream" -> try {
                StreamService.start(this)
            } catch (e: Exception) {
                Log.w("SceneCommands", "background start refused: ${e.message}")
                CoroutineScope(Dispatchers.IO).launch {
                    PhoneLink.sendEvent(applicationContext, "stream_error", "Open Scene on your watch and tap Start.")
                }
            }
            "stopHrStream" -> StreamService.stop(this)
        }
    }
}
