package ai.synheart.scene

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Owns one Flutter engine for the life of the process, so Dart — and with it
 * the Synheart runtime, behavior collection and the watch relay — keeps
 * running after the activity is closed. [SceneForegroundService] keeps the
 * process alive; [MainActivity] only attaches to this engine.
 *
 * Without it the activity's engine is destroyed with the activity, and native
 * collectors keep sending to a detached engine ("FlutterJNI was detached"),
 * and background behavior events are dropped.
 */
class SceneApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        // A cached engine gets no automatic plugin registration from the activity.
        GeneratedPluginRegistrant.registerWith(engine)
        WatchRelay.register(engine.dartExecutor.binaryMessenger, this)
        BackgroundChannel.register(engine.dartExecutor.binaryMessenger, this)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "scene_engine"
    }
}
