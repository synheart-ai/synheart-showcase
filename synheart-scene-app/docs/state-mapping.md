# State mapping — SDK outputs to app labels

RFC §5 asks for "a documented mapping from SDK outputs to app labels". Since
2026-09-28 Scene reads **Synheart Core HSI**, as Resona does
(`synheart-showcase/resona`). The app uses only the axes the runtime
provides, each with its confidence. That answers RFC §6's rule: "use only
fields actually provided".

Code: `lib/domain/state.dart` (axes, policy), `lib/engine/recommender.dart`
(`StateTargets`), `lib/app/state_engine.dart` (publishing), `lib/app/signals.dart`
(runtime and sources).

> **Status: demo policy.** The thresholds come from Resona's showcase policy,
> "demo policy choices, not universal health interpretations". The mapping
> from axes to film targets is Scene's own and is **not validated**. Research
> sign-off on the SDK contract (RFC §6, §13) is still open.

## SDK contract used

| Item | Value |
|---|---|
| Packages | `synheart_core` 0.15.0, `synheart_wear` 0.5.0 |
| Native runtime | `synheart-core-runtime` 0.31.5 and `syni-runtime` 0.4.4, installed with `synheart install runtime`; pinned in `synheart.lock` |
| Output | `Synheart.onStateUpdate` → `HSIState.hsi` axes `focus`, `stress`, `arousal`, `capacity`; each `{value 0–1, confidence 0–1}`. `sleep` and the digital axes are not used |
| Sources | The Scene **Galaxy Watch** (Wear OS) app, relayed over the Wearable Data Layer (`WatchRelay`, provider `wear_os`); Apple Health (iOS) / Health Connect (Android) via `startWearCollection`; standard BLE heart-rate monitors via `BleHrmProvider`; WearSim pairing links (`ai.synheart.wearsim.signal.v1` over WebSocket) |
| Inputs pushed | heart rate, RR intervals, vendor HRV (RMSSD); accelerometer from WearSim. The Galaxy Watch sends **heart rate only** (Health Services' `HEART_RATE_BPM` has no RR), which is Tier 3 in Synheart's research ruling on HR-only wearables: Capacity withheld, other axes capped, confidence ×0.60. On device it gave 0.00–0.17 |
| Consent to the runtime | `biosignals: true`, `behavior: true` (since 2026-09-30); `phoneContext`, `allowCloud`, `allowResearch`, `allowVendorSync`, `syni`: all `false` |
| Behavior config | `BehaviorConfig(enableGestureTracking: true, enableTypingTracking: false, emitRawMotionSamples: true)`; app-switch, notification (Notification access) and call (phone permission) events from `synheart_behavior`'s collectors |
| Task type | Not set. It modulates confidence, and choosing a film is not a focus task |
| Collection window | **Continuous** (product decision, 2026-09-30): from consent until it is withdrawn, in the foreground and — on Android, through a foreground service with an ongoing notification — the background. Every reading with evidence updates the picks; a check-in waits for the next one. Reverses RFC §5's "no passive background collection"; needs a privacy review. Until 2026-09-30: only during a check-in |

> **GAP:** "Cloud upload is off" is guaranteed by the consent form above.
> Whether `Synheart.initialize()` itself contacts a server (for example, for
> capabilities) has **not** been verified. The consent copy therefore does not
> claim "nothing leaves the device".

## Quality rules

- **Confidence (temporary, 2026-09-29):** an axis is *available* when its
  confidence is **above 0**. Before this — and in Resona — the gate was **0.45**;
  it was lowered so a heart-rate-only watch still gives a reading. Revisit it.
- **Low confidence:** an available axis under Resona's **0.45** is used but
  marked *low confidence* — on each plain signal it feeds, on the suggested
  experience, in the state sheet, on Tonight and in *Why this movie?* ("treat
  it lightly"). Zero confidence stays *unavailable*, never a negative result.
- **Not enough evidence:** no axis is available. The state is not used, the
  list is taste only, and the app says so.
- **Check-in result:** the first reading with at least one available axis
  becomes the check-in's result and is published to the picks; collection
  then stops. None within **3 minutes** → *Not enough signal*. Liveness
  (samples within 45 s) is shown during the check-in.
- **Freshness:** a published reading is used for **30 minutes** after it was
  taken. After that, picks are taste only.

All four numbers are tunable defaults.

## Experience policy (Resona's thresholds)

| Condition, on available axes, first match | Experience | Resona's mode | Suggested intent |
|---|---|---|---|
| stress ≥ 0.62, or arousal ≥ 0.76, or capacity ≤ 0.35 | Unwind | ease | Help me unwind |
| focus ≤ 0.44 | Easy watch | clarity | Just entertain me |
| focus ≥ 0.60 | Stay engaged | flow | Give me something engaging |
| otherwise | *No clear need* (a real result) | — | none |

## From axes to film targets

`strain` = the largest of: stress, 1 − capacity, clamp((arousal − 0.5) × 2), over
the axes that are available. A missing axis sets no target.

| Target | Formula | Needs |
|---|---|---|
| Intensity | 0.8 − 0.6 · strain | strain |
| Cognitive load | 0.3 + 0.5 · focus − 0.15 · strain | focus |
| Energy | 0.3 + 0.55 · arousal | arousal |
| Lighter tone preferred | strain ≥ 0.6 | strain |

State fit is the weighted closeness over the targets that exist (intensity
0.40, cognitive load 0.25, energy 0.15, tone 0.20), and 0.5 when none exist.

## What the user sees — the plan's plain signals

The Current State card uses the plan's language (plan §1, §4), not raw HSI
axis names. **Provisional mapping — needs Research approval (RFC §6):**

| Shown as | From | Level |
|---|---|---|
| Energy | arousal | Low < 0.36 ≤ Moderate < 0.66 ≤ High |
| Mental load | the higher of stress and 1 − capacity | same |
| Engagement | focus | same |
| Suggested experience | the policy above | Unwind / Easy watch / Stay engaged / No clear need |

Only axes that pass the confidence gate count; otherwise *Not available*.
The raw readings are under *Details*. The busy-evening demo data reads
exactly as the plan's example card: Moderate / High / Moderate → Unwind.
Heart rate is shown only as a live BPM indicator during a check-in.

## Demo data

Seeded readings, labelled *Demo data — not a real reading* wherever they appear:

| Scenario | Axes (value / confidence) | Expected for the demo persona |
|---|---|---|
| Busy day, tired evening | stress 0.78/0.8, capacity 0.30/0.7, focus 0.50/0.6, arousal 0.50/0.7 | Unwind; a meaningful change |
| Rested and focused | focus 0.78/0.8, stress 0.20/0.75, capacity 0.80/0.7, arousal 0.50/0.7 | Stay engaged; no meaningful change, reported as such |
| Signal too weak | focus 0.30/0.0, stress 0.90/0.0 | Not enough evidence; taste only (zero confidence, because the gate is "above 0") |

WearSim presentation cues (`ease`, `clarity`, `flow`, `signal_settling`) map
to the matching experience with a seeded WearSim reading. While a
presentation runs, live readings are paused.
