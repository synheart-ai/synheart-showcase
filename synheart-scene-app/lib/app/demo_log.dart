import 'package:flutter/foundation.dart';

/// The events RFC §10 asks to instrument.
enum DemoEvent {
  onboardingCompleted,
  checkInConsented,
  checkInSkipped,
  checkInSucceeded,
  checkInInsufficientSignal,
  checkInFailed,
  demoScenarioUsed,
  recommendationsViewed,
  comparisonToggled,
  comparisonViewed,
  explanationViewed,
  intentChanged,
  filmSelected,
  feedbackGiven,
  demoReset,
}

/// A local, in-memory log of demo events for rehearsal review.
///
/// Fields carry only enum names, counts and catalogue film ids — never typed
/// text, typing metrics or anything else from the check-in (RFC §10). Nothing
/// is stored or sent; in debug builds each event is printed with the
/// `[scene-event]` prefix so it shows in `flutter run` / device logs.
class DemoLog {
  DemoLog({DateTime Function()? clock, this.capacity = 500}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final int capacity;
  final _entries = <DemoLogEntry>[];

  List<DemoLogEntry> get entries => List.unmodifiable(_entries);

  void record(DemoEvent event, [Map<String, String> fields = const {}]) {
    final e = DemoLogEntry(_clock(), event, fields);
    _entries.add(e);
    if (_entries.length > capacity) _entries.removeAt(0);
    if (kDebugMode) debugPrint('[scene-event] $e');
  }
}

class DemoLogEntry {
  const DemoLogEntry(this.at, this.event, this.fields);
  final DateTime at;
  final DemoEvent event;
  final Map<String, String> fields;

  @override
  String toString() => '${at.toIso8601String()} ${event.name}${fields.isEmpty ? '' : ' $fields'}';
}
