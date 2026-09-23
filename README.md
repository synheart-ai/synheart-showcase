# Synheart Showcase

Synheart Showcase is a collection of applications that demonstrate what can be built with the **Synheart Human State Interface (HSI)** infrastructure.

> We taught our systems to know where you are.
> We taught AI to predict what you want next.
> Neither of them ever learned to understand the state you're actually in.
>
> **Let's fix that.**

Each project explores a practical way for software to respond to consented, privacy-aware human-state context while keeping the user in control of the experience. These are real, runnable applications rather than slideware — they are the reference for what the HSI stack makes possible.

## Demo

[![Watch the Resona demo](https://img.youtube.com/vi/xRhoxP4koxo/maxresdefault.jpg)](https://youtu.be/xRhoxP4koxo)

*Resona — adaptive music built on Synheart HSI. Click to watch on YouTube.*

## What is the Human State Interface?

HSI is an open specification for representing and exchanging inferred human-state signals — focus, stress, arousal, capacity — between independent systems. It defines *what* is exchanged, not *how* it is produced: canonical payload structure, field semantics, time-window rules, and explicit confidence, so that an application can tell the difference between *"the evidence says no"* and *"there isn't enough evidence."*

Around that specification, Synheart provides SDKs that collect consented signals, compute state on-device, and hand applications typed, confidence-aware updates:

| Layer | What it provides | SDKs |
| --- | --- | --- |
| **Specification** | Schema, RFCs, and test vectors for human-state signals | [`hsi`](https://github.com/synheart-ai/hsi) |
| **Core** | Biosignals, behavior, and on-device state computation | [Flutter](https://github.com/synheart-ai/synheart-core-flutter) · [Swift](https://github.com/synheart-ai/synheart-core-swift) · [Kotlin](https://github.com/synheart-ai/synheart-core-kotlin) · [Wear OS](https://github.com/synheart-ai/synheart-core-kotlin-edge) |
| **Wearables** | HealthKit, Health Connect, WHOOP, Garmin, Oura, Fitbit | [Flutter](https://github.com/synheart-ai/synheart-wear-flutter) |
| **Behavior** | Typing, motion, gestures, attention — privacy-preserving | [Flutter](https://github.com/synheart-ai/synheart-behavior-flutter) · [Kotlin](https://github.com/synheart-ai/synheart-behavior-kotlin) |
| **Sessions** | Biosignal session lifecycle with pluggable providers | [Kotlin](https://github.com/synheart-ai/synheart-session-kotlin) |
| **Auth** | Secure Enclave / Keystore-backed ECDSA P-256 request signing | [Flutter](https://github.com/synheart-ai/synheart-auth-flutter) · [Kotlin](https://github.com/synheart-ai/synheart-auth-kotlin) |
| **Syni** | Persona-driven, on-device adaptive agent running on HSI | [Concepts](https://github.com/synheart-ai/syni) · [Flutter](https://github.com/synheart-ai/syni-flutter) · [Kotlin](https://github.com/synheart-ai/syni-kotlin) |

## Showcases

### [Resona](resona) — *Music that understands the moment*

[![Watch the Resona demo](https://img.shields.io/badge/▶-Watch%20the%20demo-red)](https://youtu.be/xRhoxP4koxo)

Resona is an adaptive music experience built with Flutter and Synheart. It receives supported wearable signals, computes HSI locally, and uses trustworthy state updates to offer subtle soundtrack recommendations.

Resona demonstrates:

- Apple Health and Health Connect wearable sources
- Direct Bluetooth heart-rate monitor support
- On-device HSI computation with confidence-aware experience rules
- User-controlled adaptive music recommendations
- Background audio and iOS Live Activities
- A privacy-first interface that avoids exposing raw physiological data

See the [Resona guide](resona/README.md) for architecture, setup, wearable support, and development instructions.

*More showcases are on the way. If you build something on HSI, we would like to see it.*

## Repository structure

```text
synheart-showcase/
└── resona/    Flutter adaptive-music showcase
```

Each showcase is self-contained and has its own dependencies and setup guide. Proprietary Synheart Runtime binaries are not stored in this repository; authorized developers install the required artifacts with the Synheart CLI.

## Build your own

The shortest path from zero to an HSI-aware application:

1. **Read the spec.** Start with [`hsi`](https://github.com/synheart-ai/hsi) to understand states, axes, confidence, and time-window semantics.
2. **Pick a Core SDK** for your platform from the table above, and add a signal source (wearable or behavior).
3. **Install the runtime.** State computation happens in the native Synheart Runtime, provisioned with the Synheart CLI:
   ```bash
   curl -fsSL https://synheart.sh/install | sh
   synheart login
   synheart install runtime
   ```
   The runtime artifacts are proprietary and currently require an authorized account — `synheart login` will not succeed without one. The SDKs, the HSI specification, and this showcase's source are open; the native runtime binaries are not.
4. **Listen for state updates.** The SDK hands you a stream of real `HSIState` objects — not JSON you have to parse. Every axis carries a value *and* a confidence:

   ```dart
   Synheart.onStateUpdate.listen((HSIState state) {
     final focus = state.hsi.focus;        // value + confidence, or null
     if (focus == null || focus.confidence < 0.45) return;  // not enough evidence
     if (focus.value <= 0.44) suggestSomethingCalmer();
   });
   ```

5. **Handle "I don't know" as a real answer.** Low confidence, stale data, and a disconnected wearable are not zero — they mean the app has nothing to say yet, and should say nothing. This is the branch most integrations forget.
6. **Decide who acts on the result.** Resona explains what it noticed, recommends a track, and lets the listener accept or ignore it — a deliberate choice for a music app running on inferred signals. Your product may warrant acting automatically. Just make it a decision you made on purpose.

Read [Resona's source](resona/lib) for a working example of every step, particularly [`lib/state/`](resona/lib/state) for the Synheart orchestration and confidence gating.

## Responsible use

Synheart showcases are examples of adaptive software design. They should be built around meaningful consent, data minimization, transparent recommendations, and user choice.

**These showcases are wellness and developer demonstrations, not medical software. They do not diagnose, treat, cure, or prevent any disease or medical condition and must not be used for clinical or safety-critical decisions.**

## Contributing

We keep this repository small on purpose, so we rarely merge outside pull requests into it.

But we would genuinely love to see what you have built. If you have made something on HSI — a weekend experiment, a research prototype, a product, a beautifully cursed hack — **open an issue and show us.** We read all of them. Projects we love may end up featured here, and we will always credit you.

If you are working on a showcase with us, keep it focused, reproducible, and understandable on its own. It should arrive as its own top-level directory with a self-contained README covering what it demonstrates, how to set it up, and the privacy decisions it makes. Never commit credentials, provisioning profiles, user data, generated build output, or proprietary runtime artifacts.

## License

Apache License 2.0. See [LICENSE](LICENSE).
