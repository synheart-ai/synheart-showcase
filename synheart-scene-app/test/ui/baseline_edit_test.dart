import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/scene_cubit.dart';
import 'package:scene/app/synheart.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/domain/taste.dart';
import 'package:scene/engine/recommender.dart';
import 'package:scene/main.dart';
import 'package:scene/ui/picks.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SceneApp(synheart: SynheartService.unavailable()));
    await tester.pumpAndSettle();
  }

  testWidgets('every preference can be skipped and a baseline still results (RFC §9.1)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Build my movie profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this film'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 16'), findsOneWidget);
    await tester.tap(find.text('Skip the rest'));
    await tester.pumpAndSettle();
    expect(find.textContaining('your baseline will be broad'), findsOneWidget);
    await tester.tap(find.text('See my Movie DNA'));
    await tester.pumpAndSettle();
    expect(find.text('Your Movie DNA'), findsOneWidget);
    expect(find.textContaining('Derived from 0 films you rated and 0 genres you picked'), findsOneWidget);
  });

  test('editing a rating updates the taste-only ranking at once (RFC §9.2)', () {
    final cubit = SceneCubit()..useAnswers(demoPersonaAnswers);
    List<String> top() => Picks.of(cubit).list(mode: RecommendationMode.tasteOnly).map((r) => r.film.id).toList();
    final before = top();
    expect(before.first, 'se7en');

    // Turn against dark crime: the list must change without re-onboarding.
    cubit
      ..rate('dark-knight', Rating.notForMe)
      ..rate('zodiac', Rating.notForMe)
      ..rate('parasite', Rating.notForMe)
      ..rate('superbad', Rating.love)
      ..rate('paddington-2', Rating.love);
    expect(cubit.state.hasProfile, isTrue);
    expect(top(), isNot(equals(before)));
  });

  testWidgets('Edit keeps answers; Reset demo asks first, then clears', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit your baseline'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Your Movie DNA'), findsOneWidget);

    await tester.tap(find.byTooltip('Reset demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Your Movie DNA'), findsOneWidget);

    await tester.tap(find.byTooltip('Reset demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Try the demo profile'), findsOneWidget);
  });
}
