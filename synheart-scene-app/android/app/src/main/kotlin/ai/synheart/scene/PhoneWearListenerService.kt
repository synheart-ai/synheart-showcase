package ai.synheart.scene

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/** Receives the Scene watch app's messages (heart rate, stream events). */
class PhoneWearListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path.startsWith("/synheart/session/")) WatchRelay.dispatch(event.path, event.data)
    }
}
