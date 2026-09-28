import 'package:equatable/equatable.dart';

/// A coarse, non-clinical level used on the Current State card.
enum Level {
  low('Low'),
  moderate('Moderate'),
  high('High');

  const Level(this.label);
  final String label;

  static Level fromValue(double v) => v < 0.36 ? Level.low : (v < 0.66 ? Level.moderate : Level.high);

  /// A representative value for the level (used when the user adjusts it).
  double get value => switch (this) {
        Level.low => 0.2,
        Level.moderate => 0.5,
        Level.high => 0.8,
      };
}

/// The kind of experience that fits the current moment.
enum Experience {
  unwind('Unwind', 'a good evening to unwind'),
  stayEngaged('Stay engaged', 'a good evening for something engaging'),
  liftMe('Lift me up', 'a good evening for something lively'),
  easyWatch('Easy watch', 'a good evening for an easy watch');

  const Experience(this.label, this.phrase);
  final String label;

  /// Tentative phrase for sentences — "This may be a good evening to unwind",
  /// never "You are stressed" (RFC §8).
  final String phrase;

  /// The viewing intent this suggests, which the user can accept, change or
  /// skip on the Current context screen (RFC §4.5).
  EveningIntent get suggestedIntent => switch (this) {
        Experience.unwind => EveningIntent.unwind,
        Experience.stayEngaged => EveningIntent.engaging,
        Experience.liftMe || Experience.easyWatch => EveningIntent.entertain,
      };
}

/// Where the state came from — shown so the demo stays honest.
enum StateSource {
  synheart('From your Synheart check-in'),
  adjusted('Adjusted by you'),
  preset('Demo data — not a real check-in');

  const StateSource(this.label);
  final String label;
}

/// The user's current state in simple, non-clinical terms. This is an input
/// to personalisation — never a diagnosis — and the user can always adjust it.
class CurrentState extends Equatable {
  const CurrentState({
    required this.energy,
    required this.mentalLoad,
    required this.engagement,
    required this.source,
    this.capturedAt,
  });

  /// How long a check-in stays usable. A tunable default: the RFC leaves the
  /// freshness rule open (§13).
  static const freshFor = Duration(hours: 2);

  /// When the snapshot was taken; null for a preset not yet applied.
  final DateTime? capturedAt;

  bool isStaleAt(DateTime now) => capturedAt != null && now.difference(capturedAt!) > freshFor;

  /// 0–1.
  final double energy;
  final double mentalLoad;
  final double engagement;
  final StateSource source;

  Level get energyLevel => Level.fromValue(energy);
  Level get mentalLoadLevel => Level.fromValue(mentalLoad);
  Level get engagementLevel => Level.fromValue(engagement);

  /// The plan's "Suggested Experience" line, derived from the three signals.
  Experience get suggestedExperience {
    if (mentalLoad >= 0.66) return Experience.unwind;
    if (energy < 0.36) return Experience.easyWatch;
    if (engagement >= 0.66) return Experience.stayEngaged;
    if (energy >= 0.66) return Experience.liftMe;
    return Experience.easyWatch;
  }

  CurrentState copyWith({double? energy, double? mentalLoad, double? engagement, StateSource? source, DateTime? capturedAt}) =>
      CurrentState(
        energy: energy ?? this.energy,
        mentalLoad: mentalLoad ?? this.mentalLoad,
        engagement: engagement ?? this.engagement,
        source: source ?? this.source,
        capturedAt: capturedAt ?? this.capturedAt,
      );

  /// The plan's example state card: moderate energy, high mental load,
  /// moderate engagement → Unwind.
  static const planExample = CurrentState(
    energy: 0.5,
    mentalLoad: 0.8,
    engagement: 0.5,
    source: StateSource.preset,
  );

  @override
  List<Object?> get props => [energy, mentalLoad, engagement, source, capturedAt];
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
