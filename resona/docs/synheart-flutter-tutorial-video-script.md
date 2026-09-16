# Build an Adaptive Flutter App with Synheart

## Step-by-step tutorial video script

**Working title:** Build an App That Responds to Human State with Flutter and Synheart

**Target length:** 10–12 minutes

**Audience:** Flutter developers integrating Synheart for the first time

**Demo input:** A real Bluetooth heart-rate monitor with heart rate and RR intervals

**Demo output:** A compact Flutter screen that shows the wearable signal, trustworthy HSI values, and an adaptive experience card

> Production note: keep the code shown in this tutorial generic. Resona appears only as an example of what this integration can unlock. Do not expose private credentials, capability tokens, user identifiers, or proprietary runtime artifacts in the recording.

---

## Before recording

Prepare the following:

- Flutter 3.32 or newer
- Xcode with an iOS 15+ target, or Android Studio with Android API 28+
- A Synheart developer account and CLI access
- A Synheart app configured for development
- A compatible BLE heart-rate monitor that exposes the standard Heart Rate Service
- The monitor awake, worn, and close to the phone
- A physical iPhone or Android phone; do not use a simulator for the live wearable section

Record the terminal at a readable font size. Blur account names, filesystem paths, QR codes, device identifiers, and signing information where needed.

---

## 0:00–0:30 — Cold open: show the outcome

### Visual

Start with a polished, silent montage of Resona:

1. Open the music library.
2. Start a track.
3. Briefly show the wearable status in Settings.
4. Show the state character changing.
5. Show the recommendation for a softer soundtrack.
6. End on the adapted player.

Then cut to the small tutorial app. Its screen should show:

- `BLE monitor · Live`
- current BPM
- Focus, Arousal, Capacity, and Stress
- an experience card that changes only when a reliable state arrives

### Voiceover

> “What if an application could respond not only to what a person taps, but to how their state is changing?”

> “This is Resona, a music experience built with Synheart. In this tutorial, we’ll build the small, real integration behind an experience like this—from a new Flutter project to live wearable signals, on-device HSI, and a safe adaptive response.”

### On-screen title

**Flutter + Synheart**

*From wearable signal to adaptive experience*

---

## 0:30–1:10 — Explain the architecture

### Visual

Show this simple diagram:

```text
Wearable
   ↓ HR + RR
Synheart Flutter SDK
   ↓
On-device Synheart Runtime
   ↓ HSI value + confidence
Your app's experience policy
   ↓
Subtle UI or content adaptation
```

### Voiceover

> “There are four parts to the workflow.”

> “The wearable provides consented measurements such as heart rate and beat-to-beat intervals. The Flutter SDK gives the host app a clean integration layer. The native Synheart Runtime processes the signals on device and produces the Human State Interface, or HSI. Finally, the application decides how—or whether—to respond.”

> “Synheart produces context. Your app owns the experience policy. A single score should never directly control the interface without checking that the reading is available, fresh, and sufficiently confident.”

### On-screen callout

**Runtime → SDK → host application**

---

## 1:10–1:55 — Create the Flutter project

### Visual

Open a terminal and run:

```bash
flutter create adaptive_synheart_demo
cd adaptive_synheart_demo
flutter pub add synheart_core synheart_wear permission_handler
```

### Voiceover

> “We’ll begin with a normal Flutter application.”

> “The Core package exposes sessions and typed HSI output. The Wear package provides wearable integrations, including direct BLE heart-rate monitors and platform health sources. Permission Handler is used here for Android Bluetooth permissions.”

> “Adding the Dart packages is only half of the installation. The Human State Interface is computed by the separately installed native runtime.”

---

## 1:55–2:35 — Install the Synheart Runtime

### Visual

Show the following commands. If the CLI is already installed, begin with `synheart login`.

```bash
curl -fsSL https://synheart.sh/install | sh
synheart login

# Run these in the Flutter project root.
synheart install runtime
synheart install syni
```

Then show the generated `synheart.lock` file without exposing sensitive content.

### Voiceover

> “The Synheart CLI installs the native runtime artifacts for the host platforms. On iOS, install Syni as well because the Flutter Core package links its native framework.”

> “The generated lock file pins the installed artifacts by hash. Commit that lock file so development machines and CI can restore the same runtime with `synheart sync`.”

### On-screen note

```bash
synheart sync
```

*Restores the runtime versions pinned by `synheart.lock`.*

---

## 2:35–3:35 — Configure the platforms

### iOS visual

In `ios/Podfile`, near the top, add:

```ruby
ENV['SYNHEART_APP_ROOT'] = File.expand_path('..', __dir__)
```

For direct BLE, add this to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app connects to a heart-rate monitor that you choose.</string>
```

If the app will also read Apple Health, enable the HealthKit capability in Xcode and add:

```xml
<key>NSHealthShareUsageDescription</key>
<string>This app reads heart-rate and HRV data with your permission.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>This app does not write health data.</string>
```

### Android visual

Set the wearable-compatible minimum in `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    minSdk = 28
}
```

Add the BLE permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission
    android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30" />
<uses-permission
    android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30" />
<uses-permission
    android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission
    android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="30" />
```

### Voiceover

> “Platform configuration depends on the sources your application enables. For this tutorial, direct BLE needs a Bluetooth usage description on iOS and the appropriate scan and connection permissions on Android.”

> “Only declare access your application actually uses, explain it before opening the system prompt, and keep wearable connection inside a clear Settings or onboarding flow.”

> “If you later add Apple Health or Health Connect, follow the additional platform-health configuration in the Synheart documentation. Those sources are useful for health records, while truly continuous Apple Watch delivery requires an active watch workout or companion experience.”

---

## 3:35–4:35 — Initialize Synheart and obtain consent

### Visual

Create `lib/synheart_controller.dart` and begin with:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:synheart_core/synheart_core.dart';
import 'package:synheart_wear/synheart_wear.dart';

class SynheartController extends ChangeNotifier {
  StreamSubscription<HSIState>? _hsiSubscription;
  StreamSubscription<HeartRateSample>? _bleSubscription;
  final BleHrmProvider _ble = BleHrmProvider();

  HSIState? latestState;
  double? heartRate;
  String status = 'Not connected';

  Future<void> initialize({required String subjectId}) async {
    await Synheart.initialize(
      config: SynheartConfig(
        appId: 'com.example.adaptive_synheart_demo',
        subjectId: subjectId,
        appVersion: '1.0.0',
        appName: 'Adaptive Synheart Demo',
        category: 'Demo',
        developer: 'Example Developer',
        wearConfig: const WearConfig(
          enableHighFrequencyHrv: true,
        ),
      ),
    );

    await Synheart.grantConsent(
      biosignals: true,
      phoneContext: false,
      behavior: false,
      cloudUpload: false,
    );
  }
}
```

### Voiceover

> “Initialize Synheart once with the identity and modules needed by the application.”

> “The subject ID should be a stable pseudonymous identifier from your own account system—not an email address and not a value invented again on every launch.”

> “Consent is a product flow, not just a line of code. Before granting biosignal access here, the real app should explain what it reads, why it reads it, how it is processed, and how the user can revoke access.”

> “This example keeps cloud upload off. HSI can be computed locally without sending raw biosignals to your server.”

### Developer-mode note

If your development app has not yet been provisioned with production capability handling, the Synheart dashboard may provide a development configuration. Do not show or recommend unsigned capabilities as a production setup.

---

## 4:35–5:10 — Start a session and listen for HSI

### Visual

Continue the controller:

```dart
Future<void> startSession() async {
  _hsiSubscription = Synheart.onStateUpdate.listen(
    _handleState,
    onError: (Object error) {
      status = 'HSI error';
      notifyListeners();
    },
  );

  await Synheart.startSession();
  Synheart.setTaskType(TaskType.focus);
  Synheart.setFocusKind(FocusKind.medium);
}
```

### Voiceover

> “Initialization prepares the SDK; the session defines the period we want to measure.”

> “Subscribe before starting so the app cannot miss the first HSI update. We also provide lightweight task context: this experience is designed to support a medium-focus activity.”

> “The runtime closes HSI windows on a fixed cadence of roughly sixty seconds. A completed window does not automatically mean the state is usable, so we’ll add trust checks before adapting anything.”

---

## 5:10–6:30 — Scan and connect a real BLE wearable

### Visual

Add scanning:

```dart
Future<List<BleHrmDevice>> scanForMonitors() async {
  final permission = await _ble.requestPermission();
  if (permission != 'granted') {
    throw StateError('Bluetooth permission was not granted.');
  }

  await _ble.warmAdapter();
  return _ble.scan(timeoutMs: 6000);
}
```

Add connection and ingestion:

```dart
Future<void> connect(BleHrmDevice device) async {
  await _ble.connect(
    deviceId: device.deviceId,
    sessionId: 'session-${DateTime.now().millisecondsSinceEpoch}',
    enableBattery: true,
  );

  _bleSubscription = _ble.onHeartRate.listen((sample) {
    heartRate = sample.bpm;
    status = '${device.name} · Live';

    Synheart.pushWearHr(
      sample.tsMs,
      sample.bpm,
      provider: 'ble_hrm',
    );

    if (sample.rrIntervalsMs.isNotEmpty) {
      Synheart.pushRrBatch(
        sample.tsMs,
        sample.rrIntervalsMs,
        provider: 'ble_hrm',
      );
    }

    notifyListeners();
  });
}
```

### Android recording note

Before scanning on Android, request `Permission.bluetoothScan` and `Permission.bluetoothConnect` with `permission_handler`. Devices running Android 11 or earlier also use the legacy location permission declared in the manifest.

### Voiceover

> “The user chooses Connect in Settings, not in the main experience. We request permission at that moment, scan nearby standard heart-rate devices, and show the discovered devices by name and signal strength.”

> “After the user selects a monitor, its heart-rate stream gives us BPM and, when the hardware supports it, RR intervals.”

> “We push both into Core. Heart rate gives the runtime a vital signal, while RR intervals provide the beat-to-beat variation needed for stronger physiological context. Never fabricate missing RR intervals.”

> “At this point, show the phone and the monitor together. The BPM in the app should closely follow the device.”

### Visual verification

Show:

- the selected device name
- `Live`
- BPM changing naturally
- an unobtrusive waiting state for HSI

---

## 6:30–7:45 — Accept only trustworthy HSI

### Visual

Add an experience mode and the HSI handler:

```dart
enum ExperienceMode { waiting, steady, lighter, calming }

ExperienceMode mode = ExperienceMode.waiting;

void _handleState(HSIState state) {
  latestState = state;

  if (state.hasParseError) {
    mode = ExperienceMode.waiting;
    notifyListeners();
    return;
  }

  final ageMs = DateTime.now().millisecondsSinceEpoch - state.timestampMs;
  if (ageMs > const Duration(seconds: 90).inMilliseconds) {
    mode = ExperienceMode.waiting;
    notifyListeners();
    return;
  }

  final focus = state.hsi.focus;
  final arousal = state.hsi.arousal;
  final stress = state.hsi.stress;

  if (_usable(stress) && stress!.value >= 0.62 ||
      _usable(arousal) && arousal!.value >= 0.76) {
    mode = ExperienceMode.calming;
  } else if (_usable(focus) && focus!.value < 0.44) {
    mode = ExperienceMode.lighter;
  } else if (_usable(focus) && focus!.value >= 0.60) {
    mode = ExperienceMode.steady;
  } else {
    mode = ExperienceMode.waiting;
  }

  notifyListeners();
}

bool _usable(HSIAxisValue? axis) =>
    axis != null && axis.confidence >= 0.65;
```

### Voiceover

> “Every HSI axis contains a value and a confidence. The value answers what the current estimate is. Confidence answers whether the runtime has enough evidence to support that estimate.”

> “First, reject parse failures. Next, reject stale states. Then check each axis independently because one axis can be available while another is not.”

> “For this demo, the experience policy requires at least sixty-five percent confidence. These thresholds are product policy, not universal truths. Validate them for your use case and avoid medical or safety-critical interpretations.”

> “When the evidence is insufficient, the correct state is waiting or unavailable—not a negative judgment about the person.”

### On-screen callout

```text
value ≠ certainty

Check:
✓ parsed
✓ fresh
✓ confidence threshold met
```

---

## 7:45–8:45 — Adapt the experience without taking control away

### Visual

Show a compact Flutter widget driven by the controller:

```dart
String messageFor(ExperienceMode mode) => switch (mode) {
  ExperienceMode.waiting => 'Learning your current rhythm',
  ExperienceMode.steady => 'A steady pace may support your momentum',
  ExperienceMode.lighter => 'A clearer rhythm may help you reconnect',
  ExperienceMode.calming => 'A softer pace may help you settle',
};
```

Then show the UI behavior:

1. The card starts in `Learning your current rhythm`.
2. A trustworthy state arrives.
3. The copy and accent color transition subtly.
4. A recommendation appears.
5. The user can accept it or keep the current experience.

### Voiceover

> “Now the application translates the trusted state into experience language.”

> “Notice what we are not doing: we are not showing a diagnosis, claiming to know an emotion with certainty, or forcing a change.”

> “The app explains what it noticed, recommends one useful action, and leaves the final decision with the user.”

> “For repeated production updates, add hysteresis—such as requiring the same classification across multiple trustworthy windows—and a cooldown before presenting another recommendation. This prevents a borderline value from making the interface jump back and forth.”

### Recommended production policy graphic

```text
Trustworthy window
       ↓
Same state across multiple windows
       ↓
Recommendation cooldown satisfied
       ↓
Explain → recommend → let the user decide
```

---

## 8:45–9:30 — Show Apple Watch and Health Connect as alternatives

### Visual

Return to the architecture diagram and branch the wearable source:

```text
Direct BLE HR monitor ─┐
Apple Health ──────────┼─→ Synheart Core → HSI
Health Connect ────────┘
```

Show this abbreviated platform-health collection code:

```dart
final wearSubscription = Synheart.wearSampleStream.listen((sample) {
  final timestamp = sample.timestamp.millisecondsSinceEpoch;

  if (sample.hr case final hr? when hr > 0) {
    Synheart.pushWearHr(timestamp, hr, provider: 'platform_health');
  }

  final rr = sample.rrIntervals ?? const <double>[];
  if (rr.isNotEmpty) {
    Synheart.pushRrBatch(timestamp, rr, provider: 'platform_health');
  }

  if (sample.hrvRmssd case final hrv? when hrv > 0) {
    Synheart.pushVendorHrv(
      timestamp,
      rmssd: hrv,
      provider: 'platform_health',
    );
  }
});

await Synheart.startWearCollection(
  interval: const Duration(seconds: 1),
);
```

### Voiceover

> “The rest of the application does not need to care which approved source supplied the signal.”

> “You can replace direct BLE with Apple Health on iOS or Health Connect on Android. The controller normalizes the samples and the same HSI listener continues to drive the experience.”

> “There is one important distinction: platform health APIs expose data recorded into the health store. Truly continuous, second-by-second Apple Watch streaming normally requires an active workout and a dedicated watch companion. Choose the source based on the latency and signal quality your experience actually needs.”

---

## 9:30–10:05 — Clean up the lifecycle

### Visual

Complete the controller:

```dart
Future<void> stop() async {
  await _bleSubscription?.cancel();
  _bleSubscription = null;

  if (await _ble.isConnected()) {
    await _ble.disconnect();
  }

  if (Synheart.isWearCollecting) {
    await Synheart.stopWearCollection();
  }

  await Synheart.stopSession();
  await _hsiSubscription?.cancel();
  _hsiSubscription = null;
  await Synheart.dispose();

  status = 'Not connected';
  heartRate = null;
  latestState = null;
  mode = ExperienceMode.waiting;
  notifyListeners();
}
```

### Voiceover

> “Treat the wearable and Synheart session as explicit resources.”

> “Cancel subscriptions, disconnect the active transport, stop collection, close the session, and dispose the SDK when the integration is no longer needed or the signed-in identity changes.”

> “If the wearable drops unexpectedly, keep the last UI from becoming a new claim. Mark it stale, return to a waiting state, and offer reconnection from Settings.”

---

## 10:05–10:45 — Verify the full pipeline

### Visual

Show each item becoming checked:

```text
✓ Native runtime available
✓ Wearable connected
✓ BPM updating
✓ RR intervals received
✓ HSI windows arriving
✓ Required axis confidence met
✓ UI adaptation presented
✓ User remains in control
```

Show runtime diagnostics:

```dart
final diagnostics = Synheart.runtimeDiagnostics();
debugPrint('Runtime available: ${diagnostics['isAvailable']}');
debugPrint('Runtime version: ${diagnostics['version']}');
debugPrint('HSI frames: ${diagnostics['frameCount']}');
debugPrint('Missing symbols: ${diagnostics['missingSymbols']}');
```

### Voiceover

> “Verify the pipeline in order. A connected badge alone is not enough. Confirm that BPM changes, RR intervals arrive when supported, HSI frame count increases, and the axis used by your policy meets its confidence requirement.”

> “If an axis remains at zero confidence, inspect the input coverage first. It usually means the runtime does not yet have enough evidence for that axis—not that the user scored zero.”

---

## 10:45–11:20 — Closing

### Visual

Transition from the compact tutorial app back to Resona. Show the recommendation and smooth track change once more.

End on:

**Synheart**

*Human-state intelligence for adaptive experiences.*

Then:

**Built with Flutter**

### Voiceover

> “We started with a new Flutter project, connected a real wearable, sent heart rate and RR intervals into the on-device Synheart Runtime, listened for typed HSI updates, and adapted the experience only when the evidence was fresh and confident.”

> “Music is just one example. The same pattern can support learning tools, games, wellness experiences, and digital environments that respond more thoughtfully to the person using them.”

> “Synheart gives developers meaningful human-state context. What you build with that context—and how respectfully you use it—remains an experience decision.”

---

## Clean voiceover script

What if an application could respond not only to what a person taps, but to how their state is changing?

This is Resona, a music experience built with Synheart. In this tutorial, we’ll build the small, real integration behind an experience like this—from a new Flutter project to live wearable signals, on-device HSI, and a safe adaptive response.

There are four parts to the workflow. The wearable provides consented measurements such as heart rate and beat-to-beat intervals. The Flutter SDK gives the host app a clean integration layer. The native Synheart Runtime processes the signals on device and produces the Human State Interface, or HSI. Finally, the application decides how—or whether—to respond.

Synheart produces context. Your app owns the experience policy. A single score should never directly control the interface without checking that the reading is available, fresh, and sufficiently confident.

We’ll begin with a normal Flutter application. The Core package exposes sessions and typed HSI output. The Wear package provides wearable integrations, including direct BLE heart-rate monitors and platform health sources. Permission Handler is used here for Android Bluetooth permissions.

Adding the Dart packages is only half of the installation. The Human State Interface is computed by the separately installed native runtime.

The Synheart CLI installs the native runtime artifacts for the host platforms. On iOS, install Syni as well because the Flutter Core package links its native framework.

The generated lock file pins the installed artifacts by hash. Commit that lock file so development machines and CI can restore the same runtime with Synheart sync.

Platform configuration depends on the sources your application enables. For this tutorial, direct BLE needs a Bluetooth usage description on iOS and the appropriate scan and connection permissions on Android.

Only declare access your application actually uses, explain it before opening the system prompt, and keep wearable connection inside a clear Settings or onboarding flow.

If you later add Apple Health or Health Connect, follow the additional platform-health configuration in the Synheart documentation. Those sources are useful for health records, while truly continuous Apple Watch delivery requires an active watch workout or companion experience.

Initialize Synheart once with the identity and modules needed by the application.

The subject ID should be a stable pseudonymous identifier from your own account system—not an email address and not a value invented again on every launch.

Consent is a product flow, not just a line of code. Before granting biosignal access here, the real app should explain what it reads, why it reads it, how it is processed, and how the user can revoke access.

This example keeps cloud upload off. HSI can be computed locally without sending raw biosignals to your server.

Initialization prepares the SDK; the session defines the period we want to measure.

Subscribe before starting so the app cannot miss the first HSI update. We also provide lightweight task context: this experience is designed to support a medium-focus activity.

The runtime closes HSI windows on a fixed cadence of roughly sixty seconds. A completed window does not automatically mean the state is usable, so we’ll add trust checks before adapting anything.

The user chooses Connect in Settings, not in the main experience. We request permission at that moment, scan nearby standard heart-rate devices, and show the discovered devices by name and signal strength.

After the user selects a monitor, its heart-rate stream gives us BPM and, when the hardware supports it, RR intervals.

We push both into Core. Heart rate gives the runtime a vital signal, while RR intervals provide the beat-to-beat variation needed for stronger physiological context. Never fabricate missing RR intervals.

At this point, show the phone and the monitor together. The BPM in the app should closely follow the device.

Every HSI axis contains a value and a confidence. The value answers what the current estimate is. Confidence answers whether the runtime has enough evidence to support that estimate.

First, reject parse failures. Next, reject stale states. Then check each axis independently because one axis can be available while another is not.

For this demo, the experience policy requires at least sixty-five percent confidence. These thresholds are product policy, not universal truths. Validate them for your use case and avoid medical or safety-critical interpretations.

When the evidence is insufficient, the correct state is waiting or unavailable—not a negative judgment about the person.

Now the application translates the trusted state into experience language.

Notice what we are not doing: we are not showing a diagnosis, claiming to know an emotion with certainty, or forcing a change.

The app explains what it noticed, recommends one useful action, and leaves the final decision with the user.

For repeated production updates, add hysteresis—such as requiring the same classification across multiple trustworthy windows—and a cooldown before presenting another recommendation. This prevents a borderline value from making the interface jump back and forth.

The rest of the application does not need to care which approved source supplied the signal.

You can replace direct BLE with Apple Health on iOS or Health Connect on Android. The controller normalizes the samples and the same HSI listener continues to drive the experience.

There is one important distinction: platform health APIs expose data recorded into the health store. Truly continuous, second-by-second Apple Watch streaming normally requires an active workout and a dedicated watch companion. Choose the source based on the latency and signal quality your experience actually needs.

Treat the wearable and Synheart session as explicit resources.

Cancel subscriptions, disconnect the active transport, stop collection, close the session, and dispose the SDK when the integration is no longer needed or the signed-in identity changes.

If the wearable drops unexpectedly, keep the last UI from becoming a new claim. Mark it stale, return to a waiting state, and offer reconnection from Settings.

Verify the pipeline in order. A connected badge alone is not enough. Confirm that BPM changes, RR intervals arrive when supported, HSI frame count increases, and the axis used by your policy meets its confidence requirement.

If an axis remains at zero confidence, inspect the input coverage first. It usually means the runtime does not yet have enough evidence for that axis—not that the user scored zero.

We started with a new Flutter project, connected a real wearable, sent heart rate and RR intervals into the on-device Synheart Runtime, listened for typed HSI updates, and adapted the experience only when the evidence was fresh and confident.

Music is just one example. The same pattern can support learning tools, games, wellness experiences, and digital environments that respond more thoughtfully to the person using them.

Synheart gives developers meaningful human-state context. What you build with that context—and how respectfully you use it—remains an experience decision.

---

## Suggested description for the published video

Build a Flutter experience that responds to trustworthy human-state context with Synheart. This tutorial starts with a new project, installs the native Synheart Runtime, connects a real BLE heart-rate monitor, ingests heart rate and RR intervals, listens for typed HSI updates, and safely adapts the UI using freshness and confidence checks.

This tutorial demonstrates a wellness-oriented developer workflow. Synheart is not a medical device, and HSI output must not be used to diagnose, treat, cure, or prevent disease.

## Suggested chapter markers

```text
00:00 What we are building
00:30 How Synheart works
01:10 Create the Flutter project
01:55 Install the Synheart Runtime
02:35 Configure iOS and Android
03:35 Initialize Synheart and consent
04:35 Start a session
05:10 Connect a BLE wearable
06:30 Validate HSI confidence and freshness
07:45 Adapt the experience safely
08:45 Apple Watch and Health Connect
09:30 Lifecycle cleanup
10:05 Verify the complete pipeline
10:45 Final result
```
