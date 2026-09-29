import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/data/demo_scenarios.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/engine/explain.dart';
import 'package:scene/engine/recommender.dart';
import 'package:scene/engine/taste_builder.dart';

void main() {
  final persona = buildTasteProfile(demoPersonaAnswers);
  const engine = Recommender();

  test('Knives Out under the busy-evening state: three parts, tentative, traceable (RFC §8)', () {
    final r = engine.score(filmById('knives-out')!, persona, state: DemoScenario.busyEvening.state);
    final e = explain(r, state: DemoScenario.busyEvening.state, usualIntensity: persona.preferredIntensity, tasteOnlyRank: 11);
    expect(e.taste, contains('mystery'));
    expect(e.rightNow, contains('The demo data suggests this may be a good evening to unwind'));
    expect(e.rightNow, contains('Based on energy (moderate), mental load (high) and engagement (moderate).'));
    expect(e.rightNow, contains('lower intensity than you usually choose'));
    expect(e.rightNow, contains('entertaining rather than emotionally heavy'));
    expect(e.effect, contains('Taste counted for 50%, your current state for 35% and your choices for 15%'));
    expect(e.effect, contains('On taste alone it was #11'));
    expect(e.headline, contains('may suit tonight'));
  });

  test('taste-only picks say so and carry no "right now" part', () {
    final r = engine.score(filmById('se7en')!, persona, mode: RecommendationMode.tasteOnly);
    final e = explain(r);
    expect(e.rightNow, isNull);
    expect(e.effect, contains('taste alone'));
    expect(e.effect, contains('No current state was used'));
    expect(e.headline, startsWith('Strong fit for your taste'));
  });

  test('a chosen intent is named, with its precedence over the current state (RFC §9.6)', () {
    const viewing = ViewingContext(intent: EveningIntent.unwind, maxRuntimeMinutes: 90);
    final r = engine.score(filmById('palm-springs')!, persona, state: DemoScenario.busyEvening.state, context: viewing);
    final e = explain(r, state: DemoScenario.busyEvening.state, viewing: viewing);
    expect(e.rightNow, contains('You chose "Help me unwind", which takes precedence over your current state.'));
    expect(e.rightNow, contains('90 minutes or less'));
    expect(e.effect, contains('your current state for 15% and your choices for 35%'));
  });

  test('taste only with an intent: no current state claimed', () {
    const viewing = ViewingContext(intent: EveningIntent.engaging);
    final r = engine.score(filmById('se7en')!, persona, mode: RecommendationMode.tasteOnly, context: viewing);
    final e = explain(r, viewing: viewing);
    expect(e.rightNow, 'You chose "Give me something engaging".');
    expect(e.effect, 'Ranked on taste (70%) and your choice of evening (30%). No current state was used.');
  });

  test('snapshot age', () {
    final at = DateTime(2026, 9, 28, 20);
    expect(ageLabel(at, at.add(const Duration(seconds: 20))), 'just now');
    expect(ageLabel(at, at.add(const Duration(minutes: 12))), '12 min ago');
    expect(ageLabel(at, at.add(const Duration(minutes: 65))), '1 h 5 min ago');
  });
}
