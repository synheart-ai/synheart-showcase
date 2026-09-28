import 'package:flutter_test/flutter_test.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/engine/state_from_typing.dart';

TypingSample sample({int taps = 60, double speed = 3, double gaps = 0.1, double stability = 0.7, double activity = 0.7, double intensity = 0.5, int backspaces = 2}) =>
    TypingSample(taps: taps, speed: speed, gapRatio: gaps, cadenceStability: stability, activityRatio: activity, interactionIntensity: intensity, backspaces: backspaces, durationSeconds: 20);

void main() {
  test('reads the SDK metrics map by its real keys', () {
    final s = TypingSample.fromMetrics({
      'typing_tap_count': 42, 'typing_speed': 3.5, 'typing_gap_ratio': 0.2,
      'typing_cadence_stability': 0.6, 'typing_activity_ratio': 0.8,
      'typing_interaction_intensity': 0.55, 'backspace_count': 4, 'number_of_delete': 1, 'duration': 12,
    });
    expect(s.taps, 42);
    expect(s.speed, 3.5);
    expect(s.backspaces, 5);
    expect(s.durationSeconds, 12);
  });

  test('missing values become zero instead of failing', () {
    final s = TypingSample.fromMetrics({'typing_tap_count': 3});
    expect(s.speed, 0);
    expect(s.gapRatio, 0);
  });

  test('too little typing says nothing', () {
    expect(stateFromTyping([sample(taps: 10)]), isNull);
    expect(stateFromTyping(const []), isNull);
  });

  test('hesitant typing with many corrections reads as high mental load → Unwind', () {
    final s = stateFromTyping([sample(speed: 2, gaps: 0.45, stability: 0.3, backspaces: 14)])!;
    expect(s.mentalLoadLevel, Level.high);
    expect(s.suggestedExperience, Experience.unwind);
    expect(s.source, StateSource.synheart);
  });

  test('brisk, steady typing reads as higher energy and lower load', () {
    final brisk = stateFromTyping([sample(speed: 6, intensity: 0.8, gaps: 0.05, stability: 0.85, backspaces: 1)])!;
    final slow = stateFromTyping([sample(speed: 1.5, intensity: 0.2, gaps: 0.4, stability: 0.4, backspaces: 10)])!;
    expect(brisk.energy, greaterThan(slow.energy));
    expect(brisk.mentalLoad, lessThan(slow.mentalLoad));
  });

  test('bursts combine weighted by keystrokes', () {
    final combined = stateFromTyping([sample(taps: 90, speed: 4), sample(taps: 10, speed: 1.5)])!;
    final briskOnly = stateFromTyping([sample(taps: 100, speed: 4)])!;
    final slowOnly = stateFromTyping([sample(taps: 100, speed: 1.5)])!;
    expect(combined.energy, lessThan(briskOnly.energy));
    expect(combined.energy, greaterThan(slowOnly.energy));
  });
}
