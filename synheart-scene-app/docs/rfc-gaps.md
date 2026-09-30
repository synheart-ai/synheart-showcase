# RFC gaps — what the first build did not meet

Checked 2026-09-28 against [`rfc.md`](rfc.md). The first build followed the demo
**plan** (PDF). The RFC is stricter in several places.

**Status: all 17 closed on 2026-09-28**, in commits `714e456` (engine), `10b2e53`
(check-in), `7d9f8ec` (screens), `03947d9` (baseline), `0ffcebe` (events) and
`3ea9bf5` (accessibility). Each is covered by tests.

| # | RFC | First build | Fix |
|---|---|---|---|
| 1 | §4.4, §6 — consent **before** collecting signals; Skip | `SynheartBehavior.initialize()` ran in `main()` and an app-wide gesture detector was attached, so collection could start before any consent. No consent step, no Skip | Consent card first; SDK started only after consent; no app-wide wrapper; Skip → taste only |
| 2 | §9.3 — loading / success / insufficient-signal / failure states | Snackbar on too little typing; no failure state | Explicit check-in status panel |
| 3 | §6 — confirm whether data leaves the device, and say so | Copy said "on this device" without verification | Verified in the 0.4.1 source (no HTTP client; Android only *reads* connectivity status); copy states it |
| 4 | §4.5, §8 — timestamp; snapshot age; offer a new check-in; stale → Taste only | No timestamp, no staleness | `capturedAt`; stale after 2 h (tunable default); stale or missing → taste only, labelled |
| 5 | §6 — labels are provisional; show only interpretable outputs; tentative language | "You seem to be …" | Labels marked provisional; "This may be a good evening to …" |
| 6 | §4.5 — skip or correct the suggested viewing intent | Intent only on Tonight, only in taste + state mode | Intent chips on Current context and in both modes |
| 7 | §4 — explicit intent takes precedence over an inferred need | Intent carried a fixed 15% | With an intent, context takes the 35% share and state the 15% share |
| 8 | §7 — no numerical "% match" | "Overall match 94%" and percentage bars | Descriptive fit labels ("Strong fit for tonight") |
| 9 | §8 — Why: "Your taste" / "Right now" / "How that affected this pick" | "Your baseline" / "Your current context" / "The recommendation" | Renamed; every line from the contribution record |
| 10 | §4.8 — show which items **moved** and why | Only a "new tonight" marker | Rank movement (↑ ↓ new, dropped) |
| 11 | §10 — a no-change result is explained honestly | Not handled | Compare says so when the lists barely differ |
| 12 | §5, §10 — seeded scenarios: meaningful change / no meaningful change / unavailable, labelled demo data | One preset | Three labelled scenarios |
| 13 | §4.3, §9.2 — edit the baseline | "Redo" wiped everything | Edit keeps answers; separate Reset demo |
| 14 | §6, §9.8 — reset clears inputs **and** state snapshot; derived snapshot may be stored | Snapshot not stored | Derived snapshot persisted (no raw events, no text); reset clears both |
| 15 | §9.1 — every optional preference can be skipped | Genres step needed at least one rating | "Skip" on every step; baseline from what remains |
| 16 | §10 — instrument the demo events, no raw content | None | Local event log: event names and enum values only |
| 17 | §9.9 — accessible controls; obvious back path | `context.go` everywhere, so no back arrow; posters read titles twice | Forward steps push; poster art excluded from semantics |

## Open decisions (§13) — what the build assumes until they are made

| Decision | Current assumption |
|---|---|
| Platform / framework | Flutter, iOS + Android |
| SDK interaction and outputs | `synheart_core` 0.15.0 HSI axes (focus, stress, arousal, capacity) with confidence, from wearable sources; see [state-mapping.md](state-mapping.md) |
| Real SDK results, seeded data, or both | Both; seeded ones are labelled **Demo data** everywhere they appear |
| Processing, storage, retention | HSI is computed on device, with cloud upload off. Answers, the latest reading and the TMDB film-data cache are kept in app storage until **Reset demo** (the cache survives it). Raw samples are never stored |
| Tagging and media rights owner | **Open.** Tags are my curation. Posters, synopses and trailers come from TMDB (attribution + official logo shown; licence for external demos unconfirmed); typographic posters without a token |
| Audience and date | **Open** |

## Update 2026-09-28 — HSI, as in Resona

After the gap work, Scene moved from a typing heuristic to **Synheart Core HSI**
(commits `4bd0994`, `245f321`, `5b50e7c`). Effect on the RFC:

- **§6 SDK contract:** the app now uses fields the SDK actually provides:
  HSI axes, each with a confidence. That replaces labels Scene had invented.
  Low confidence means unavailable (Resona's rule).
- **§4.4 / §6 consent:** consent is in Settings, before any source. The
  runtime is given local-only consent.
- **§9.3 statuses:** listening, not enough signal, signal settling, no clear
  need, and too old are shown on the state pill and sheet.
- **§4 flow:** the *Synheart check-in* and *Current context* screens are
  replaced by Settings (sources) and the state sheet. Tonight is now a
  browse home. The eight RFC steps are all still there, in that shape.

## Update 2026-09-29 — back in line with the plan and RFC

A review against both documents found three drifts from the HSI move, now fixed
(`e28cd30`, `aee7a22`):

1. **The check-in moment was gone** (plan §4, §10; RFC §4.4). Restored as its
   own screen, followed by a Current State screen.
2. **Continuous collection edged into RFC §5's out-of-scope "passive
   background collection".** Scene now collects only during a check-in.
3. **Raw axis names ("Stress: higher") replaced the plan's plain language.**
   The card shows Energy / Mental load / Engagement again, with a provisional
   mapping.

Also restored: Movie DNA percentages (plan §3). The RFC's no-percentage rule
is about the match score.

## Recheck 2026-09-30 — after TMDB, the Galaxy Watch and the "> 0" gate

A fresh read of the demo plan (PDF) and this RFC against the code at `25ddebb`.
The 17 fixes above still hold. Found and fixed in `d6d7231`:

| RFC / plan | Finding | Fix |
|---|---|---|
| §8, §9.4 | The gate was lowered to "> 0" (2026-09-29, product decision) so the heart-rate-only watch gives a reading. Readings at 0.01–0.17 then drove firm labels ("Engagement: Low", "Easy watch"), while the copy said uncertain readings were left out | Kept the gate; readings under Resona's 0.45 are marked *low confidence* on the state card, sheet, Tonight and Why; copy corrected |
| §4 override | Explicit intent led the ranking but not the Why headline | Headline follows the chosen intent |
| §10 | Tonight showed the demo line even for *Rested and focused*, where Compare says nothing meaningful changed | Line only when the comparison is meaningful |
| §8; plan §10 | Why had no snapshot age or new check-in; the closing message only appeared on Compare | Both added to Why |
| §6 | Consent said "heart rate and HRV" (the watch sends HR only) and nothing about TMDB / YouTube network use | Consent and Settings copy corrected; README network section |
| §12 | TMDB logo missing | Official logo with the attribution in Settings and Why |
| plan §6 | Demo lists matched the README but no test pinned them; near-ties | Exact top five pinned by a test; differences from the plan documented in the README |

Corrections to lines above that are now out of date: staleness is **30 min**
(`CurrentState.freshFor`), not 2 h (row 4); row 3's "0.4.1 source, no HTTP
client" referred to the old typing SDK — the app now calls TMDB, and the watch
relay's routing is not verified; "Low confidence means unavailable" (HSI
update) is replaced by the temporary gate and the marker.

Left as is, and documented: watched films are always excluded, not optionally
(§7); there is no check for incomplete catalogue entries (§7) — all 45 are
hand-curated.

## Decision 2026-09-30 — continuous behavior and biosignal collection

Product decision (user): after consent, Scene collects **heart rate and
behavior continuously, in the foreground and the background**, and the state
updates live; the check-in is optional. Behavior = taps / scrolls / swipes in
Scene, app switches, notification and call events (no content), motion; no
typing. Android keeps running through a foreground service with an ongoing
notification and a cached Flutter engine; iOS is foreground only.

This **reverses** the 2026-09-29 fix above ("Scene now collects only during a
check-in") and goes against **RFC §5 out of scope: "Passive background
collection without a separate product and privacy review."** The consent card,
Settings and README now say what is collected and when (RFC §6). The privacy
review itself is **not done** — needed before any external demo.

## Still open, and not code

- **Privacy review for continuous collection** (RFC §5), and the Play policy
  declaration for the notification listener, if Scene is ever published.
- **The confidence gate:** "> 0" is temporary. With it, a heart-rate-only
  source always "passes" and the live *Not enough signal* path needs exactly
  zero confidence. Decide before any external demo (see state-mapping.md).
- **§6 SDK contract:** Engineering and Research have not agreed the fields,
  quality rules or freshness. The build documents what it uses in
  [state-mapping.md](state-mapping.md) and marks every label provisional.
- **§10 audience check:** whether viewers can say why the top pick changed is a
  rehearsal question. The event log helps, but only a rehearsal answers it.
- **Device run:** the Galaxy Watch6 path ran on a Samsung SM-A235F on
  2026-09-29 (live heart rate; check-in succeeds under the "> 0" gate). The BLE
  strap, Health Connect, HealthKit and iOS are not yet run on hardware.
- **Network during `Synheart.initialize()`:** not verified; the consent copy
  claims only "cloud upload is off".
- **Trailers:** YouTube links from TMDB; they need a connection (§9.10).

## Plan vs RFC differences kept on purpose

- **Feedback:** the RFC asks for "good fit / poor fit plus optional reason". The
  build keeps the plan's four options. They are a superset: *Perfect* and
  *Pretty good* count as good, the other two as poor.
