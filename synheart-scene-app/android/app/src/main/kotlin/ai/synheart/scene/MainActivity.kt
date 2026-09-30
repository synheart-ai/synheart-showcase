package ai.synheart.scene

import io.flutter.embedding.android.FlutterFragmentActivity

// A fragment activity: Health Connect's permission request uses the
// ActivityResult API. It attaches to the engine [SceneApplication] created
// and cached, and leaves it running when it is destroyed, so collection
// continues in the background (see SceneForegroundService).
class MainActivity : FlutterFragmentActivity() {
    override fun getCachedEngineId(): String = SceneApplication.ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false
}
