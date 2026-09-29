import 'package:equatable/equatable.dart';

/// One HSI axis reading: a 0–1 value and the runtime's confidence in it.
/// Mirrors `HSIAxisValue` from synheart_core, so the domain and its tests do
/// not depend on the SDK.
class AxisReading extends Equatable {
  const AxisReading(this.value, this.confidence);

  final double value;
  final double confidence;

  /// Below this, a reading is *unavailable* — never a negative result.
  /// The same threshold Resona uses.
  static const minConfidence = 0.45;

  bool get isAvailable => confidence >= minConfidence;

  @override
  List<Object?> get props => [value, confidence];
}

/// The HSI axes Scene reads.
enum HsiAxis {
  focus('Focus'),
  stress('Stress'),
  arousal('Arousal'),
  capacity('Capacity');

  const HsiAxis(this.label);
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
/// mental load"), shown instead of raw HSI axis names so nothing reads like a
/// diagnosis. **Provisional mapping** — RFC §6 requires Research to approve it:
/// * Energy ← arousal
/// * Mental load ← the higher of stress and reduced capacity (1 − capacity)
/// * Engagement ← focus
/// Each is derived only from axes that pass the confidence gate.
enum PlainSignal {
  energy('Energy'),
  mentalLoad('Mental load'),
  engagement('Engagement');

  const PlainSignal(this.label);
  final String label;

  /// The HSI axes this signal is read from.
  List<HsiAxis> get sources => switch (this) {
        PlainSignal.energy => const [HsiAxis.arousal],
        PlainSignal.mentalLoad => const [HsiAxis.stress, HsiAxis.capacity],
        PlainSignal.engagement => const [HsiAxis.focus],
      };
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
    required this.source,
    this.capturedAt,
  });

  final AxisReading? focus;
  final AxisReading? stress;
  final AxisReading? arousal;
  final AxisReading? capacity;
  final StateSource source;

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
      };

  /// The value of an axis, or null when it is missing or below the
  /// confidence threshold.
  double? valueOf(HsiAxis a) {
    final r = reading(a);
    return r != null && r.isAvailable ? r.value : null;
  }

  List<HsiAxis> get availableAxes => [for (final a in HsiAxis.values) if (valueOf(a) != null) a];

  /// A plain signal's 0–1 value, or null when its axes are unavailable.
  double? plain(PlainSignal p) => switch (p) {
        PlainSignal.energy => valueOf(HsiAxis.arousal),
        PlainSignal.engagement => valueOf(HsiAxis.focus),
        PlainSignal.mentalLoad => () {
            final stress = valueOf(HsiAxis.stress);
            final capacity = valueOf(HsiAxis.capacity);
            final signs = [?stress, if (capacity != null) 1 - capacity];
            return signs.isEmpty ? null : signs.reduce((a, b) => a > b ? a : b);
          }(),
      };

  SignalLevel? levelOf(PlainSignal p) {
    final v = plain(p);
    return v == null ? null : SignalLevel.of(v);
  }

  /// At least one axis is usable. Without that, Scene says there is not
  /// enough evidence and ranks on taste only.
  bool get hasEvidence => availableAxes.isNotEmpty;

  /// Resona's policy, adapted: ease first, then clarity, then flow. Null
  /// means no clear need — a real result, not a failure.
  Experience? get suggestedExperience {
    final focus = valueOf(HsiAxis.focus);
    final stress = valueOf(HsiAxis.stress);
    final arousal = valueOf(HsiAxis.arousal);
    final capacity = valueOf(HsiAxis.capacity);
    if ((stress != null && stress >= .62) || (arousal != null && arousal >= .76) || (capacity != null && capacity <= .35)) {
      return Experience.unwind;
    }
    if (focus != null && focus <= .44) return Experience.easyWatch;
    if (focus != null && focus >= .60) return Experience.stayEngaged;
    return null;
  }

  CurrentState copyWith({StateSource? source, DateTime? capturedAt}) => CurrentState(
        focus: focus,
        stress: stress,
        arousal: arousal,
        capacity: capacity,
        source: source ?? this.source,
        capturedAt: capturedAt ?? this.capturedAt,
      );

  Map<String, Object?> toJson() => {
        for (final a in HsiAxis.values)
          if (reading(a) != null) a.name: [reading(a)!.value, reading(a)!.confidence],
        'source': source.name,
        if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
      };

  static CurrentState fromJson(Map<String, dynamic> m) {
    AxisReading? r(HsiAxis a) {
      final v = m[a.name];
      return v is List && v.length == 2 ? AxisReading((v[0] as num).toDouble(), (v[1] as num).toDouble()) : null;
    }

    final at = m['capturedAt'] as String?;
    return CurrentState(
      focus: r(HsiAxis.focus),
      stress: r(HsiAxis.stress),
      arousal: r(HsiAxis.arousal),
      capacity: r(HsiAxis.capacity),
      source: StateSource.values.byName(m['source'] as String),
      capturedAt: at == null ? null : DateTime.parse(at),
    );
  }

  @override
  List<Object?> get props => [focus, stress, arousal, capacity, source, capturedAt];
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
