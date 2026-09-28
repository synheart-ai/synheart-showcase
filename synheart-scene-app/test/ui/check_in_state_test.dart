import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/synheart.dart';
import 'package:scene/main.dart';

void main() {
  Future<void> toCheckIn(WidgetTester tester) async {
    await tester.pumpWidget(SceneApp(synheart: SynheartService.unavailable()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start my Synheart check-in'));
    await tester.pumpAndSettle();
  }

  testWidgets('without the SDK the check-in offers the manual paths', (tester) async {
    await toCheckIn(tester);
    expect(find.text('How has today been?'), findsOneWidget);
    expect(find.text('Synheart is not available on this device'), findsOneWidget);
    expect(find.text('Read my current state'), findsNothing);
    expect(find.text('Use demo scenario'), findsOneWidget);
  });

  testWidgets('the demo scenario shows the plan\'s example card and can be adjusted', (tester) async {
    await toCheckIn(tester);
    await tester.tap(find.text('Use demo scenario'));
    await tester.pumpAndSettle();

    expect(find.text('DEMO PRESET'), findsOneWidget);
    expect(find.text('You seem to be looking to unwind.'), findsOneWidget);
    expect(find.text('Unwind'), findsOneWidget);

    // Lower the mental load: the suggestion changes and the source says "adjusted".
    await tester.tap(find.text('Low').at(1));
    await tester.pumpAndSettle();
    expect(find.text('ADJUSTED BY YOU'), findsOneWidget);
    expect(find.text('Unwind'), findsNothing);
  });
}
