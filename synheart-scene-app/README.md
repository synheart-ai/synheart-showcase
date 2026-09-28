# Scene by Synheart

> Taste tells us what you like. Your state helps us understand what might fit right now.

A mobile cinema-recommendation **demo** that shows how Synheart adds
present-context intelligence to a conventional recommender. Scene first learns
a user's movie taste, then combines that baseline with their current state to
answer one question: **"What should I watch right now?"**

Source plan: *Scene by Synheart — Cinema Recommendation Demo App Plan*
(Internal Product Concept, September 2026).

## Demo principle

Synheart never guesses taste. The baseline establishes preference first; the
current state only changes **which of the films you'd like fit this moment**.

> Your preferences haven't changed. Your context has.

## The eight MVP screens

| # | Screen | Purpose |
|---|---|---|
| 1 | Welcome | Find the right movie for right now |
| 2 | Build Movie Profile | Rate a curated set of films, pick genres, set Familiar ↔ Surprise me |
| 3 | Movie DNA | The baseline taste profile |
| 4 | Synheart Check-In | A short typing prompt captured with `synheart_behavior` |
| 5 | Current State | Signals in non-clinical language (energy, mental load, engagement) |
| 6 | Tonight's Picks | Taste + current state recommendations |
| 7 | Why This Movie? | How baseline and state shaped a pick |
| 8 | Taste vs. Taste + State | The toggle that makes Synheart's contribution visible |

## Recommendation logic (transparent, demo-grade)

| Input | Weight | Source |
|---|---|---|
| Taste match | 50% | Baseline |
| State fit | 35% | Synheart |
| Context fit | 15% | Time / intent / setting |

These are tunable defaults, not a validated formula (RFC §7). When the user
picks an intent, it takes precedence over the check-in: taste 50 / context 35 /
state 15. *Based on taste* with an intent is taste 70 / context 30, and no
check-in is used. Fit is shown in words (*Strong fit for tonight*), never as a
percentage.

Each film carries genre, intensity, cognitive load, energy, emotional tone,
runtime and familiarity.

## Synheart integration

The check-in uses `synheart_behavior`'s `BehaviorTextField`. The SDK records
**how** the user types (speed, cadence, gaps, corrections) — never **what**
they type.

- **Consent first.** Nothing is collected before the user agrees. The SDK is
  started on *I agree* and disposed when the check-in closes. There is no
  app-wide gesture detector and no background collection.
- **Skip** is always available and leads to taste-only picks.
- **On device.** The 0.4.1 source has no HTTP client, and Scene sends nothing.
- The labels (energy, mental load, engagement) are **provisional**. The
  mapping is documented in [`docs/state-mapping.md`](docs/state-mapping.md).
- A snapshot is used for 2 hours, then the app falls back to taste only.

## Supporting features

- **Choose My Evening** — explicit intent (entertain me / keep me engaged /
  help me unwind) and a *90 minutes or less* filter. The user's choice always
  counts alongside Synheart.
- **State-aware collections** — *Because you want to switch off*, *Keep me
  engaged*, *Something familiar*, *Surprise me*, *90 minutes or less*.
- **Feedback loop** — Perfect / Pretty good / Not really / Wrong for me, with
  optional reasons. *Wrong for me*, *Already seen* and *Not interested* hide
  the film from later picks.

## Demo script (about 3 minutes)

1. **Welcome** → *Try the demo profile* (a thriller / sci-fi / crime fan).
2. **Movie DNA** — this is taste only; Synheart has not been used yet. *Edit*
   changes it without starting over.
3. **Check-in** — read the consent card aloud, then either type a sentence or
   two, or pick a **demo data** scenario (labelled as such everywhere):
   - *Busy day, tired evening* — the ranking changes meaningfully.
   - *Rested and focused* — the list barely moves, and Scene says so.
   - *Skip* — taste only, the unavailable-state case.
4. **Current context** — provisional labels, the check-in time, and a
   suggested evening the user can accept, change or skip.
5. **Tonight's Picks** starts on *Based on taste*: Se7en, Ex Machina,
   Prisoners, Shutter Island, Gone Girl.
6. Switch to **Taste + current state** (busy evening). The list becomes Glass
   Onion, Ocean's Eleven, Knives Out, The Nice Guys, The Grand Budapest Hotel.
   Say the line: *"Your preferences haven't changed. Your context has."*
7. Open a pick → **Why this movie?** — *Your taste*, *Right now*, *How that
   affected this pick*, with its taste-only rank.
8. **What changed?** — each film's movement (↑ from #11, new), what dropped
   out, then the closing message.

**Reset demo** (Welcome or Movie DNA) clears everything for the next run.

## Privacy and data

| Kept on the device | Never kept |
|---|---|
| Ratings, genres, discovery (direct inputs) | Typed text (cleared on continue) |
| The derived snapshot: three levels, source, time | Raw typing events |

Both are cleared by **Reset demo**. A local event log (in memory, printed
with `[scene-event]` in debug builds) records demo events with enum names
and film ids only.

## Offline

Everything works without a network: catalogue, baseline, check-in and
rankings. There are no trailers or artwork downloads.

## RFC

[`docs/rfc.md`](docs/rfc.md) is the RFC from Notion. [`docs/rfc-gaps.md`](docs/rfc-gaps.md)
lists what the first build missed and where each gap was closed.

## Tests

```bash
flutter analyze
flutter test
```

The tests pin the demo story and the RFC's rules. They cover all three
seeded scenarios, consent and skip, and stale state, as well as intent
precedence, the event log, the accessibility guidelines and 160% text. The
typing check-in is widget-tested through the SDK's own `BehaviorTextField`;
the native SDK session is not, so a device run is still worth doing.

## Run

```bash
flutter pub get
flutter run
```

Flutter 3.44.8 (Dart 3.12). iOS and Android.

## Build log

Built step by step — one commit per step — see `git log`.
