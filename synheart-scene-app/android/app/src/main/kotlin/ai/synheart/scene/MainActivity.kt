package ai.synheart.scene

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// A fragment activity: Health Connect's permission request uses the
// ActivityResult API.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WatchRelay.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
    }
}
