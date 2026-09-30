# Scene by Synheart

> Taste tells us what you like. Your state helps us understand what might fit right now.

A mobile cinema-recommendation **demo** built on the Synheart Human State
Interface (HSI). If [Resona](../resona) is a state-aware
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
Galaxy Watch (HR only) / Apple Health / Health Connect / BLE strap (HR + RR) / WearSim
                         │
                         ▼
          synheart_core → native Synheart runtime
             on-device HSI: focus · stress · arousal · capacity
                         │   (each with a confidence)
                         ▼
     confidence gate (> 0, temporary; Resona's is ≥ 0.45; below 0.45 is marked "low confidence")
                         │   → experience policy (Resona's thresholds)
                         │
                         ▼
      taste 50 · state 35 · context 15  →  explain  →  user decides
```

Missing or stale evidence, or an axis with zero confidence, is **unavailable**,
never a negative judgement; Scene then ranks on taste only and says so.
**Temporary (2026-09-29):** any confidence above 0 counts, so a heart-rate-only
watch still gives a reading. Everything built from a reading under Resona's 0.45
is marked *low confidence* on the state card, the state sheet, Tonight and Why.
The full mapping is in [`docs/state-mapping.md`](docs/state-mapping.md).

## Screens

| Screen | Purpose |
|---|---|
| Welcome | Find the right movie for right now |
| Build movie profile | Rate a curated set (Love / Like / Not for me / Haven't seen), pick genres, Familiar ↔ Surprise me; every step can be skipped |
| Movie DNA | The baseline (genre percentages and qualities); edit it or reset the demo |
| **Synheart check-in** | Consent, then "Sit back for a minute" while Synheart reads the chosen wearable; ends at the first confident reading. **The only time Scene collects** |
| Current State | The plan's card: Energy, Mental load, Engagement, Suggested experience; the suggested evening to accept, change or skip |
| **Home (Tonight)** | The Taste only ⇄ Taste + current state toggle, a hero for the #1 pick, tonight's top five, Choose My Evening, then browse rows |
| State pill and sheet | The latest check-in in plain words, its age, and Check in again |
| Settings (⚙ on Welcome, Movie DNA, Tonight, the check-in and Current State) | Consent; choose and test a source (Galaxy Watch, Bluetooth strap, Apple Health / Health Connect, WearSim) — paused on leaving; demo data |
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

## Film data (TMDB)

Posters, synopses, runtimes and trailers come from [TMDB](https://www.themoviedb.org).
Scene's **own tags** — intensity, cognitive load, energy, tone, familiarity —
still drive every recommendation; no movie API provides them (RFC §6).

1. Create a TMDB account and an API key (Settings → API). Either the v4 *API
   Read Access Token* or the v3 *API Key* works.
2. Put it in `tmdb.json` at the project root. The file is gitignored:
   ```json
   {"TMDB_TOKEN": "<your token>"}
   ```
3. Run with `flutter run --dart-define-from-file=tmdb.json`.
4. Optional but recommended: pin the matches so they are reviewable.
   `dart run tool/resolve_tmdb.dart` writes `lib/data/tmdb_ids.dart` and lists
   any misses, plus runtimes that differ from the catalogue.

Film data is cached on the device after the first fetch, so a demo works
offline. Without a token, or for a film TMDB has no confident match for,
Scene shows its typographic poster. Settings → *Film data* shows the match
count.

> TMDB's terms require attribution: the app shows TMDB's logo (their official
> "Primary short (blue)" SVG from themoviedb.org/about/logos-attribution,
> rendered to `assets/tmdb_logo.png`) with the attribution line in Settings and
> on *Why this movie?*. TMDB is free for non-commercial use; confirm the licence
> before sharing the demo externally (RFC §12).

## The check-in and its source

1. From Movie DNA tap **Start my Synheart check-in** (or *Do a Synheart
   check-in* on the home screen).
2. Read the consent card and tap **I agree**. Nothing is collected before this.
3. **Choose a source** (once): the **Galaxy Watch** app, a **Bluetooth
   heart-rate strap** (scan, then tap it), **Apple Health / Health Connect**, or
   a **WearSim** link (`wearsim://pair?endpoint=ws://…` opens Scene directly, or
   paste it). Settings shows the live BPM so you can test it; leaving Settings
   stops it.
4. Tap **Start check-in** and sit back. It usually takes one to two minutes
   (HSI windows are about 60 s), ends at the first reading above the gate, and
   **stops collecting**. After 3 minutes without one it says *Not enough
   signal* — try again, use taste only, or change the source.

The strap sends RR intervals as well as heart rate, so it usually gives the
fuller reading; the watch sends heart rate only. On 2026-09-29 the Galaxy Watch6
(with a Samsung SM-A235F) gave confidences of 0.00–0.17, the level Synheart's
research ruling on HR-only wearables allows. A failed check-in's *Details* and
the `[scene-signal]` debug log say why a reading did not pass.

## Demo script (about 3 minutes)

1. **Welcome** → *Try the demo profile* (a thriller / sci-fi / crime fan).
2. **Movie DNA** — this is taste only; Synheart has not been used yet.
3. **Start my Synheart check-in** — *"But what I normally like is not
   necessarily what fits every evening."* Run it live, or use **demo data**:
   - *Busy day, tired evening* — the ranking changes meaningfully.
   - *Rested and focused* — the list barely moves, and Scene says so.
   - *Signal too weak* — not enough evidence, so taste only.
4. **Current State** — the plan's card. The busy evening reads Energy
   *Moderate*, Mental load *High*, Engagement *Moderate* → *Unwind*.
   See tonight's picks: the home starts on *Based on taste* — Se7en, Ex
   Machina, Prisoners, Shutter Island, Gone Girl.
5. Switch to **Taste + current state** (busy evening). The top five becomes
   Glass Onion, Ocean's Eleven, The Nice Guys, Knives Out and Hot Fuzz. Say
   the line: *"Your preferences haven't changed. Your context has."* (Tonight
   shows it only when the change is meaningful.)
6. Open a pick → **Why this movie?**, with its taste-only rank, the reading's
   age, *Check in again*, and the plan's closing message.

Both lists are pinned by a test (`test/engine_test.dart`). Several places are
near-ties (Glass Onion / Ocean's Eleven by about 0.0002; places 5–8 within
0.01), so a tag change that reorders them fails the test on purpose.

**Differences from the plan's example lists (kept on purpose).** The plan's
taste-only list has Knives Out fifth and no Ex Machina; its taste + state list
is Knives Out, The Nice Guys, Catch Me If You Can, The Grand Budapest Hotel and
Ocean's Eleven, with Knives Out in both lists. Scene's catalogue tags rank Ex
Machina into the taste-only five and Glass Onion first under the busy evening,
and the two lists share no film. The story is the same: dark thrillers first,
then lighter films from the same taste.
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
| Film data cache: TMDB posters, synopses, runtimes, trailer ids | — |

**Network use.** Film data comes from TMDB (`api.themoviedb.org`, posters from
`image.tmdb.org`) on first fetch, then from the cache, so catalogue and baseline
flows work offline. Trailers open YouTube and need a connection. No health data
is sent with these requests. Whether `Synheart.initialize()` contacts the network
is not verified; the consent copy claims only that cloud upload is off.

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
confidence gate and the low-confidence marker, publishing the first reading
above the gate, check-in diagnostics, liveness, WearSim link validation and
cues, and consent before any source. They also cover the demo story and its
pinned lists, all three seeded scenarios, the accessibility guidelines and 160%
text. On a device, only the Galaxy Watch path has been run so far (2026-09-29);
HealthKit, Health Connect and the BLE strap are untested on hardware.

## Build log

Built step by step — one commit per step — see `git log`.
