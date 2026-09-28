import '../domain/state.dart';

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// The timing signals one Synheart typing event carries (from
/// `BehaviorEvent.metrics`). No text or content — only how the user typed.
class TypingSample {
  const TypingSample({
    required this.taps,
    required this.speed,
    required this.gapRatio,
    required this.cadenceStability,
    required this.activityRatio,
    required this.interactionIntensity,
    required this.backspaces,
    required this.durationSeconds,
  });

  /// Keystrokes in the burst.
  final int taps;

  /// Keystrokes per second.
  final double speed;

  /// Share of keystroke intervals that were long pauses (0–1).
  final double gapRatio;

  /// How even the rhythm was (0–1).
  final double cadenceStability;

  /// Share of the burst spent actively typing (0–1).
  final double activityRatio;

  /// The SDK's overall typing intensity (0–1).
  final double interactionIntensity;
  final int backspaces;
  final int durationSeconds;

  /// Reads the SDK's typing-event metrics map. Unknown or missing values
  /// become zero rather than failing the check-in.
  factory TypingSample.fromMetrics(Map<String, dynamic> m) {
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return TypingSample(
      taps: i('typing_tap_count'),
      speed: d('typing_speed'),
      gapRatio: d('typing_gap_ratio'),
      cadenceStability: d('typing_cadence_stability'),
      activityRatio: d('typing_activity_ratio'),
      interactionIntensity: d('typing_interaction_intensity'),
      backspaces: i('backspace_count') + i('number_of_delete'),
      durationSeconds: i('duration'),
    );
  }
}

/// Minimum keystrokes before Scene will read a state from typing.
const minTapsForState = 25;

/// Turns one or more typing bursts into Scene's non-clinical state.
///
/// These are **demo heuristics**, stated plainly so they can be explained:
/// * **Energy** rises with typing speed and the SDK's typing intensity.
/// * **Mental load** rises with corrections, long pauses and an uneven rhythm.
/// * **Engagement** rises with time spent actively typing and a steady rhythm.
///
/// Bursts are combined weighted by their keystrokes. Returns null when there
/// is too little typing to say anything ([minTapsForState]).
CurrentState? stateFromTyping(List<TypingSample> samples) {
  final taps = samples.fold<int>(0, (n, s) => n + s.taps);
  if (taps < minTapsForState) return null;

  double mean(double Function(TypingSample) f) => samples.fold<double>(0, (sum, s) => sum + f(s) * s.taps) / taps;

  final speed = mean((s) => s.speed); // keystrokes / s — relaxed ~2, brisk ~5+
  final intensity = mean((s) => s.interactionIntensity);
  final gaps = mean((s) => s.gapRatio);
  final stability = mean((s) => s.cadenceStability);
  final activity = mean((s) => s.activityRatio);
  final backspaces = samples.fold<int>(0, (n, s) => n + s.backspaces);
  final correction = _clamp01(backspaces / taps / 0.25); // a quarter of keystrokes deleted = max

  final energy = _clamp01(0.15 + 0.55 * _clamp01((speed - 1.5) / 4.0) + 0.3 * intensity);
  final mentalLoad = _clamp01(0.15 + 0.35 * correction + 0.3 * gaps + 0.2 * (1 - stability));
  final engagement = _clamp01(0.15 + 0.45 * activity + 0.4 * stability);

  return CurrentState(energy: energy, mentalLoad: mentalLoad, engagement: engagement, source: StateSource.synheart);
}
