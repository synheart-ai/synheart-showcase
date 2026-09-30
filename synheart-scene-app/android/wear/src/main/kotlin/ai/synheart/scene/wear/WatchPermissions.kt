package ai.synheart.scene.wear

import android.Manifest
import android.os.Build

/**
 * Which heart-rate permission this watch uses.
 *
 * Android 16 (API 36) replaced BODY_SENSORS with the granular Health Connect
 * permissions for apps targeting API 36+, including HEART_RATE_BPM from Health
 * Services. On an API 36+ watch a BODY_SENSORS request is silently dropped: no
 * dialog, permission stays denied, and heart rate never starts. The choice is
 * made per device SDK.
 */
internal object WatchPermissions {
    fun heartRate(): String =
        if (Build.VERSION.SDK_INT >= ANDROID_16) READ_HEART_RATE else Manifest.permission.BODY_SENSORS

    private const val ANDROID_16 = 36
    private const val READ_HEART_RATE = "android.permission.health.READ_HEART_RATE"
}
