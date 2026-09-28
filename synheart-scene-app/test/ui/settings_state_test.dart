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
    await tester.tap(find.text("See tonight's picks"));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

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

  testWidgets('after consent, sources connect through the Synheart runtime', (tester) async {
    await toTonight(tester);
    tester.view.physicalSize = const Size(1170, 7000); // the whole Settings page on screen
    await openSettings(tester);
    final agree = find.text('I agree — continue');
    await tester.tap(agree);
    await tester.pumpAndSettle();
    expect(fake.calls, ['start']);

    await tester.tap(find.text('Bluetooth heart-rate monitor'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('scan'));
    await tester.tap(find.text('Polar H10'));
    await tester.pumpAndSettle();
    expect(fake.calls, containsAllInOrder(['scan', 'disconnect', 'ble:hrm-1']));
    expect(find.text('Waiting for a signal…'), findsOneWidget);

    fake.heartRateCtl.add(64);
    await tester.pump();
    expect(find.text('Signal arriving · 64 BPM'), findsOneWidget);

    // A confident reading is published: back on Tonight, the pill shows it.
    fake.emit(const CurrentState(stress: AxisReading(0.8, 0.8), capacity: AxisReading(0.3, 0.7), source: StateSource.synheart));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Unwind'), findsOneWidget);
    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();
    expect(find.text('Your rhythm has picked up'), findsOneWidget);
    expect(find.textContaining('From your wearable, via Synheart'), findsOneWidget);
    expect(find.text('not available'), findsNWidgets(2)); // focus and arousal were not in the reading
    expect(find.text('Help me unwind (suggested)'), findsOneWidget);
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
    expect(find.text('Connect a source'), findsOneWidget);
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
