# Resona

**Music that understands the moment.**

Resona is a Flutter showcase for adaptive experiences built with the Synheart Human State Interface (HSI). It combines supported wearable signals, on-device state computation, and a user-controlled music player to demonstrate how an application can respond thoughtfully as the available evidence changes.

## What Resona demonstrates

- A polished Flutter music experience with background playback
- Apple Health on iOS and Health Connect on Android
- Direct standard BLE heart-rate monitor discovery and connection
- Heart-rate and RR-interval ingestion through Synheart Core
- Typed HSI updates computed by the native Synheart Runtime
- Confidence-aware state classification and graceful unavailable states
- User-controlled soundtrack recommendations rather than forced adaptation
- Motion-based album-art parallax and subtle state transitions
- iOS Live Activities and Dynamic Island playback context
- Media delivery through a range-aware Cloudflare Worker backed by R2

## How it works

```text
Apple Health / Health Connect / BLE heart-rate monitor
                         │
                         ▼
              Synheart Flutter SDK
                         │
                         ▼
             Native Synheart Runtime
          on-device HSI window computation
                         │
                         ▼
           Confidence-aware app policy
                         │
                         ▼
       Explain → recommend → user decides
```

Resona treats missing, stale, or low-confidence evidence as unavailable. It does not convert absent evidence into a negative judgment about the listener.

The included experience policy can present three kinds of support:

- **Flow:** maintain a steady soundtrack when focus evidence supports it
- **Finding focus:** recommend a clearer rhythm when focus appears to drift
- **Resetting:** recommend a softer soundtrack when elevated rhythm, arousal, stress, or reduced capacity supports that response

These thresholds are demo policy choices, not universal health interpretations.

## Wearable support

### Direct Bluetooth heart-rate monitors

Resona can scan for and connect to devices implementing the standard Bluetooth Heart Rate Service. Heart rate and available RR intervals are forwarded to Synheart Core for HSI computation.

This is the most direct live-data path in the showcase.

### Apple Watch through Apple Health

On iOS, Resona can read heart-rate and HRV records made available through Apple Health. HealthKit access requires explicit permission from the user.

Apple Health is a health-record source. Truly continuous, second-by-second Apple Watch delivery generally requires an active workout and a dedicated watch companion, which is outside this showcase's current scope.

### Health Connect

On Android, supported wearable data can be read through Health Connect after the user grants the corresponding record permissions.

## Requirements

- Flutter 3.32 or newer
- Dart 3.8 or newer
- iOS 15 or newer, or Android API 28 or newer
- Xcode for iOS builds or Android Studio for Android builds
- Access to the Synheart CLI and native Runtime artifacts
- A physical device for wearable testing
- A compatible wearable source for real physiological input

## Setup

### 1. Install Flutter dependencies

From this directory:

```bash
flutter pub get
```

### 2. Install the Synheart Runtime

The Dart packages do not contain the native runtime. Install the Synheart CLI, authenticate, and provision the artifacts from the `resona` project root:

```bash
curl -fsSL https://synheart.sh/install | sh
synheart login
synheart install runtime
synheart install syni
```

The Syni runtime is required for the current iOS dependency graph even when the app does not directly use Syni features.

The installed binaries live under `synheart/vendor/` and are intentionally excluded from Git. A provisioned project should commit its generated `synheart.lock` so CI and other authorized developers can restore the same artifacts with:

```bash
synheart sync
```

### 3. Run the app

List available devices:

```bash
flutter devices
```

Run on a connected physical device:

```bash
flutter run -d <device-id>
```

Use release mode for performance and product demonstrations:

```bash
flutter run -d <device-id> --release
```

## Connect a wearable

Wearable setup stays outside the primary music interface:

1. Open the Resona home screen.
2. Tap the current-state pill in the upper-right corner.
3. Open **Settings** from the state sheet.
4. Choose Apple Watch/Health Connect or a Bluetooth heart-rate monitor.
5. Grant only the permissions required for the selected source.

The Settings screen shows the selected source, whether a fresh signal is arriving, and the current BPM when available.

## HSI and adaptation behavior

Resona starts a local Synheart session, ingests consented wearable samples, and listens to typed `HSIState` updates. The experience policy evaluates available focus, stress, arousal, and capacity axes only when their confidence is sufficient.

When a meaningful state change is detected, Resona can:

1. Update the small state character and label.
2. Explain what the experience noticed in neutral language.
3. Recommend a specific track.
4. Allow the listener to accept the recommendation or keep the current music.

Raw biosignals are not presented as medical scores. Cloud upload is disabled in the showcase's local consent configuration.

## Media delivery

The unmodified app streams its demo tracks from the existing Resona media endpoint. The source for the media service is included in [`cloudflare/media-worker`](cloudflare/media-worker).

The Worker:

- serves an explicit allowlist of media objects from R2
- supports `GET`, `HEAD`, CORS, and byte-range requests
- returns cache and content-safety headers
- does not expose bucket listing or upload operations

You do not need to deploy the Worker to run the unmodified showcase. If you host your own licensed media, update the media endpoint and object allowlist, create your own R2 binding, and deploy from the Worker directory.

Never commit Cloudflare credentials or local Wrangler authentication files.

## Project structure

```text
resona/
├── android/                 Android host and permissions
├── assets/
│   ├── music_art/           Local album artwork
│   └── states/              State character artwork
├── cloudflare/media-worker/ Range-aware media service
├── docs/                    Tutorial and recording material
├── ios/
│   ├── ResonaLiveActivity/  Live Activity widget extension
│   └── Runner/              iOS host integration
├── lib/
│   ├── home/                Music library and state sheet
│   ├── platform/            Live Activity bridge
│   ├── player/              Playback and adaptive UI
│   ├── settings/            Wearable-source settings
│   └── state/               Synheart and wearable orchestration
└── test/                    Flutter widget tests
```

## Validation

Before submitting changes:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Native wearable behavior, background audio, HealthKit, Health Connect, and Live Activities must also be verified on physical devices.

## Privacy and responsible design

Resona is designed around the following principles:

- obtain meaningful consent before collecting biosignals
- request permissions only when the user selects a source
- keep connection management in Settings rather than interrupting playback
- minimize raw-data exposure
- distinguish insufficient evidence from a negative result
- explain recommendations in neutral language
- leave the final adaptation decision with the listener
- provide a clear way to disconnect the wearable

Do not use this showcase as the basis for medical diagnosis, treatment, employment decisions, fitness-for-duty decisions, or emergency response.
