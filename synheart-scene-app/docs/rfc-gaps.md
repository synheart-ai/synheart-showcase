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
| Processing, storage, retention | HSI is computed on device, with cloud upload off. Answers and the latest reading are kept in app storage until **Reset demo**. Raw samples are never stored |
| Tagging and media rights owner | **Open.** Tags are my curation; posters are typographic (no artwork) |
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

## Still open, and not code

- **§6 SDK contract:** Engineering and Research have not agreed the fields,
  quality rules or freshness. The build documents what it uses in
  [state-mapping.md](state-mapping.md) and marks every label provisional.
- **§10 audience check:** whether viewers can say why the top pick changed is a
  rehearsal question. The event log helps, but only a rehearsal answers it.
- **Device run:** wearables, HealthKit, Health Connect and the native runtime
  have been built into the app but not yet run on a phone.
- **Network during `Synheart.initialize()`:** not verified; the consent copy
  claims only "cloud upload is off".
- **Trailers:** no trailer links (RFC §3 makes them optional).

## Plan vs RFC differences kept on purpose

- **Feedback:** the RFC asks for "good fit / poor fit plus optional reason". The
  build keeps the plan's four options. They are a superset: *Perfect* and
  *Pretty good* count as good, the other two as poor.
