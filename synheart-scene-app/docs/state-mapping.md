# State mapping — SDK outputs to app labels

RFC §5 asks for "a documented mapping from SDK outputs to app labels". This is
that mapping as implemented in `lib/engine/state_from_typing.dart`.

> **Status: provisional.** The RFC (§6) says labels such as *energy*,
> *engagement* and *mental load* stay provisional until Research validates
> the mapping. The app marks them provisional on the Current context screen.
> **Nothing below has been validated.** It is a transparent demo heuristic,
> not a Synheart model.

## SDK contract used

| Item | Value |
|---|---|
| Package | `synheart_behavior` 0.4.1 (pub.dev) |
| Interaction | `BehaviorTextField` with `onTypingEvent`. One event per typing burst, emitted when the field loses focus |
| Platforms | iOS (15.0+) and Android |
| Permissions | None for typing. The package's Android manifest adds notification-listener and phone-state entries; Scene removes them |
| Where computed | The typing metrics are computed in Dart inside `BehaviorTextField`. The native SDK is started after consent for the session, but the metrics do not depend on it |
| Network | None. The 0.4.1 source has no HTTP client; Android only reads connectivity status |
| Latency | About 0.4 s after "Read my current context" (unfocus → event) |
| Collection window | Only while the check-in screen is open after consent; the SDK is disposed on leaving |

## Inputs (from `BehaviorEvent.metrics`)

| Key | Meaning | Range |
|---|---|---|
| `typing_tap_count` | keystrokes in the burst | ≥ 1 |
| `typing_speed` | keystrokes per second | ≥ 0 |
| `typing_gap_ratio` | share of intervals that were long pauses | 0–1 |
| `typing_cadence_stability` | evenness of rhythm | 0–1 |
| `typing_activity_ratio` | share of the burst spent typing | 0–1 |
| `typing_interaction_intensity` | the SDK's typing intensity | 0–1 |
| `backspace_count` + `number_of_delete` | corrections | ≥ 0 |

Missing or unknown values are read as 0.

## Quality rule

- **Insufficient signal:** fewer than **25 keystrokes** across all bursts.
  No state is produced, and the app shows a neutral message.
- **Freshness:** a snapshot is used for **2 hours**. After that the app falls
  back to taste only and offers a new check-in.
- Both thresholds are tunable defaults. RFC §13 leaves the real rules open.

## Mapping

Bursts are averaged, weighted by keystrokes. `correction = min(1, backspaces / taps / 0.25)`.

| Label | Formula (clamped 0–1) | Plain reading |
|---|---|---|
| Energy | `0.15 + 0.55 · clamp((speed − 1.5) / 4) + 0.30 · intensity` | faster, more intense typing → higher |
| Mental load | `0.15 + 0.35 · correction + 0.30 · gaps + 0.20 · (1 − stability)` | more corrections, pauses, uneven rhythm → higher |
| Engagement | `0.15 + 0.45 · activity + 0.40 · stability` | more time typing, steadier rhythm → higher |

Levels shown: **Low** < 0.36 ≤ **Moderate** < 0.66 ≤ **High**.

## From labels to a suggested evening

| Condition (first match) | Suggested experience | Suggested intent |
|---|---|---|
| mental load ≥ 0.66 | Unwind | Help me unwind |
| energy < 0.36 | Easy watch | Just entertain me |
| engagement ≥ 0.66 | Stay engaged | Give me something engaging |
| energy ≥ 0.66 | Lift me up | Just entertain me |
| otherwise | Easy watch | Just entertain me |

The user can accept, change or skip the suggested intent. An explicit intent
takes precedence over the check-in: the weights become taste 50 / context 35 /
state 15 instead of 50 / 15 / 35.

## Demo data

Two seeded snapshots (`lib/data/demo_scenarios.dart`), always labelled *Demo
data — not a real check-in*:

| Scenario | Energy / load / engagement | Expected result for the demo persona |
|---|---|---|
| Busy day, tired evening | 0.5 / 0.8 / 0.5 | Meaningful change (the plan's example) |
| Rested and focused | 0.75 / 0.2 / 0.75 | No meaningful change — reported as such |

The third RFC scenario, *unavailable state*, is **Skip** (or a stale snapshot).
