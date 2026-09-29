import 'package:flutter/foundation.dart';

import '../domain/state.dart';

/// What happened during one check-in, so a "Not enough signal" result can be
/// explained: did heart rate arrive, did Synheart produce readings, and how
/// close were they to the confidence gate?
///
/// Counts and confidences only — no heart-rate values are kept (the privacy
/// table in the README). In debug builds each step is printed with the
/// `[scene-signal]` prefix.
class CheckInDiagnostics {
  CheckInDiagnostics(this.source, this.startedAt);

  final String source;
  final DateTime startedAt;

  int heartRateSamples = 0;
  DateTime? firstSampleAt;
  DateTime? lastSampleAt;
  int readings = 0;

  /// The highest confidence each axis reached, whether or not it passed.
  final best = <HsiAxis, double>{};

  void onHeartRate(DateTime at) {
    heartRateSamples++;
    firstSampleAt ??= at;
    lastSampleAt = at;
  }

  void onReading(CurrentState r) {
    readings++;
    for (final a in HsiAxis.values) {
      final c = r.reading(a)?.confidence;
      if (c != null && c > (best[a] ?? -1)) best[a] = c;
    }
  }

  /// The best axis so far, or null before any reading carried an axis.
  MapEntry<HsiAxis, double>? get strongest =>
      best.entries.isEmpty ? null : best.entries.reduce((a, b) => a.value >= b.value ? a : b);

  /// The likeliest reason, in plain words, for a check-in that ended without
  /// a confident reading.
  String get diagnosis {
    if (heartRateSamples == 0) {
      return 'No heart rate arrived from $source during the check-in. Check that it is streaming in Settings.';
    }
    if (readings == 0) {
      return '$heartRateSamples heart-rate samples arrived, but Synheart produced no reading in that time. '
          'It may need more data than this source sends.';
    }
    final s = strongest;
    if (s == null) {
      return 'Synheart produced $readings readings, but none carried a Focus, Stress, Arousal or Capacity value.';
    }
    return 'Synheart produced $readings readings. The most confident was ${s.key.label} at '
        '${s.value.toStringAsFixed(2)}; Scene needs more than ${AxisReading.minConfidence.toStringAsFixed(2)}.';
  }

  /// One line per fact, for the Details section and the log.
  List<String> summary(DateTime now) => [
        'Source: $source',
        'Heart-rate samples: $heartRateSamples'
            '${lastSampleAt == null ? '' : ' (last ${now.difference(lastSampleAt!).inSeconds} s ago)'}',
        'Synheart readings: $readings',
        if (best.isNotEmpty)
          'Best confidence: ${[for (final e in best.entries) '${e.key.label} ${e.value.toStringAsFixed(2)}'].join(', ')}',
        'Needed: more than ${AxisReading.minConfidence.toStringAsFixed(2)} on at least one axis',
      ];

  static String describeReading(CurrentState r) => [
        for (final a in HsiAxis.values)
          if (r.reading(a) case final v?)
            '${a.name} ${v.value.toStringAsFixed(2)}@${v.confidence.toStringAsFixed(2)}${v.isAvailable ? '✓' : ''}',
      ].join(' ');

  static void log(String message) {
    if (kDebugMode) debugPrint('[scene-signal] $message');
  }
}
