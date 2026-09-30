import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/signals.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/engine/recommender.dart';
import 'package:scene/engine/taste_builder.dart';

/// An HSI 1.3 snapshot shaped like the runtime's (0.32.0): scored axes in
/// several domains, a digital axis with no score, withheld axes with
/// reasons, a context guess and an embedding Scene must ignore.
String snapshot() => jsonEncode({
      'hsi_version': '1.3',
      'axes': {
        'cognitive': [
          {'name': 'focus', 'score': 0.62, 'confidence': 0.5, 'direction': 'higher_is_more'},
          {'name': 'cognitive_load', 'score': 0.4, 'confidence': 0.3, 'direction': 'lower_is_more'},
          {'name': 'mental_fatigue', 'score': null, 'confidence': 0.0},
        ],
        'affective': [
          {'name': 'valence', 'score': 0.3, 'confidence': 0.2, 'direction': 'bidirectional'},
          {'name': 'arousal', 'score': 0.5, 'confidence': 0.3},
        ],
        'digital': [
          {'name': 'focus_quality', 'score': 0.7, 'confidence': 0.6, 'direction': 'higher_is_more'},
          {'name': 'interruption_pressure', 'score': 0.2, 'confidence': 0.5, 'direction': 'lower_is_more'},
          {'name': 'interaction_mode', 'score': null, 'confidence': 0.0, 'direction': 'bidirectional'},
        ],
      },
      'embeddings': [
        {'vector': [0.1, 0.2], 'dimension': 64},
      ],
      'privacy': {'embedding_allowed': false},
      'meta': {
        'synheart': {
          'context': {'context_label': 'BR', 'context_confidence': 0.83, 'foreground_app_category': 'COMM'},
          'diagnostics': {
            'notes': {'interaction_mode': 'no interaction signal in window'},
          },
          'state_withheld': {'capacity': 'no_signal', 'mental_fatigue': 'no_contributing_modality', 'stress': 'no_contributing_modality'},
        },
      },
    });

void main() {
  group('reading every HSI value from a snapshot', () {
    final s = SynheartSignals.fromHsiJson(snapshot(), basis: {Modality.physiological, Modality.digital});

    test('scored axes in every domain', () {
      expect(s.focus, const AxisReading(0.62, 0.5));
      expect(s.cognitiveLoad, const AxisReading(0.4, 0.3));
      expect(s.directionOf(HsiAxis.cognitiveLoad), HsiDirection.lowerIsMore, reason: 'as runtime 0.32.0 labels it');
      expect(s.plain(PlainSignal.mentalLoad), closeTo(0.6, 1e-9), reason: 'lower-is-more 0.4 is 0.6 load');
      expect(s.valence, const AxisReading(0.3, 0.2));
      expect(s.focusQuality, const AxisReading(0.7, 0.6));
      expect(s.interruptionPressure, const AxisReading(0.2, 0.5));
    });

    test('a null score is "could not compute", never zero', () {
      expect(s.mentalFatigue, isNull);
      expect(s.interactionMode, isNull);
    });

    test('reasons come from state_withheld, then the digital notes', () {
      expect(s.whyUnavailable(HsiAxis.capacity), 'no heart-rate signal');
      expect(s.whyUnavailable(HsiAxis.mentalFatigue), 'no input for it yet');
      expect(s.whyUnavailable(HsiAxis.interactionMode), 'no taps or scrolls in the last minute');
    });

    test('context guess and basis are kept; the context is not stored', () {
      expect(s.contextLabel, 'BR');
      expect(s.appCategory, 'COMM');
      expect(s.basisLabel, 'heart rate and phone use');
      final stored = CurrentState.fromJson(s.toJson());
      expect(stored.contextLabel, isNull);
      expect(stored.cognitiveLoad, s.cognitiveLoad);
      expect(stored.withheld, s.withheld);
      expect(stored.basis, s.basis);
    });

    test('typed values fill in only what the JSON lacks', () {
      final legacy = SynheartSignals.fromHsiJson('{}', typed: {HsiAxis.sleep: const AxisReading(0.8, 0.4)});
      expect(legacy.sleep, const AxisReading(0.8, 0.4));
      final both = SynheartSignals.fromHsiJson(snapshot(), typed: {HsiAxis.focus: const AxisReading(0.1, 0.9)});
      expect(both.focus, const AxisReading(0.62, 0.5));
    });
  });

  group('directions follow the snapshot', () {
    test('lower_is_more from the snapshot inverts; higher_is_more does not', () {
      String snap(String dir) => jsonEncode({
            'axes': {
              'digital': [
                {'name': 'interruption_pressure', 'score': 0.2, 'confidence': 0.5, 'direction': dir},
              ],
            },
          });
      final lower = SynheartSignals.fromHsiJson(snap('lower_is_more'));
      final higher = SynheartSignals.fromHsiJson(snap('higher_is_more'));
      final both = SynheartSignals.fromHsiJson(snap('bidirectional'));
      expect(lower.plain(PlainSignal.interruptions), closeTo(0.8, 1e-9));
      expect(higher.plain(PlainSignal.interruptions), closeTo(0.2, 1e-9));
      expect(both.plain(PlainSignal.interruptions), isNull);
      expect(CurrentState.fromJson(higher.toJson()).directionOf(HsiAxis.interruptionPressure), HsiDirection.higherIsMore);
    });

    test('the log marks each axis\'s direction', () {
      final line = SynheartSignals.describeHsi(snapshot());
      expect(line, contains('interruption_pressure=0.20@0.50↓'));
      expect(line, contains('valence=0.30@0.20↔'));
      expect(line, contains('focus=0.62@0.50 '));
    });
  });

    group('a lower-is-more 0.00 at low confidence is a floor, not a maximum', () {
    test('seen on device: not available, "too early to tell"', () {
      const s = CurrentState(
          interruptionPressure: AxisReading(0.0, 0.25), cognitiveLoad: AxisReading(0.0, 0.08), source: StateSource.synheart);
      expect(s.plain(PlainSignal.interruptions), isNull);
      expect(s.plain(PlainSignal.mentalLoad), isNull);
      expect(s.whyUnavailableSignal(PlainSignal.interruptions), 'too early to tell');
      expect(s.suggestedExperience, isNull, reason: 'no false "Unwind"');
    });

    test('a confident 0.00, or a small non-zero score, still counts', () {
      const confident = CurrentState(interruptionPressure: AxisReading(0.0, 0.9), source: StateSource.synheart);
      const small = CurrentState(interruptionPressure: AxisReading(0.05, 0.25), source: StateSource.synheart);
      expect(confident.plain(PlainSignal.interruptions), 1.0);
      expect(small.plain(PlainSignal.interruptions), closeTo(0.95, 1e-9));
    });
  });

  group('plain signals from the behavior axes', () {
    test('interruptions invert interruption pressure (lower is more)', () {
      const s = CurrentState(interruptionPressure: AxisReading(0.2, 0.5), source: StateSource.synheart);
      expect(s.plain(PlainSignal.interruptions), closeTo(0.8, 1e-9));
      expect(s.levelOf(PlainSignal.interruptions), SignalLevel.high);
    });

    test('engagement is the mean of focus and focus quality', () {
      const s = CurrentState(focus: AxisReading(0.4, 0.5), focusQuality: AxisReading(0.8, 0.5), source: StateSource.synheart);
      expect(s.plain(PlainSignal.engagement), closeTo(0.6, 1e-9));
    });

    test('tiredness is the higher of mental fatigue and poor sleep', () {
      const s = CurrentState(mentalFatigue: AxisReading(0.3, 0.5), sleep: AxisReading(0.2, 0.5), source: StateSource.synheart);
      expect(s.plain(PlainSignal.tiredness), closeTo(0.8, 1e-9));
    });

    test('mood never reads "Low"', () {
      const s = CurrentState(valence: AxisReading(0.1, 0.5), source: StateSource.synheart);
      expect(PlainSignal.mood.levelLabel(s.levelOf(PlainSignal.mood)!), 'Lower');
    });

    test('mental load includes cognitive load, which is lower-is-more', () {
      const s = CurrentState(stress: AxisReading(0.2, 0.5), cognitiveLoad: AxisReading(0.25, 0.5), source: StateSource.synheart);
      expect(s.plain(PlainSignal.mentalLoad), 0.75);
    });

    test('a bidirectional axis other than valence gives no amount', () {
      const s = CurrentState(
          arousal: AxisReading(0.9, 0.5), directions: {HsiAxis.arousal: HsiDirection.bidirectional}, source: StateSource.synheart);
      expect(s.plain(PlainSignal.energy), isNull);
      expect(s.suggestedExperience, isNull);
    });
  });

  group('policy with the behavior axes', () {
    test('high cognitive load (a low score) suggests unwinding', () {
      const s = CurrentState(cognitiveLoad: AxisReading(0.25, 0.5), source: StateSource.synheart);
      expect(s.suggestedExperience, Experience.unwind);
    });

    test('tiredness or heavy interruptions suggest an easy watch', () {
      const tired = CurrentState(mentalFatigue: AxisReading(0.8, 0.5), source: StateSource.synheart);
      const interrupted = CurrentState(interruptionPressure: AxisReading(0.1, 0.5), source: StateSource.synheart);
      expect(tired.suggestedExperience, Experience.easyWatch);
      expect(interrupted.suggestedExperience, Experience.easyWatch);
    });

    test('focus quality lifts engagement to "stay engaged"', () {
      const s = CurrentState(focus: AxisReading(0.55, 0.5), focusQuality: AxisReading(0.8, 0.5), source: StateSource.synheart);
      expect(s.suggestedExperience, Experience.stayEngaged);
    });
  });

  group('ranking', () {
    final persona = buildTasteProfile(demoPersonaAnswers);
    const engine = Recommender();
    List<String> top(CurrentState s) => [for (final r in engine.recommend(persona, state: s).take(5)) r.film.id];

    test('interaction mode never changes the ranking (direction undocumented)', () {
      const base = CurrentState(focus: AxisReading(0.5, 0.5), stress: AxisReading(0.4, 0.5), source: StateSource.synheart);
      const withMode = CurrentState(
          focus: AxisReading(0.5, 0.5), stress: AxisReading(0.4, 0.5), interactionMode: AxisReading(0.95, 0.9), source: StateSource.synheart);
      expect(top(withMode), top(base));
    });

    test('behavior axes count less than the core axes', () {
      final core = StateTargets.from(const CurrentState(stress: AxisReading(0.8, 0.5), source: StateSource.synheart));
      final behavior = StateTargets.from(const CurrentState(cognitiveLoad: AxisReading(0.2, 0.5), source: StateSource.synheart));
      expect(behavior.strain, lessThan(core.strain!));
      expect(behavior.strain, closeTo(secondaryWeight * 0.8, 1e-9));
    });

    test('a lower mood alone prefers a lighter tone', () {
      final t = StateTargets.from(const CurrentState(valence: AxisReading(0.2, 0.5), source: StateSource.synheart));
      expect(t.prefersLightTone, isTrue);
    });
  });
}
