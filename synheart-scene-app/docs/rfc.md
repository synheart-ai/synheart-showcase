<!-- Copied from Notion ("Scene_by_Synheart_App_RFC") on 2026-09-28. Kept verbatim,
     including words that were garbled in the copy (e.g. "behioral", "tasvidence",
     "implementa", "valis", "thbaseline", "raimmediately"). -->

# Scene_by_Synheart_App_RFC

# RFC: Scene by Synheart cinema discovery demo

**Status:** Proposed

**Owner:** Product Operations

**Reviewers:** Engineering, Design, Research

**Target:** Demo MVP

**Decision requested:** Approve the MVP scope and confirm the Synheart signal contract, supported mobile platform, and demo data mode.

## 1. Summary

Scene is a mobile movie discovery demo that combines a person’s stated movie preferences with their current context. During onboarding, the user rates films and chooses genres to establish a **taste baseline**. A short, consented interaction then supplies the Synheart signals supported by the integration. Scene ranks a curated film catalog using both inputs and explains why its recommendations differ from a taste-only list.

The central demo interaction is a toggle between **Taste only** and **Taste + current state**. It should make the change in ranking visible while preserving user choice. Scene proposes movies; it does not infer genre preference from behioral signals or claim to diagnose a person.

## 2. Problem and goal

Conventional movie recommendations reflect past choices, but what someone usually enjoys may not fit a particular evening. Respona demonstrated this distinction for music. Scene applies the same product pattern to films and gives the team a reusable example of state-aware personalization.

**Goal:** In one short walkthrough, a viewer can see (1) how the app learned the user’s taste, (2) what current-state information was used, (3) which recommendation changed, and (4) why.

**Success for the demo:** A user can complete onboarding, a check-in, and a comparison without developer intervention. The displayed explanation must match the ranking inputs and avoid unsupported health or psychological claims.

## 3. Users and primary use case

The primary user is someone deciding what film to watch now. For the MVP, the app is a controlled demonstration for partners and internal stakeholders, rather than a streaming service. The demo user can sele a film, inspect a reason, watch an available trailer link if licensed or supplied, and give lightweight feedback. Playback and streaming availability are outside the MVP.

## 4. Proposed user flow

| Step | Screen | Required behavior |
| --- | --- | --- |
| 1 | Welcome | Explain taste plus current context; start profile setup. |
| 2 | Build movie profile | Rate a small curated set with Love, Like, Not for me, or Haven’t seen; choose genres and exploration preference. |
| 3 | Movie DNA | Summarize the resulting baseline in plain language, with an option to edit it. |
| 4 | Synheart check-in | Explain the interaction and ask for consent before collecting signals. Run the supported SDK flow. |
| 5 | Current context | Show only interpretable, available outputs with cautious labels and a timestamp; allow the user to skip or correct the suggested viewing intent. |
| 6 | Tonight’s picks | Show a short ranked list, film details, and a brief reason for each recommendation. |
| 7 | Why this movie? | Separate tasvidence from current-context evidence and the resulting recommendation. |
| 8 | Taste comparison | Toggle Taste only / Taste + current state; show which items moved and why. |

**User override:** Offer simple intents such as *Just entertain me*, *Keep me engaged*, and *Help me unwind*. Explicit intent takes precedence over an inferred viewing need in the ranking and explanation.

## 5. MVP scope

### In scope

- Single mobile app with the eight-screen flow above.
- Curated, locally available movie metadata sufficient to show meaningful ranking changes.
- Persisted taste baseline for the demo user, with edit and reset controls.
- One supported Synheart check-in path and a documented mapping from SDK outputs to app labels.
- Deterministic ranking with taste-only and taste-plus-state modes.
- Reason text generated from actual metadata and active ranking factors.
- Clear fallback when signals are unavailable, stale, declined, or invalid.
- Basic feedback: good fit / poor fit plus optional reason.
- Demo reset and seeded profiles for repeatable presentations; any simulated signal must be clearly labeled as demo data.

### Out of scope for the first build

- Streaming playback, subscriptions, ticketing, or provider availability.
- Large-scale collaborative filtering or a production recommendation model.
- Claims about mental health, stress diagnosis, or treatment.
- Passive background collection without a separate product and privacy review.
- A claim that the app knows whether a person *needs* a film; users remain free to choose.

## 6. Data and integration contract

### Taste baseline

Collect film ratings, selected genres, and an exploration preference. Derive a baseline profile for genre, tone, intensity, pacing, and familiarity where catalog metadata supports it. Do not treat *Haven’t seen* as dislike. Save the user’s direct inputs separately from inferred attributes so the profile can be explained and edited.

### Synheart check-in

Engineering and Research must agree on the SDK contract before implementa: supported platform, collection interaction, required permissions, latency, output fields and ranges, quality indicators, freshness, and failure modes. The app must use only fields actually provided or defensibly derived from approved SDK outputs. Labels such as **energy**, **engagement**, or **mental load** are provisional until this mapping is validated. Show a neutral message if there is insufficient signal.

### Movie catalog

Each film needs an ID, title, year, synopsis, genres, runtime, artwork rights/source, trailer URL if used, and curated tags for tone, intensity, pace, cognitive demand, and familiarity. The team should verify metadata and media-use rights before sharing the demo externally. A small, well-tagged catalog is preferable to a large catalog with thin metadata.

### Data handling

Ask consent for the check-in and provide Skip. Define retention for interaction data and derived state before shipping. For MVP, prefer storing the derived snapshot needed for the demo and avoiding raw text or raw behavioral events unless the SDK requires them. Provide an in-app reset that clears the local profile and state snapshot. Confirm whether any data leaves the device as part of SDK integration and reflect that accurately in the consent copy.

## 7. Recommendation design

Filter out films marked *Not for me*, exclude unavailable or incomplete catalog entries, and optionally exclude already-watched films. Rank the remaining films using:

`final score = taste fit + current-state fit + explicit context fit`

For an initial implementation, use weights of **50% taste, 35% state, 15% context** as tunable defaults, not as a validated scientific formula. The taste-only mode re-ranks the same eligible catalog using baseline preferences alone. Explicit user intent and hard constraints such as runtime act as filters or overrides where appropriate. Keep a contribution record for each ranked film so the explanation can cite the real factors.

Do not display a numerical “94% match” unless the team defines and valis what that percentage means. Use descriptive labels such as *Strong fit for tonight* in the first demo.

**Illustrative scenario:** A user who likes dark thrillers might receive *Se7en* near the top in Taste only. If a validated current-state signal and the user’s chosen intent favor a lighter experience, *Knives Out* might rise in Taste + current state. This is an example ranking for the seeded demo profile, not a promise that a given signal always implies a viewing preference.

## 8. Explanation and UI rules

- **Why this movie?** shows three parts: “Your taste,” “Right now,” and “How that affected this pick.”
- Every claim must trace to a rated film, selected preference, chosen intent, approved state mapping, or catalog attribute.
- Use tentative language for inferred context: “This may be a good fit” rather than “You are stressed.”
- If the state is missing or stale, label the list Taste only; do not imply Synheart shaped it.
- If the user chooses a different intent, update the raimmediately.
- Show the age of the state snapshot and offer a new check-in.

## 9. Functional acceptance criteria

1. A new user can complete or skip each optional preference without getting stuck; the app still produces a sensible baseline from the remaining inputs.
2. A user can edit ratings and genres, and the taste-only ranking updates accordingly.
3. The check-in requests consent, exposes a Skip path, and reports loading, success, insufficient-signal, and failure states.
4. The app never displays a state label that lacks an approved mapping from an available SDK output.
5. The comparison toggle uses the same eligible catalog; changed ordering is visible and explanations match the active mode.
6. A selected viewing intent affects ranking in the documented way and is represented in the reason text.
7. With consent declined, no usable signal, or stale data, recommendations remain available in Taste only mode.
8. Demo reset clears the user’s locally stored inputs and state snapshot; seeded scenarios can  restored consistently.
9. Core screens support readable text, accessible controls and labels, and an obvious back path.
10. The demo works without network access for catalog and baseline flows; document any network-dependent Synheart or trailer behavior separately.

## 10. Measurement and demo validation

Instrument completion of onboarding, consent or skip, successful check-in, recommendation view, comparison toggle, explanation view, intent change, film selection, and feedback. Collect only the event fields needed to evaluate the demo, avoiding raw check-in content. Review whether the audience can correctly describe why the top result changed after a walkthrough. Test at least three seeded scenarios: a meaningful ranking change, no meaningful change, and unavailable state. A no-change result should be explained honestly rather than forced.

## 11. Delivery sequence

1. **Confirm contract and catalog.** Validate SDK outputs, collection flow, privacy copy, movie tags, and demo scenarios with Engineering and Research.
2. **Build baseline and catalog.** Implement onboarding, Movie DNA, local data model, and taste-only ranking.
3. **Integrate state.** Add consent, SDK adapter, freshness and quality handling, state mapping, and fallbacks.
4. **Build comparison and explanations.** Implement both ranking modes, transparent reason records, user intent, and the toggle.
5. **Polish and rehearse.** Test real and seeded paths, accessibility, reset, offline behavior, and live-demo timing.

## 12. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| SDK outputs do not support the proposed labels | Confirm the contract first; use only supported labels and revise the UI copy. |
| Check-in is slow or fails during a live demo | Provide a repeatable seeded scenario, clearly marked as demo data, plus a Taste only fallback. |
| Film metadata produces implausible recommendations | Curate a compact catalog, review tags with the team, and rehearse edge cases. |
| State language sounds diagnostic or overly certain | Review mappings and copy with Research; use tentative, non-clinical wording. |
| Audience cannot see Synheart’s contribution | Make the comparison toggle and factor-level explanation central to the demo. |
| Posters or trailers cannot be used externally | Confirm rights or use licensed/owned assets and text-only placeholders. |

## 13. Open decisions before build approval

- Which mobile platform and framework will host this demo?
- Which Synheart SDK interaction and output fields are available today, and what quality/freshness rules apply?
- Will the first live demonstration use actual SDK results, seeded data, or both? How will seeded data be labeled?
- Where will data be processed and stored, and what retention period is approved?
- Who owns and approves film tagging, recommendation examples, and media rights?
- Which specific audience and demo date are we targeting?

## 14. Decision proposal

Approve Scene as an eight-screen demo MVP, contingent on the SDK contract and data-handling decisions above. Build thbaseline and taste-only experience first, then integrate verified Synheart outputs and the comparison view. The release gate is a repeatable walkthrough in which every displayed state label and recommendation explanation is supported by the underlying inputs.
