# Scene by Synheart

> Taste tells us what you like. Your state helps us understand what might fit right now.

A mobile cinema-recommendation **demo** built on the Synheart Human State
Interface (HSI). If [Resona](../synheart-showcase/resona) is a state-aware
Spotify, Scene is a state-aware Netflix. It first learns a person's movie
taste, then combines that baseline with their current state to answer one
question: **"What should I watch right now?"**

Sources: *Scene by Synheart — Cinema Recommendation Demo App Plan* (PDF,
September 2026) and the Scene RFC ([`docs/rfc.md`](docs/rfc.md)).

## Demo principle

Synheart never guesses taste. The baseline establishes preference first; the
current state only changes **which of the films you'd like fit this moment**.

> Your preferences haven't changed. Your context has.

## How it works

```text
Apple Health / Health Connect / BLE heart-rate monitor / WearSim
                         │
                         ▼
          synheart_core → native Synheart runtime
             on-device HSI: focus · stress · arousal · capacity
                         │   (each with a confidence)
                         ▼
     confidence gate (≥ 0.45) → experience policy (Resona's thresholds)
                         │
                         ▼
      taste 50 · state 35 · context 15  →  explain  →  user decides
```

Missing, stale or low-confidence evidence is **unavailable**, never a negative
judgement. Scene then ranks on taste only and says so. The full mapping is in
[`docs/state-mapping.md`](docs/state-mapping.md).

## Screens

| Screen | Purpose |
|---|---|
| Welcome | Find the right movie for right now |
| Build movie profile | Rate a curated set (Love / Like / Not for me / Haven't seen), pick genres, Familiar ↔ Surprise me; every step can be skipped |
| Movie DNA | The baseline, in words; edit it or reset the demo |
| **Home (Tonight)** | The Taste only ⇄ Taste + current state toggle, a hero for the #1 pick, tonight's top five, Choose My Evening, then browse rows |
| State pill and sheet | As in Resona: the current state in neutral words, reading age, live BPM, suggested evening |
| Settings | Consent, then a source: Apple Health / Health Connect, Bluetooth HRM, WearSim; demo data |
| Why this movie? | *Your taste* / *Right now* / *How that affected this pick*, from the ranking's own numbers |
| What changed? | Both rankings, each film's movement, and an honest "no meaningful change" |

## Recommendation logic (transparent, demo-grade)

| Input | Weight | Source |
|---|---|---|
| Taste match | 50% | Baseline |
| State fit | 35% | Synheart HSI |
| Context fit | 15% | Chosen intent, runtime limit |

These are tunable defaults, not a validated formula (RFC §7). When the user
picks an intent, it takes precedence over the state: taste 50 / context 35 /
state 15. *Based on taste* with an intent is 70 / 30. Fit is shown in words
(*Strong fit for tonight*), never as a percentage.

## Setup

Scene needs the proprietary Synheart native runtime, installed with the
Synheart CLI in the same way as Resona.

```bash
flutter pub get

# Once per machine
curl -fsSL https://synheart.sh/install | sh
synheart login

# In this directory: installs synheart/vendor/ (gitignored)
synheart install runtime     # first time
synheart sync                # afterwards, from the committed synheart.lock
```

For iOS, set your development team in Xcode under **Signing & Capabilities**
(the project carries none). The app uses the HealthKit capability.

```bash
flutter devices
flutter run -d <device-id>            # a physical device for wearable input
flutter run -d <device-id> --release  # for demos
```

Requirements: Flutter 3.44.8 (Dart 3.12), iOS 16.2+, Android API 28+.

## Connect a source

1. On the home screen, tap the state pill, then **Settings**.
2. Read the consent card and tap **I agree**. Nothing is collected before this.
3. Choose **Apple Health / Health Connect**, a **Bluetooth heart-rate monitor**
   (scan, then tap it), or a **WearSim** link. A `wearsim://pair?endpoint=ws://…`
   link opens Scene directly, or you can paste it.
4. Each source asks only for its own permissions. **Disconnect** or **Withdraw
   consent** at any time.

## Demo script (about 3 minutes)

1. **Welcome** → *Try the demo profile* (a thriller / sci-fi / crime fan).
2. **Movie DNA** — this is taste only; Synheart has not been used yet.
3. **Home** on *Based on taste*: Se7en leads, then Ex Machina, Prisoners,
   Shutter Island and Gone Girl. Below them are "Because you like …" rows.
4. Tap the **state pill** → Settings → a live source, or **demo data**:
   - *Busy day, tired evening* — the ranking changes meaningfully.
   - *Rested and focused* — the list barely moves, and Scene says so.
   - *Signal too weak* — not enough evidence, so taste only.
5. Switch to **Taste + current state** (busy evening). The top five becomes
   Glass Onion, Ocean's Eleven, The Nice Guys, Knives Out and Hot Fuzz. The
   fifth slot is a near-tie with Catch Me If You Can. Say the line:
   *"Your preferences haven't changed. Your context has."*
6. Open a pick → **Why this movie?**, with its taste-only rank.
7. **What changed?** — each film's movement (↑ from #11, new), what dropped
   out, then the closing message.

**Reset demo** (Welcome or Movie DNA) clears everything for the next run.

## Supporting features

- **Choose My Evening** — explicit intent and a *90 minutes or less* filter.
- **Browse rows** — with a reading: *Because you want to switch off*, *Keep me
  engaged*, *Something familiar*, *Surprise me*, *90 minutes or less*. Without
  one: *Because you like <genre>*.
- **Feedback** — Perfect / Pretty good / Not really / Wrong for me, with
  optional reasons. *Wrong for me*, *Already seen* and *Not interested* hide
  the film from later picks.

## Privacy and data

| Kept on the device | Never kept |
|---|---|
| Ratings, genres, discovery (direct inputs) | Raw heart-rate or HRV samples |
| The latest published reading: four axes with confidence, source, time | — |

Both are cleared by **Reset demo**. The runtime is given local-only consent:
biosignals only, and cloud, research and vendor sync off. A local event log
(in memory, printed with `[scene-event]` in debug builds) records demo events
with enum names and film ids only.

## Tests

```bash
flutter analyze
flutter test
```

The HSI path is tested through a fake `SignalBackend`. The tests cover the
confidence gate, the two-window publishing rule, liveness, WearSim link
validation and cues, and consent before any source. They also cover the demo
story, all three seeded scenarios, the accessibility guidelines and 160% text.
Wearables, HealthKit, Health Connect and the native runtime need a physical
device.

## Build log

Built step by step — one commit per step — see `git log`.
