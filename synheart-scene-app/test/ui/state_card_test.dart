import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/demo_scenarios.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/ui/state_card.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, CurrentState s) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StateCard(reading: s)))));

  testWidgets('a heart-rate-only watch reading is marked low confidence (RFC §8, §9.4)', (tester) async {
    // The Galaxy Watch6 reading from 2026-09-29.
    const watch = CurrentState(
      focus: AxisReading(0.0, 0.17),
      stress: AxisReading(0.11, 0.01),
      arousal: AxisReading(0.5, 0.14),
      capacity: AxisReading(0.5, 0.0),
      source: StateSource.synheart,
    );
    await pumpCard(tester, watch);
    expect(find.text('Easy watch'), findsOneWidget);
    // Energy, Mental load, Engagement and the suggested experience.
    expect(find.text('low confidence'), findsNWidgets(4));
    expect(find.textContaining('not sure about this reading'), findsOneWidget);
    expect(find.textContaining('left out'), findsNothing);
  });

  testWidgets('a confident reading carries no marker', (tester) async {
    await pumpCard(tester, DemoScenario.busyEvening.state);
    expect(find.text('Unwind'), findsOneWidget);
    expect(find.text('low confidence'), findsNothing);
  });
}
