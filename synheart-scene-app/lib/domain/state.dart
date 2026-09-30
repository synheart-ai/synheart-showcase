import 'package:equatable/equatable.dart';

/// One HSI axis reading: a 0–1 value and the runtime's confidence in it.
/// Mirrors `HSIAxisValue` from synheart_core, so the domain and its tests do
/// not depend on the SDK.
class AxisReading extends Equatable {
  const AxisReading(this.value, this.confidence);

  final double value;
  final double confidence;

  /// A reading is available when its confidence is **above** this;
  /// otherwise it is *unavailable* — never a negative result.
  ///
  /// TEMPORARY (2026-09-29, product decision): any confidence above 0 counts,
  /// so heart-rate-only sources such as the Galaxy Watch (confidences
  /// 0.01–0.17 on device, below the HR-only ceilings in the research
  /// ruling) still produce a reading. Resona's gate, and Scene's before
  /// this, is 0.45 — see [resonaMinConfidence]. Revisit before a real demo.
  static const minConfidence = 0.0;

  /// The gate Resona uses; the value to return to.
  static const resonaMinConfidence = 0.45;

  bool get isAvailable => confidence > minConfidence;

  /// Used (above the temporary gate) but below Resona's 0.45: shown with a
  /// "low confidence" marker so a thin reading never looks certain (RFC §8,
  /// §9.4). A heart-rate-only watch gives 0.01–0.17.
  bool get isLowConfidence => isAvailable && confidence < resonaMinConfidence;

  @override
  List<Object?> get props => [value, confidence];
}

/// How an axis's score reads (HSI 1.3 `direction`).
enum HsiDirection {
  /// A higher score means more of the thing named.
  higherIsMore,

  /// A lower score means more: `interruption_pressure`.
  lowerIsMore,

  /// Neither end is better, and the runtime does not document which end is
  /// which: `interaction_mode`. Shown, never ranked on.
  bidirectional;

  /// The snapshot's `direction` string, or null when absent or unknown.
  static HsiDirection? fromWire(Object? s) => switch (s) {
        'higher_is_more' => higherIsMore,
        'lower_is_more' => lowerIsMore,
        'bidirectional' => bidirectional,
        _ => null,
      };
}

/// Every HSI axis Scene reads (HSI 1.3; runtime 0.32.0). The first four are
/// the core, physiology-led axes; the rest arrived with behavior collection
/// (2026-09-30) and count with a smaller weight — see `secondaryWeight` in
/// the recommender.
enum HsiAxis {
  focus('Focus', 'focus'),
  stress('Stress', 'stress'),
  arousal('Arousal', 'arousal'),
  capacity('Capacity', 'capacity'),
  cognitiveLoad('Cognitive load', 'cognitive_load'),
  mentalFatigue('Mental fatigue', 'mental_fatigue'),
  valence('Valence', 'valence'),
  sleep('Sleep', 'sleep_score'),
  focusQuality('Focus quality', 'focus_quality'),
  interruptionPressure('Interruption pressure', 'interruption_pressure', HsiDirection.lowerIsMore),
  interactionMode('Interaction mode', 'interaction_mode', HsiDirection.bidirectional);

  const HsiAxis(this.label, this.wireName, [this.direction = HsiDirection.higherIsMore]);
  final String label;

  /// The name in the HSI snapshot (`axes.<domain>[].name`, `state_withheld`).
  final String wireName;
  final HsiDirection direction;

  /// Added with behavior collection; weighted less than the core four.
  bool get isSecondary => index >= HsiAxis.cognitiveLoad.index;

  static HsiAxis? fromWire(String name) {
    for (final a in values) {
      if (a.wireName == name || (a == sleep && name == 'sleep')) return a;
    }
    return null;
  }
}

/// Why the runtime left an axis out (`meta.synheart.state_withheld`, and
/// the notes on digital axes with no score), in plain words. Unknown codes
/// are shown as they are, never guessed at.
String withheldReason(String code) {
  final c = code.toLowerCase();
  if (c.contains('no_signal')) return 'no heart-rate signal';
  if (c.contains('no_contributing_modality')) return 'no input for it yet';
  if (c.contains('episodic_sensing')) return 'needs continuous sensing';
  if (c.contains('cold_start')) return 'still learning your baseline';
  if (c.contains('low_directional_evidence')) return 'not enough evidence yet';
  if (c.contains('insufficient foreground activity')) return 'not enough phone use in the last minute';
  if (c.contains('no interaction signal')) return 'no taps or scrolls in the last minute';
  if (c.contains('no notifications')) return 'no notifications or app use in the last minute';
  if (c == 'none') return 'not produced';
  return code;
}

/// What a reading was built from (HSI `modalities`).
enum Modality {
  physiological('heart rate'),
  kinematic('motion'),
  digital('phone use');

  const Modality(this.label);
  final String label;
}

/// What kind of evening the current state may suit. Scene's demo policy,
/// modelled on Resona's flow / clarity / ease, with the same thresholds.
/// These are demo choices, not health interpretations.
enum Experience {
  /// Elevated stress or arousal, or reduced capacity (Resona's "ease").
  unwind('Unwind', 'a good evening to unwind', 'Your rhythm has picked up', 'Something lighter may help you settle.'),

  /// Focus appears to drift (Resona's "clarity").
  easyWatch('Easy watch', 'a good evening for an easy watch', 'Your focus seems to be drifting', 'A film that is easy to follow may suit tonight.'),

  /// Focus evidence is strong (Resona's "flow").
  stayEngaged(
      'Stay engaged', 'a good evening for something engaging', 'You seem settled and focused', 'A film that asks a little more of you may suit tonight.');

  const Experience(this.label, this.phrase, this.headline, this.message);
  final String label;

  /// Tentative phrase for sentences — "This may be a good evening to unwind",
  /// never "You are stressed" (RFC §8).
  final String phrase;

  /// Neutral-language headline and message for the state sheet.
  final String headline;
  final String message;

  /// The viewing intent this suggests, which the user can accept, change or
  /// skip (RFC §4.5).
  EveningIntent get suggestedIntent => switch (this) {
        Experience.unwind => EveningIntent.unwind,
        Experience.easyWatch => EveningIntent.entertain,
        Experience.stayEngaged => EveningIntent.engaging,
      };
}

/// The plan's plain-language signals (plan §1, §4: "energy, engagement and
/// mental load"), plus three from the behavior axes (2026-09-30), shown
/// instead of raw HSI axis names so nothing reads like a diagnosis.
/// **Provisional mapping** — RFC §6 requires Research to approve it:
/// * Energy ← arousal
/// * Mental load ← the highest of stress, reduced capacity (1 − capacity)
///   and cognitive load
/// * Engagement ← the mean of focus and focus quality
/// * Tiredness ← the higher of mental fatigue and poor sleep (1 − sleep)
/// * Interruptions ← 1 − interruption pressure (its score is lower-is-more)
/// * Mood ← valence
/// Each is derived only from axes that pass the confidence gate.
/// Interaction mode is not mapped: its direction is undocumented.
enum PlainSignal {
  energy('Energy'),
  mentalLoad('Mental load'),
  engagement('Engagement'),
  tiredness('Tiredness'),
  interruptions('Interruptions'),
  mood('Mood');

  const PlainSignal(this.label);
  final String label;

  /// The HSI axes this signal is read from.
  List<HsiAxis> get sources => switch (this) {
        PlainSignal.energy => const [HsiAxis.arousal],
        PlainSignal.mentalLoad => const [HsiAxis.stress, HsiAxis.capacity, HsiAxis.cognitiveLoad],
        PlainSignal.engagement => const [HsiAxis.focus, HsiAxis.focusQuality],
        PlainSignal.tiredness => const [HsiAxis.mentalFatigue, HsiAxis.sleep],
        PlainSignal.interruptions => const [HsiAxis.interruptionPressure],
        PlainSignal.mood => const [HsiAxis.valence],
      };

  /// The level in words. Mood avoids "Low", which reads like a diagnosis.
  String levelLabel(SignalLevel l) => this == PlainSignal.mood
      ? switch (l) {
          SignalLevel.low => 'Lower',
          SignalLevel.moderate => 'Steady',
          SignalLevel.high => 'Brighter',
        }
      : l.label;
}

/// Low / Moderate / High, as on the plan's example state card.
enum SignalLevel {
  low('Low'),
  moderate('Moderate'),
  high('High');

  const SignalLevel(this.label);
  final String label;

  static SignalLevel of(double v) => v < 0.36 ? low : (v < 0.66 ? moderate : high);
}

/// Where the state came from — shown so the demo stays honest.
enum StateSource {
  synheart('From your wearable, via Synheart'),
  wearSim('From a WearSim demo source'),
  preset('Demo data — not a real reading');

  const StateSource(this.label);
  final String label;
}

/// The user's current state as HSI axes. This is an input to
/// personalisation — never a diagnosis. Axes the runtime could not resolve
/// with enough confidence are treated as unavailable (RFC §6: use only fields
/// the SDK actually provides, with their quality).
class CurrentState extends Equatable {
  const CurrentState({
    this.focus,
    this.stress,
    this.arousal,
    this.capacity,
    this.cognitiveLoad,
    this.mentalFatigue,
    this.valence,
    this.sleep,
    this.focusQuality,
    this.interruptionPressure,
    this.interactionMode,
    required this.source,
    this.capturedAt,
    this.withheld = const {},
    this.basis = const {},
    this.directions = const {},
    this.contextLabel,
    this.appCategory,
  });

  final AxisReading? focus;
  final AxisReading? stress;
  final AxisReading? arousal;
  final AxisReading? capacity;
  final AxisReading? cognitiveLoad;
  final AxisReading? mentalFatigue;
  final AxisReading? valence;
  final AxisReading? sleep;
  final AxisReading? focusQuality;
  final AxisReading? interruptionPressure;
  final AxisReading? interactionMode;
  final StateSource source;

  /// Axes the runtime left out, with its reason code.
  final Map<HsiAxis, String> withheld;

  /// What the reading was built from.
  final Set<Modality> basis;

  /// Each axis's direction as the snapshot states it (HSI 1.3
  /// `direction`); the enum's documented default when the snapshot is
  /// silent. Scene follows the runtime's own label rather than a hard-coded
  /// one.
  final Map<HsiAxis, HsiDirection> directions;

  HsiDirection directionOf(HsiAxis a) => directions[a] ?? a.direction;

  /// The runtime's guess at the current activity (`meta.synheart.context`),
  /// shown only under Details and never ranked on: it describes app use.
  final String? contextLabel;
  final String? appCategory;

  /// How long a reading stays usable once the signal stops. A tunable
  /// default: the RFC leaves the freshness rule open (§13).
  static const freshFor = Duration(minutes: 30);

  /// When the snapshot was taken; null for a preset not yet applied.
  final DateTime? capturedAt;

  bool isStaleAt(DateTime now) => capturedAt != null && now.difference(capturedAt!) > freshFor;

  AxisReading? reading(HsiAxis a) => switch (a) {
        HsiAxis.focus => focus,
        HsiAxis.stress => stress,
        HsiAxis.arousal => arousal,
        HsiAxis.capacity => capacity,
        HsiAxis.cognitiveLoad => cognitiveLoad,
        HsiAxis.mentalFatigue => mentalFatigue,
        HsiAxis.valence => valence,
        HsiAxis.sleep => sleep,
        HsiAxis.focusQuality => focusQuality,
        HsiAxis.interruptionPressure => interruptionPressure,
        HsiAxis.interactionMode => interactionMode,
      };

  /// Why an axis is not available, in plain words, or null when it is.
  String? whyUnavailable(HsiAxis a) {
    if (valueOf(a) != null) return null;
    final code = withheld[a];
    if (code != null) return withheldReason(code);
    final r = reading(a);
    return r != null ? 'Synheart is not confident enough yet' : null;
  }

  /// Why a plain signal is not available: the first reason its axes give.
  String? whyUnavailableSignal(PlainSignal p) {
    if (plain(p) != null) return null;
    for (final a in p.sources) {
      final why = whyUnavailable(a);
      if (why != null) return why;
    }
    return null;
  }

  /// "Based on heart rate and phone use", or null when unknown.
  String? get basisLabel {
    final parts = [for (final m in Modality.values) if (basis.contains(m)) m.label];
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.single : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }

  /// The value of an axis, or null when it is missing or below the
  /// confidence threshold.
  double? valueOf(HsiAxis a) {
    final r = reading(a);
    return r != null && r.isAvailable ? r.value : null;
  }

  List<HsiAxis> get availableAxes => [for (final a in HsiAxis.values) if (valueOf(a) != null) a];

  /// A plain signal's 0–1 value, or null when its axes are unavailable.
  double? plain(PlainSignal p) {
    double? highest(List<double?> xs) {
      final v = xs.whereType<double>().toList();
      return v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
    }

    double? inverted(HsiAxis a) {
      final v = valueOf(a);
      return v == null ? null : 1 - v;
    }

    return switch (p) {
      PlainSignal.energy => valueOf(HsiAxis.arousal),
      PlainSignal.mentalLoad => highest([valueOf(HsiAxis.stress), inverted(HsiAxis.capacity), valueOf(HsiAxis.cognitiveLoad)]),
      PlainSignal.engagement => () {
          final v = [valueOf(HsiAxis.focus), valueOf(HsiAxis.focusQuality)].whereType<double>().toList();
          return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
        }(),
      PlainSignal.tiredness => highest([valueOf(HsiAxis.mentalFatigue), inverted(HsiAxis.sleep)]),
      PlainSignal.interruptions => switch (directionOf(HsiAxis.interruptionPressure)) {
          HsiDirection.lowerIsMore => inverted(HsiAxis.interruptionPressure),
          HsiDirection.higherIsMore => valueOf(HsiAxis.interruptionPressure),
          // Which end is "more" is not stated: not shown as a level.
          HsiDirection.bidirectional => null,
        },
      PlainSignal.mood => valueOf(HsiAxis.valence),
    };
  }

  SignalLevel? levelOf(PlainSignal p) {
    final v = plain(p);
    return v == null ? null : SignalLevel.of(v);
  }

  /// Whether any axis behind this plain signal is a low-confidence reading.
  bool isLowConfidenceSignal(PlainSignal p) => p.sources.any((a) => reading(a)?.isLowConfidence ?? false);

  /// Whether any axis in use is a low-confidence reading — then every
  /// state-based label and suggestion is marked as such.
  bool get isLowConfidence => availableAxes.any((a) => reading(a)!.isLowConfidence);

  /// At least one axis is usable. Without that, Scene says there is not
  /// enough evidence and ranks on taste only.
  bool get hasEvidence => availableAxes.isNotEmpty;

  /// Resona's policy, adapted: ease first, then clarity, then flow. Null
  /// means no clear need — a real result, not a failure. The behavior axes
  /// join with stricter thresholds (demo choices, 2026-09-30): high
  /// cognitive load reads like stress; tiredness or heavy interruptions
  /// suggest an easy watch; engagement (focus with focus quality) replaces
  /// focus alone.
  Experience? get suggestedExperience {
    final stress = valueOf(HsiAxis.stress);
    final arousal = valueOf(HsiAxis.arousal);
    final capacity = valueOf(HsiAxis.capacity);
    final load = valueOf(HsiAxis.cognitiveLoad);
    final engagement = plain(PlainSignal.engagement);
    final tiredness = plain(PlainSignal.tiredness);
    final interruptions = plain(PlainSignal.interruptions);
    if ((stress != null && stress >= .62) ||
        (arousal != null && arousal >= .76) ||
        (capacity != null && capacity <= .35) ||
        (load != null && load >= .70)) {
      return Experience.unwind;
    }
    if ((engagement != null && engagement <= .44) ||
        (tiredness != null && tiredness >= .70) ||
        (interruptions != null && interruptions >= .70)) {
      return Experience.easyWatch;
    }
    if (engagement != null && engagement >= .60) return Experience.stayEngaged;
    return null;
  }

  CurrentState copyWith({StateSource? source, DateTime? capturedAt}) => CurrentState(
        focus: focus,
        stress: stress,
        arousal: arousal,
        capacity: capacity,
        cognitiveLoad: cognitiveLoad,
        mentalFatigue: mentalFatigue,
        valence: valence,
        sleep: sleep,
        focusQuality: focusQuality,
        interruptionPressure: interruptionPressure,
        interactionMode: interactionMode,
        source: source ?? this.source,
        capturedAt: capturedAt ?? this.capturedAt,
        withheld: withheld,
        basis: basis,
        directions: directions,
        contextLabel: contextLabel,
        appCategory: appCategory,
      );

  /// The stored snapshot: derived values only. The activity guess is not
  /// kept.
  Map<String, Object?> toJson() => {
        for (final a in HsiAxis.values)
          if (reading(a) != null) a.name: [reading(a)!.value, reading(a)!.confidence],
        'source': source.name,
        if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
        if (withheld.isNotEmpty) 'withheld': {for (final e in withheld.entries) e.key.name: e.value},
        if (basis.isNotEmpty) 'basis': [for (final m in basis) m.name],
        if (directions.isNotEmpty) 'directions': {for (final e in directions.entries) e.key.name: e.value.name},
      };

  static CurrentState fromJson(Map<String, dynamic> m) {
    AxisReading? r(HsiAxis a) {
      final v = m[a.name];
      return v is List && v.length == 2 ? AxisReading((v[0] as num).toDouble(), (v[1] as num).toDouble()) : null;
    }

    final at = m['capturedAt'] as String?;
    final w = m['withheld'];
    final b = m['basis'];
    final d = m['directions'];
    return CurrentState(
      focus: r(HsiAxis.focus),
      stress: r(HsiAxis.stress),
      arousal: r(HsiAxis.arousal),
      capacity: r(HsiAxis.capacity),
      cognitiveLoad: r(HsiAxis.cognitiveLoad),
      mentalFatigue: r(HsiAxis.mentalFatigue),
      valence: r(HsiAxis.valence),
      sleep: r(HsiAxis.sleep),
      focusQuality: r(HsiAxis.focusQuality),
      interruptionPressure: r(HsiAxis.interruptionPressure),
      interactionMode: r(HsiAxis.interactionMode),
      source: StateSource.values.byName(m['source'] as String),
      capturedAt: at == null ? null : DateTime.parse(at),
      withheld: w is Map
          ? {
              for (final e in w.entries)
                if (HsiAxis.values.asNameMap()[e.key] != null) HsiAxis.values.asNameMap()[e.key]!: '${e.value}',
            }
          : const {},
      basis: b is List ? {for (final n in b) ?Modality.values.asNameMap()[n]} : const {},
      directions: d is Map
          ? {
              for (final e in d.entries)
                if (HsiAxis.values.asNameMap()[e.key] != null && HsiDirection.values.asNameMap()[e.value] != null)
                  HsiAxis.values.asNameMap()[e.key]!: HsiDirection.values.asNameMap()[e.value]!,
            }
          : const {},
    );
  }

  @override
  List<Object?> get props => [
        for (final a in HsiAxis.values) reading(a),
        source,
        capturedAt,
        withheld,
        basis,
        directions,
        contextLabel,
        appCategory,
      ];
}

/// "Choose My Evening" — explicit user intent, which always wins over the
/// inferred state when the two disagree.
enum EveningIntent {
  entertain('Just entertain me'),
  engaging('Give me something engaging'),
  unwind('Help me unwind');

  const EveningIntent(this.label);
  final String label;
}

/// Everything about tonight that is not taste and not state.
class ViewingContext extends Equatable {
  const ViewingContext({this.intent, this.maxRuntimeMinutes});

  final EveningIntent? intent;

  /// When set, films longer than this are left out ("90 minutes or less").
  final int? maxRuntimeMinutes;

  ViewingContext copyWith({EveningIntent? intent, bool clearIntent = false, int? maxRuntimeMinutes, bool clearRuntime = false}) =>
      ViewingContext(
        intent: clearIntent ? null : (intent ?? this.intent),
        maxRuntimeMinutes: clearRuntime ? null : (maxRuntimeMinutes ?? this.maxRuntimeMinutes),
      );

  @override
  List<Object?> get props => [intent, maxRuntimeMinutes];
}
