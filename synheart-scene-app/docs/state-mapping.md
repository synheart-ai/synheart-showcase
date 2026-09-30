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
| Native runtime | `synheart-core-runtime-lab` **0.32.0** (lab channel, since 2026-09-30; was stable 0.31.5), installed with `synheart install runtime`; pinned in `synheart.lock`. `synheart_core` 0.15.0 was written against 0.31.1 and loads anything ≥ 0.20.0. Move to the stable channel when 0.32.0 is published there. `syni-runtime` is no longer in the lock ("not published"); Scene sets `syni: false` |
| Output | `Synheart.onStateUpdate` → every axis in the HSI 1.3 snapshot (`HSIState.rawJson`, `axes.<domain>[]` by name; typed `HSIState.hsi` fields as fallback), each `{score 0–1, confidence 0–1}`: **core** focus, stress, arousal, capacity; **behavior** cognitive_load, mental_fatigue, valence, sleep_score, focus_quality, interruption_pressure, interaction_mode. A null score is "could not compute", never zero. Also read: `state_withheld` and the digital `diagnostics.notes` (reasons), `modalities` (basis), `meta.synheart.context` (activity guess, Details only, not stored). The embedding is ignored (`privacy.embedding_allowed: false`). Each snapshot is logged as one `[scene-hsi]` line in debug builds |
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

## Experience policy (Resona's thresholds, plus the behavior axes)

| Condition, on available axes, first match | Experience | Resona's mode | Suggested intent |
|---|---|---|---|
| stress ≥ 0.62, or arousal ≥ 0.76, or capacity ≤ 0.35, or **cognitive load ≥ 0.70** | Unwind | ease | Help me unwind |
| engagement ≤ 0.44, or **tiredness ≥ 0.70**, or **interruptions ≥ 0.70** | Easy watch | clarity | Just entertain me |
| engagement ≥ 0.60 | Stay engaged | flow | Give me something engaging |
| otherwise | *No clear need* (a real result) | — | none |

Engagement is focus alone when focus quality is missing, so the core-only
behavior is unchanged. The behavior thresholds (0.70) are demo choices
(2026-09-30), stricter than the core ones because these axes are newer to
Scene.

## From axes to film targets

`strain` = the largest of: stress, 1 − capacity, clamp((arousal − 0.5) × 2),
**0.8 × cognitive load** and **0.8 × tiredness**, over the axes that are
available. A missing axis sets no target. `secondaryWeight` = 0.8 is how much
the behavior axes count against the core four (demo choice).

| Target | Formula | Needs |
|---|---|---|
| Intensity | 0.8 − 0.6 · strain | strain |
| Cognitive load | 0.3 + 0.5 · engagement − 0.15 · strain − 0.12 · tiredness − 0.08 · interruptions | engagement |
| Energy | 0.3 + 0.55 · arousal | arousal |
| Lighter tone preferred | strain ≥ 0.6, or mood (valence) ≤ 0.35 | strain or valence |

**Directions.** Every mapping reads an axis's *amount* by the direction the
snapshot itself states (`direction`), never the raw score: higher-is-more →
the score, lower-is-more → 1 − score, bidirectional → not used (except
valence, negative → positive by definition). Seen on device with runtime
0.32.0 (2026-09-30): **`cognitive_load` and `interruption_pressure` are
lower-is-more**; `interaction_mode` and `valence` bidirectional; focus,
capacity, stress, arousal, mental_fatigue and focus_quality higher-is-more.

> **HYPOTHESIS:** a lower-is-more axis at exactly 0.00 with low confidence
> is the runtime's floor while evidence is thin, not a maximum —
> interruption_pressure 0.00@0.25 and cognitive_load 0.00@0.08 appeared in
> the first windows after a start or a heart-rate gap, while focus quality
> read 0.79@1.00. Scene treats it as unavailable ("too early to tell").
> Confirm with the runtime team.

**The state's share scales with confidence** (`stateTrust`, 2026-09-30).
trust = mean confidence of the driving axes ÷ 0.45, clamped to 0–1; the
state's weight is 35 % × trust (15 % × trust with an intent), and what it
gives up goes to taste. The user's choice keeps its share. Demo data and
WearSim keep trust 1, so the pinned demo lists are unchanged. *Why this
movie?* says "less than usual, because Synheart is not sure about this
reading". On device the full 35 % turned a 0.011 taste gap (Blade Runner
2049 .896, John Wick .887, Baby Driver .885) into the same #1 every minute
from readings at 0.04–0.36 confidence. With trust ≈ 0.77 (focus quality at
0.94 lifts the mean) Baby Driver still leads, by 0.004–0.012 — the taste
top three are that close, so any reading reorders them.

**Not driving while their direction is disputed:** `cognitive_load`,
`interruption_pressure` (and `interaction_mode`, undocumented ends) —
`HsiAxis.drivesPicks`. Shown on the card (Mental load, Interruptions),
never in the suggestion or the ranking. Revisit when the runtime team
confirms the direction.

**Behavior axes drive only at confidence ≥ 0.45** (`CurrentState.drivers`).
Below that they are shown on the card with the low-confidence tag but move
neither the suggestion nor the ranking; the core four keep the temporary
"> 0" gate. Reason (device, 2026-09-30): cognitive_load read 0.06@0.09 —
"94 % load" by its lower-is-more label — and would have suggested Unwind.

> **CONTRADICTION (cognitive_load direction):** the snapshot labels it
> `lower_is_more`, but across six windows of calm browsing it read 0.00–0.29,
> which fits higher-is-more better. Scene follows the label (evidence
> order: the runtime's own statement over my reading of values) and, at
> ~0.09 confidence, never lets it drive. Ask the runtime team.

**Interaction mode is never ranked on.** Its HSI direction is
`bidirectional` and neither the SDK nor the runtime docs say which end is
passive consumption and which is active input; guessing could invert it. It
is shown under Details with that note.

State fit is the weighted closeness over the targets that exist (intensity
0.40, cognitive load 0.25, energy 0.15, tone 0.20), and 0.5 when none exist.

## What the user sees — the plan's plain signals

The Current State card uses the plan's language (plan §1, §4), not raw HSI
axis names. **Provisional mapping — needs Research approval (RFC §6):**

| Shown as | From | Level |
|---|---|---|
| Energy | arousal | Low < 0.36 ≤ Moderate < 0.66 ≤ High |
| Mental load | the highest of stress, 1 − capacity and cognitive load | same |
| Engagement | the mean of focus and focus quality | same |
| Tiredness | the higher of mental fatigue and 1 − sleep | same |
| Interruptions | 1 − interruption pressure (the score is lower-is-more) | same |
| Mood | valence | Lower / Steady / Brighter — never "Low", which reads like a diagnosis |
| Suggested experience | the policy above | Unwind / Easy watch / Stay engaged / No clear need |

Only axes that pass the confidence gate count; otherwise *Not available*,
with the runtime's reason in plain words when it gave one (`no_signal` → "no
heart-rate signal", `no_contributing_modality` → "no input for it yet",
`cold_start…` → "still learning your baseline", `LOW_DIRECTIONAL_EVIDENCE` →
"not enough evidence yet"; unknown codes are shown as they are). Details
lists every axis's score and confidence, what the reading was built from,
and the activity guess (marked "not used for picks"). *Why this movie?*
names the three core signals when missing; the behavior signals only when
present.
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
