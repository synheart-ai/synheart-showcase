import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scene/app/demo_log.dart';
import 'package:scene/app/scene_cubit.dart';
import 'package:scene/app/synheart.dart';
import 'package:scene/data/demo_scenarios.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/main.dart';

import 'helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> toCheckIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SceneApp(synheart: SynheartService.unavailable()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start my Synheart check-in'));
    await tester.pumpAndSettle();
  }

  Future<void> typeSlowly(WidgetTester tester, String text) async {
    final field = find.byType(TextField);
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(field, text.substring(0, i));
      await tester.pump(const Duration(milliseconds: 5));
    }
  }

  testWidgets('consent comes first, and nothing is typed before it', (tester) async {
    await toCheckIn(tester);
    expect(find.text('A short typing check-in'), findsOneWidget);
    expect(find.text('Where'), findsOneWidget);
    expect(find.text('On this device. Nothing is sent anywhere.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('I agree — start the check-in'), findsOneWidget);
    expect(find.text('Skip — use my taste only'), findsOneWidget);
  });

  testWidgets('skip leads to taste-only picks', (tester) async {
    await toCheckIn(tester);
    await tester.tap(find.text('Skip — use my taste only'));
    await tester.pumpAndSettle();
    expect(find.text("Tonight's picks"), findsOneWidget);
    expect(find.text('Se7en'), findsWidgets);
  });

  testWidgets('after consent: too little typing is reported neutrally', (tester) async {
    await toCheckIn(tester);
    await tester.tap(find.text('I agree — start the check-in'));
    await tester.pumpAndSettle();
    await typeSlowly(tester, 'Long day');
    await tester.tap(find.text('Read my current context'));
    await tester.pumpAndSettle();
    expect(find.text('Not enough signal yet'), findsOneWidget);
  });

  testWidgets('after consent: enough typing gives a Synheart snapshot and clears the text', (tester) async {
    await toCheckIn(tester);
    await tester.tap(find.text('I agree — start the check-in'));
    await tester.pumpAndSettle();
    await typeSlowly(tester, 'It was a long day at work but I feel ok now');
    await tester.tap(find.text('Read my current context'));
    await tester.pumpAndSettle();
    expect(find.text('FROM YOUR SYNHEART CHECK-IN'), findsOneWidget);

    // The event log saw the check-in, and never the words (RFC §10).
    final log = tester.element(find.byType(Scaffold).last).read<SceneCubit>().log;
    final events = log.entries.map((e) => e.event).toList();
    expect(events, containsAllInOrder([DemoEvent.onboardingCompleted, DemoEvent.checkInConsented, DemoEvent.checkInSucceeded]));
    expect(log.entries.map((e) => '$e').join('\n').toLowerCase(), isNot(contains('long day')));
  });

  testWidgets('a demo scenario is labelled demo data and can be adjusted', (tester) async {
    await toCheckIn(tester);
    await tapDemo(tester, 'Busy day');
    await tester.pumpAndSettle();
    expect(find.text('DEMO DATA — NOT A REAL CHECK-IN'), findsOneWidget);

    await tester.tap(find.text('Low').at(1));
    await tester.pumpAndSettle();
    expect(find.text('ADJUSTED BY YOU'), findsOneWidget);
  });

  group('snapshot storage (RFC §6, §9.8)', () {
    test('the derived snapshot survives a restart and goes stale', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 9, 28, 20);
      final a = SceneCubit(prefs: prefs, clock: () => now);
      a.setCurrentState(DemoScenario.busyEvening.state);
      expect(a.state.current!.capturedAt, now);

      final b = SceneCubit(prefs: prefs, clock: () => now);
      expect(b.state.current!.mentalLoad, 0.8);
      expect(b.state.current!.source, StateSource.preset);
      expect(b.freshState, isNotNull);
      now = now.add(const Duration(hours: 3));
      expect(b.freshState, isNull);
    });

    test('reset clears inputs and the snapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = SceneCubit(prefs: prefs)..setCurrentState(DemoScenario.busyEvening.state);
      a.reset();
      expect(prefs.getKeys(), isEmpty);
      expect(SceneCubit(prefs: prefs).state.current, isNull);
    });
  });
}
