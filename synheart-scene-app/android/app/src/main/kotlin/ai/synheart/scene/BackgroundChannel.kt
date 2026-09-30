package ai.synheart.scene

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `ai.synheart.scene/background`: start / stop [SceneForegroundService], and
 * the Notification access that synheart_behavior's notification listener
 * needs (only the person can grant it, in system Settings).
 */
object BackgroundChannel {
    fun register(messenger: BinaryMessenger, context: Context) {
        val app = context.applicationContext
        MethodChannel(messenger, "ai.synheart.scene/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> try {
                    SceneForegroundService.start(app)
                    result.success(true)
                } catch (e: Exception) {
                    // e.g. ForegroundServiceStartNotAllowedException when started from the background.
                    result.error("start_failed", e.message, null)
                }
                "stop" -> {
                    SceneForegroundService.stop(app)
                    result.success(true)
                }
                "notificationAccessGranted" ->
                    result.success(NotificationManagerCompat.getEnabledListenerPackages(app).contains(app.packageName))
                "openNotificationAccess" -> {
                    val component = ComponentName(app, "ai.synheart.behavior.SynheartNotificationListenerService")
                    // Android 11+ can open Scene's own entry directly; older versions show the list.
                    val intent = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                            .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, component.flattenToString())
                    } else {
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    app.startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
