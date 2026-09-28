import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scrolls the check-in's consent page to a demo-data button and taps it.
Future<void> tapDemo(WidgetTester tester, String title) async {
  final button = find.textContaining('Demo data: $title');
  await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).last);
  await tester.tap(button);
}
