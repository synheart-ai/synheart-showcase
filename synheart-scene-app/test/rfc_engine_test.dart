import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/data/demo_scenarios.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/engine/recommender.dart';
import 'package:scene/engine/taste_builder.dart';

void main() {
  final persona = buildTasteProfile(demoPersonaAnswers);
  const engine = Recommender();

  group('explicit intent takes precedence (RFC §4)', () {
    test('with an intent, context carries the 35% share and state 15%', () {
      final r = engine.score(filmById('knives-out')!, persona,
          state: DemoScenario.busyEvening.state, context: const ViewingContext(intent: EveningIntent.engaging));
      expect(r.weights.context, 0.35);
      expect(r.weights.state, 0.15);
      expect(r.score, closeTo(0.5 * r.taste + 0.15 * r.state + 0.35 * r.context, 1e-9));
    });

    test('an intent that disagrees with the state moves the list towards the intent', () {
      const engaging = ViewingContext(intent: EveningIntent.engaging);
      final plain = engine.recommend(persona, state: DemoScenario.busyEvening.state);
      final chosen = engine.recommend(persona, state: DemoScenario.busyEvening.state, context: engaging);
      double load(List<Recommendation> l) => l.map((r) => r.film.cognitiveLoad).reduce((a, b) => a + b) / l.length;
      expect(load(chosen), greaterThan(load(plain)));
    });

    test('taste only with no intent is taste alone; with an intent it is 70 / 30', () {
      final f = filmById('se7en')!;
      expect(engine.score(f, persona, mode: RecommendationMode.tasteOnly).weights.taste, 1);
      final w = engine.score(f, persona, mode: RecommendationMode.tasteOnly, context: const ViewingContext(intent: EveningIntent.unwind)).weights;
      expect([w.taste, w.state, w.context], [0.7, 0, 0.3]);
    });
  });

  group('descriptive fit, not a percentage (RFC §7)', () {
    test('labels say whose fit it is', () {
      final taste = engine.recommend(persona, mode: RecommendationMode.tasteOnly).first;
      final tonight = engine.recommend(persona, state: DemoScenario.busyEvening.state).first;
      expect(taste.fitLabel, 'Strong fit for your taste');
      expect(tonight.fitLabel, 'Strong fit for tonight');
      expect(Fit.of(0.65), Fit.good);
      expect(Fit.of(0.4), Fit.possible);
    });
  });

  group('comparison (RFC §4.8, §10) — the three seeded scenarios', () {
    test('busy evening: a meaningful change, with movement recorded', () {
      final c = compareRankings(engine, persona, state: DemoScenario.busyEvening.state);
      expect(c.isMeaningful, isTrue);
      expect(c.changes.first.before, greaterThan(5));
      expect(c.dropped.map((d) => d.film.id), contains('se7en'));
    });

    test('rested and focused: no meaningful change, reported as such', () {
      final c = compareRankings(engine, persona, state: DemoScenario.freshAndFocused.state);
      expect(c.isMeaningful, isFalse);
      expect(c.newCount, 0);
    });

    test('both modes rank the same eligible catalogue', () {
      final all = engine.recommend(persona, mode: RecommendationMode.tasteOnly, limit: null).map((r) => r.film.id).toSet();
      final withState = engine.recommend(persona, state: DemoScenario.busyEvening.state, limit: null).map((r) => r.film.id).toSet();
      expect(withState, all);
    });
  });

  group('freshness (RFC §8)', () {
    test('a reading goes stale 30 minutes after the signal stops', () {
      final at = DateTime(2026, 9, 28, 20);
      final s = DemoScenario.busyEvening.state.copyWith(capturedAt: at);
      expect(s.isStaleAt(at.add(const Duration(minutes: 29))), isFalse);
      expect(s.isStaleAt(at.add(const Duration(minutes: 31))), isTrue);
    });
  });
}
