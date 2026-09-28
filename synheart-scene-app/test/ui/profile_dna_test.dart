import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/synheart.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/engine/taste_builder.dart';
import 'package:scene/main.dart';
import 'package:scene/ui/dna_screen.dart';

void main() {
  testWidgets('rate films one by one, pick genres, reach Movie DNA', (tester) async {
    await tester.pumpWidget(SceneApp(synheart: SynheartService.unavailable()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build my movie profile'));
    await tester.pumpAndSettle();

    expect(find.text(onboardingFilms.first.title), findsWidgets);
    expect(find.text('1 of ${onboardingFilms.length}'), findsOneWidget);
    for (var i = 0; i < onboardingFilms.length; i++) {
      await tester.tap(find.text(i.isEven ? 'Love it' : 'Not for me'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Which genres do you usually reach for?'), findsOneWidget);
    await tester.tap(find.text('Thriller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See my Movie DNA'));
    await tester.pumpAndSettle();

    expect(find.text('Your Movie DNA'), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);
    expect(find.text('Start my Synheart check-in'), findsOneWidget);
  });

  test('DNA traits for the demo persona read like the plan', () {
    final lines = dnaTraits(buildTasteProfile(demoPersonaAnswers));
    expect(lines, contains('Darker, more intense stories'));
    expect(lines.any((l) => l.toLowerCase().contains('pacing') || l.toLowerCase().contains('fast-paced')), isTrue);
  });
}
