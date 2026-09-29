import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/demo_log.dart';
import 'package:scene/app/scene_cubit.dart';
import 'package:scene/data/demo_scenarios.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_signals.dart';
import 'helpers.dart';

void main() {
  late FakeSignals fake;

  Future<void> toTonight(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    fake = FakeSignals();
    await tester.pumpWidget(SceneApp(signals: fake));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Skip — see tonight's picks"));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(appBarSettings());
    await tester.pumpAndSettle();
  }

  testWidgets('Settings is one tap away on Welcome, Movie DNA and Tonight', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SceneApp(signals: FakeSignals()));
    await tester.pumpAndSettle();

    Future<void> opensSettings() async {
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await opensSettings(); // Welcome, before any profile or consent
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await opensSettings(); // Movie DNA
    await tester.tap(find.text("Skip — see tonight's picks"));
    await tester.pumpAndSettle();
    await opensSettings(); // Tonight
  });

  testWidgets('with no state the pill and sheet say so, and picks are taste only', (tester) async {
    await toTonight(tester);
    expect(find.text('No state'), findsOneWidget); // the pill
    expect(find.textContaining('Taste only. No current state was used'), findsOneWidget);
    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();
    expect(find.text('CURRENT STATE'), findsOneWidget);
    expect(find.textContaining('Connect a wearable in Settings'), findsOneWidget);
  });

  testWidgets('consent comes first: no source is offered and nothing starts before it', (tester) async {
    await toTonight(tester);
    await openSettings(tester);
    expect(find.text('Let Scene read your current state'), findsOneWidget);
    expect(find.textContaining('Cloud upload is off'), findsOneWidget);
    expect(find.text('Bluetooth heart-rate monitor'), findsNothing);
    expect(fake.calls, isEmpty);
  });

  testWidgets('the full check-in: consent, choose a source, read, then collection stops (plan §4, §10)', (tester) async {
    await toTonight(tester);
    tester.view.physicalSize = const Size(1170, 7000); // whole screens, no scrolling
    await tester.tap(find.text('Do a Synheart check-in'));
    await tester.pumpAndSettle();

    // Consent first; nothing has started.
    expect(find.text('Let Scene read your current state'), findsOneWidget);
    expect(find.textContaining('Only during a check-in'), findsOneWidget);
    expect(fake.calls, isEmpty);
    await tester.tap(find.text('I agree — continue'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['start']);

    // Choose and test the strap in Settings; leaving Settings pauses it.
    expect(find.text('No source chosen yet'), findsOneWidget);
    await tester.tap(find.text('Choose a source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bluetooth heart-rate monitor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polar H10'));
    await tester.pumpAndSettle();
    fake.heartRateCtl.add(64);
    await tester.pump();
    expect(find.text('Signal arriving · 64 BPM'), findsOneWidget);
    fake.emit(const CurrentState(stress: AxisReading(0.8, 0.8), source: StateSource.synheart));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'disconnect', reason: 'leaving Settings stops collection');
    expect(find.text('No state'), findsNothing, reason: 'we are on the check-in, not home');

    // The check-in reconnects the strap and reads.
    expect(find.text('Polar H10'), findsOneWidget);
    await tester.tap(find.text('Start check-in'));
    // Not pumpAndSettle: the reading screen animates, and settling would run
    // fake time past the 3-minute check-in timeout.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sit back for a minute'), findsOneWidget);
    fake.heartRateCtl.add(66);
    await tester.pump();
    expect(find.text('66 BPM'), findsOneWidget);

    fake.emit(const CurrentState(stress: AxisReading(0.8, 0.8), capacity: AxisReading(0.3, 0.7), source: StateSource.synheart));
    await tester.pumpAndSettle();

    // The plan's Current State card; collection has stopped.
    expect(find.text('Your current state'), findsOneWidget);
    expect(find.text('This may be a good evening to unwind.'), findsOneWidget);
    expect(find.text('Mental load'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Not available'), findsNWidgets(2)); // energy and engagement were not in the reading
    expect(find.text('Unwind'), findsOneWidget);
    expect(find.text('Help me unwind (suggested)'), findsOneWidget);
    expect(fake.calls.last, 'disconnect');

    await tester.tap(find.text("See tonight's picks"));
    await tester.pumpAndSettle();
    expect(find.text('Unwind'), findsOneWidget); // the pill
  });

  testWidgets('demo data on the check-in shows the plan\'s example card (§4)', (tester) async {
    await toTonight(tester);
    tester.view.physicalSize = const Size(1170, 7000);
    await tester.tap(find.text('Do a Synheart check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Demo data: Busy day'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO DATA — NOT A REAL READING'), findsOneWidget);
    for (final (label, level) in [('Energy', 'Moderate'), ('Mental load', 'High'), ('Engagement', 'Moderate')]) {
      final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
      expect(find.descendant(of: row, matching: find.text(level)), findsOneWidget, reason: label);
    }
    expect(find.text('Unwind'), findsOneWidget);
    expect(fake.calls, isEmpty, reason: 'demo data collects nothing');
  });

  testWidgets('the Galaxy Watch source connects and shows the watch name', (tester) async {
    await toTonight(tester);
    tester.view.physicalSize = const Size(1170, 7000);
    await openSettings(tester);
    await tester.tap(find.text('I agree — continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Heart rate only'), findsOneWidget);
    await tester.tap(find.text('Galaxy Watch'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('watch'));
    expect(find.text('Galaxy Watch6'), findsOneWidget);
  });

  testWidgets('a demo scenario is labelled demo data everywhere', (tester) async {
    await toTonight(tester);
    await useDemo(tester, 'Busy day');
    expect(find.text('Unwind'), findsOneWidget);
    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo data — not a real reading'), findsOneWidget);
  });

  testWidgets('a low-confidence reading means taste only, said plainly (RFC §10)', (tester) async {
    await toTonight(tester);
    await useDemo(tester, 'Signal too weak');
    expect(find.textContaining('not enough signal yet'), findsOneWidget);
    expect(find.text('Do a Synheart check-in'), findsOneWidget);
  });

  testWidgets('"not enough signal" is logged once, although readings keep arriving', (tester) async {
    await toTonight(tester);
    tester.view.physicalSize = const Size(1170, 7000);
    await tester.tap(find.text('Do a Synheart check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I agree — continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bluetooth heart-rate monitor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polar H10'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start check-in'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 3, seconds: 1)); // the timeout
    await tester.pump();
    expect(find.text('Not enough signal'), findsOneWidget);

    // As on device: the runtime keeps closing empty windows after collection stops.
    const empty = CurrentState(stress: AxisReading(0.1, 0.0), source: StateSource.synheart);
    for (var i = 0; i < 5; i++) {
      fake.emit(empty);
      await tester.pump(const Duration(minutes: 1));
    }
    final log = tester.element(find.byType(Scaffold).last).read<SceneCubit>().log;
    expect(log.entries.where((e) => e.event == DemoEvent.checkInInsufficientSignal), hasLength(1));
  });

  testWidgets('demo data and consent are logged, with no signal values', (tester) async {
    await toTonight(tester);
    await useDemo(tester, 'Busy day');
    final log = tester.element(find.byType(Scaffold).last).read<SceneCubit>().log;
    expect(log.entries.map((e) => e.event), contains(DemoEvent.demoScenarioUsed));
    expect(log.entries.map((e) => '$e').join(), isNot(contains('0.78')));
  });

  group('reading storage (RFC §6, §9.8)', () {
    test('the reading survives a restart and goes stale', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 9, 28, 20);
      final a = SceneCubit(prefs: prefs, clock: () => now);
      a.setCurrentState(DemoScenario.busyEvening.state);
      expect(a.state.current!.capturedAt, now);

      final b = SceneCubit(prefs: prefs, clock: () => now);
      expect(b.state.current, a.state.current);
      expect(b.freshState, isNotNull);
      now = now.add(const Duration(minutes: 31));
      expect(b.freshState, isNull);
    });

    test('reset clears inputs and the reading', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = SceneCubit(prefs: prefs)..setCurrentState(DemoScenario.busyEvening.state);
      a.reset();
      expect(prefs.getKeys(), isEmpty);
      expect(SceneCubit(prefs: prefs).state.current, isNull);
    });
  });
}
