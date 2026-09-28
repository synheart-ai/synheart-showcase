import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/engine/explain.dart';
import 'package:scene/engine/recommender.dart';
import 'package:scene/engine/taste_builder.dart';

void main() {
  final persona = buildTasteProfile(demoPersonaAnswers);
  const engine = Recommender();

  test('Knives Out under the plan example state reads like the plan (§5)', () {
    final r = engine.score(filmById('knives-out')!, persona, state: CurrentState.planExample);
    final e = explain(r, state: CurrentState.planExample, usualIntensity: persona.preferredIntensity);
    expect(e.baseline, contains('mystery'));
    expect(e.context, contains('lower intensity'));
    expect(e.context, contains('moderate cognitive engagement'));
    expect(e.context, contains('entertaining rather than emotionally heavy'));
    expect(e.recommendation, contains('stays true to your taste'));
    expect(e.headline, startsWith('Matches your taste for'));
  });

  test('taste-only picks say so and carry no context line', () {
    final r = engine.score(filmById('se7en')!, persona, mode: RecommendationMode.tasteOnly);
    final e = explain(r, mode: RecommendationMode.tasteOnly);
    expect(e.context, isNull);
    expect(e.recommendation, contains('taste alone'));
  });

  test('context line names the runtime limit and the chosen intent', () {
    const viewing = ViewingContext(intent: EveningIntent.unwind, maxRuntimeMinutes: 90);
    final r = engine.score(filmById('palm-springs')!, persona, state: CurrentState.planExample, context: viewing);
    final e = explain(r, state: CurrentState.planExample, viewing: viewing);
    expect(e.context, contains('under 90 minutes'));
    expect(e.context, contains('Help me unwind'));
  });
}
