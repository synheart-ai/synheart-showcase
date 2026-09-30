import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_signals.dart';
import 'package:scene/main.dart';

void main() {
  testWidgets('welcome shows the promise and both ways in', (tester) async {
    await tester.pumpWidget(SceneApp(signals: FakeSignals()));
    await tester.pumpAndSettle();
    expect(find.image(const AssetImage('assets/scene_logo_light.png')), findsOneWidget); // the wordmark
    expect(find.text('Taste tells us what you like.'), findsOneWidget);
    expect(find.text('Build my movie profile'), findsOneWidget);
    expect(find.text('Try the demo profile'), findsOneWidget);
  });

  testWidgets('"Try the demo profile" fills the baseline and moves on', (tester) async {
    await tester.pumpWidget(SceneApp(signals: FakeSignals()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your Movie DNA'), findsOneWidget);
  });
}
