import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/data/demo_scenarios.dart';
import 'package:scene/domain/film.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/domain/taste.dart';
import 'package:scene/engine/recommender.dart';
import 'package:scene/engine/taste_builder.dart';

List<String> ids(List<Recommendation> r) => r.map((x) => x.film.id).toList();

void main() {
  final persona = buildTasteProfile(demoPersonaAnswers);
  const engine = Recommender();

  group('Movie DNA (taste builder)', () {
    test('the demo persona reads as thriller / crime / mystery / sci-fi first', () {
      final top = persona.rankedGenres.take(4).map((e) => e.key).toSet();
      expect(top, {Genre.thriller, Genre.crime, Genre.mystery, Genre.sciFi});
    });

    test('affinities are spread out and never 100% (plan: "Thriller 92% …")', () {
      final values = persona.genreAffinity.values;
      expect(values.every((v) => v < 1), isTrue);
      expect(persona.affinityFor(Genre.thriller), greaterThan(persona.affinityFor(Genre.comedy) + 0.3));
    });

    test('films rated "Not for me" pull their genres down', () {
      final base = buildTasteProfile(const TasteAnswers(ratings: {'superbad': Rating.love}));
      final disliked = buildTasteProfile(const TasteAnswers(ratings: {'superbad': Rating.notForMe}));
      expect(disliked.affinityFor(Genre.comedy), lessThan(base.affinityFor(Genre.comedy)));
    });

    test('"Haven\'t seen it" says nothing about taste and is not "seen"', () {
      final p = buildTasteProfile(const TasteAnswers(ratings: {'toy-story': Rating.notSeen}));
      expect(p.seenFilmIds, isEmpty);
      expect(p.affinityFor(Genre.animation), closeTo(0.4, 1e-9));
    });

    test('dark-tone preference comes from what the user liked', () {
      expect(persona.likesDarkTones, greaterThan(0.7));
    });
  });

  group('recommendations — the plan\'s "What changed?" story (§6)', () {
    final tasteOnly = ids(engine.recommend(persona, mode: RecommendationMode.tasteOnly));
    final withState = ids(engine.recommend(persona, state: DemoScenario.busyEvening.state));

    test('taste only: the dark thrillers lead', () {
      expect(tasteOnly, containsAll(['se7en', 'prisoners', 'shutter-island', 'gone-girl']));
    });

    test('taste + state (high mental load → Unwind): lighter films from the same taste', () {
      const planList = ['knives-out', 'nice-guys', 'catch-me', 'grand-budapest', 'oceans-eleven'];
      // The fifth slot is a near-tie (Hot Fuzz / Catch Me If You Can / Grand
      // Budapest within 0.01), so pin the story, not the exact table.
      expect(withState.where(planList.contains).length, greaterThanOrEqualTo(3));
      expect(withState, contains('knives-out'));
      expect(withState, isNot(contains('se7en')));
      expect(withState, isNot(contains('prisoners')));
    });

    test('the lists differ although the taste profile is the same', () {
      expect(withState.toSet().intersection(tasteOnly.toSet()), isEmpty);
    });

    test('every taste + state pick is still true to taste', () {
      for (final r in engine.recommend(persona, state: DemoScenario.busyEvening.state)) {
        expect(r.matchedGenres, isNotEmpty, reason: r.film.title);
        expect(r.taste, greaterThan(0.55), reason: r.film.title);
      }
    });
  });

  group('rules', () {
    test('weights are the plan\'s 50 / 35 / 15', () {
      expect(tasteWeight + stateWeight + contextWeight, closeTo(1, 1e-9));
      final f = filmById('knives-out')!;
      final r = engine.score(f, persona, state: DemoScenario.busyEvening.state);
      expect(r.score, closeTo(0.5 * r.taste + 0.35 * r.state + 0.15 * r.context, 1e-9));
    });

    test('films the user has seen are never recommended back', () {
      final seen = buildTasteProfile(demoPersonaAnswers.copyWith(
        ratings: {...demoPersonaAnswers.ratings},
      ));
      final pool = Recommender(pool: allFilms);
      expect(ids(pool.recommend(seen, limit: 50)), isNot(contains('dark-knight')));
    });

    test('"90 minutes or less" filters by runtime', () {
      final r = engine.recommend(persona, state: DemoScenario.busyEvening.state, context: const ViewingContext(maxRuntimeMinutes: 90), limit: 20);
      expect(r, isNotEmpty);
      expect(r.every((x) => x.film.runtimeMinutes <= 90), isTrue);
    });

    test('raised arousal lifts energetic films above quiet ones', () {
      const lively = CurrentState(arousal: AxisReading(0.8, 0.8), source: StateSource.preset);
      final energetic = engine.stateFit(filmById('baby-driver')!, lively);
      final quiet = engine.stateFit(filmById('octopus-teacher')!, lively);
      expect(energetic, greaterThan(quiet));
    });

    test('Choose My Evening: "Help me unwind" favours gentle films', () {
      final ctx = const ViewingContext(intent: EveningIntent.unwind);
      expect(engine.contextFit(filmById('chef')!, ctx), greaterThan(engine.contextFit(filmById('se7en')!, ctx)));
    });

    test('the experience policy follows Resona\'s thresholds', () {
      expect(DemoScenario.busyEvening.state.suggestedExperience, Experience.unwind);
      expect(DemoScenario.freshAndFocused.state.suggestedExperience, Experience.stayEngaged);
      const drifting = CurrentState(focus: AxisReading(0.40, 0.7), source: StateSource.preset);
      expect(drifting.suggestedExperience, Experience.easyWatch);
      const inBetween = CurrentState(focus: AxisReading(0.52, 0.7), stress: AxisReading(0.4, 0.7), source: StateSource.preset);
      expect(inBetween.suggestedExperience, isNull, reason: 'no clear need is a real result');
    });

    test('the busy evening reads as the plan\'s example state card (§4)', () {
      final s = DemoScenario.busyEvening.state;
      expect(s.levelOf(PlainSignal.energy), SignalLevel.moderate);
      expect(s.levelOf(PlainSignal.mentalLoad), SignalLevel.high);
      expect(s.levelOf(PlainSignal.engagement), SignalLevel.moderate);
      expect(s.suggestedExperience, Experience.unwind);
    });

    test('a plain signal is unavailable when its readings are', () {
      const onlyStress = CurrentState(stress: AxisReading(0.7, 0.8), capacity: AxisReading(0.9, 0.2), source: StateSource.preset);
      expect(onlyStress.levelOf(PlainSignal.mentalLoad), SignalLevel.high, reason: 'capacity is below the gate; stress alone counts');
      expect(onlyStress.levelOf(PlainSignal.energy), isNull);
      expect(onlyStress.levelOf(PlainSignal.engagement), isNull);
    });

    test('the gate is temporarily "above 0": a heart-rate-only watch reading counts', () {
      // What the Galaxy Watch6 gave on device, 2026-09-29 (Focus 0.17, Arousal 0.14).
      const watch = CurrentState(focus: AxisReading(0.0, 0.17), arousal: AxisReading(0.5, 0.14), source: StateSource.synheart);
      expect(AxisReading.minConfidence, 0.0);
      expect(watch.availableAxes, [HsiAxis.focus, HsiAxis.arousal]);
      expect(watch.hasEvidence, isTrue);
      expect(const AxisReading(0.5, 0.0).isAvailable, isFalse);
    });

    test('zero-confidence axes are unavailable, never a negative result', () {
      const weak = CurrentState(stress: AxisReading(0.95, 0.0), focus: AxisReading(0.1, 0.0), source: StateSource.preset);
      expect(weak.hasEvidence, isFalse);
      expect(weak.suggestedExperience, isNull);
      // No usable axis → the ranking is taste only.
      final r = engine.score(filmById('se7en')!, persona, state: weak);
      expect(r.weights.usesState, isFalse);
      expect(DemoScenario.lowConfidence.state.hasEvidence, isFalse);
    });

    test('a missing axis sets no target', () {
      const focusOnly = CurrentState(focus: AxisReading(0.8, 0.9), source: StateSource.preset);
      final t = StateTargets.from(focusOnly);
      expect(t.intensity, isNull);
      expect(t.strain, isNull);
      expect(t.cognitiveLoad, closeTo(0.7, 1e-9));
    });
  });
}
