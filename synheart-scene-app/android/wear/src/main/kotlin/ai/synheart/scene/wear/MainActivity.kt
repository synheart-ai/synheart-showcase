package ai.synheart.scene.wear

import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text

/**
 * Scene on the Galaxy Watch: one screen. It streams live heart rate to the
 * Scene phone app, where the Synheart runtime computes HSI.
 */
class MainActivity : ComponentActivity() {
    private val granted = mutableStateOf(false)
    private val request = registerForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        granted.value = ok
        if (ok) StreamService.start(this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        granted.value = hasPermission()
        setContent {
            MaterialTheme {
                val status by StreamService.status.collectAsState()
                val ok by remember { granted }
                SceneWatch(
                    status = status,
                    permissionGranted = ok,
                    onStart = { if (hasPermission()) StreamService.start(this) else request.launch(WatchPermissions.heartRate()) },
                    onStop = { StreamService.stop(this) },
                )
            }
        }
    }

    private fun hasPermission() =
        ContextCompat.checkSelfPermission(this, WatchPermissions.heartRate()) == PackageManager.PERMISSION_GRANTED
}

private val Ink = Color(0xFFE8F0EC)
private val Sage = Color(0xFFA9BFB2)
private val Heart = Color(0xFFE0697A)

@Composable
private fun SceneWatch(status: StreamStatus, permissionGranted: Boolean, onStart: () -> Unit, onStop: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("SCENE", color = Sage, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp)
        Spacer(Modifier.height(4.dp))
        Text(
            text = status.bpm?.let { "${it.toInt()}" } ?: "—",
            color = if (status.streaming) Heart else Ink,
            fontSize = 40.sp,
            fontWeight = FontWeight.Bold,
        )
        Text("BPM", color = Sage, fontSize = 12.sp)
        Spacer(Modifier.height(6.dp))
        Text(
            text = when {
                status.error != null -> status.error
                !permissionGranted -> "Allow heart rate to stream to Scene on your phone."
                status.streaming && !status.phoneReachable -> "Phone not reachable"
                status.streaming -> "Streaming to your phone"
                else -> "Ready"
            },
            color = Ink,
            fontSize = 12.sp,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(10.dp))
        Button(
            onClick = if (status.streaming) onStop else onStart,
            colors = ButtonDefaults.buttonColors(backgroundColor = if (status.streaming) Color(0xFF3A3C3B) else Heart),
        ) {
            Text(if (status.streaming) "Stop" else "Start")
        }
    }
}
