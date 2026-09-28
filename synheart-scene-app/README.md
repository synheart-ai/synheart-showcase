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

Each film carries genre, intensity, cognitive load, energy, emotional tone,
runtime and familiarity.

## Synheart integration

The check-in uses `synheart_behavior`'s `BehaviorTextField`. The SDK records
**how** the user types (speed, cadence, gaps, corrections) — never **what**
they type. Scene maps those timing signals to simple, non-clinical state
descriptions, and the user can always adjust the result before seeing picks.

## Run

```bash
flutter pub get
flutter run
```

Flutter 3.44.8 (Dart 3.12). iOS and Android.

## Build log

Built step by step — one commit per step — see `git log`.
