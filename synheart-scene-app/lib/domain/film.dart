import 'package:equatable/equatable.dart';

/// Genres a film can belong to. A film usually has two or three.
enum Genre {
  thriller('Thriller'),
  mystery('Mystery'),
  crime('Crime'),
  sciFi('Sci-Fi'),
  drama('Drama'),
  comedy('Comedy'),
  action('Action'),
  adventure('Adventure'),
  romance('Romance'),
  horror('Horror'),
  animation('Animation'),
  documentary('Documentary'),
  fantasy('Fantasy');

  const Genre(this.label);
  final String label;
}

/// The overall emotional colour of a film.
enum Tone {
  playful('playful'),
  uplifting('uplifting'),
  bittersweet('bittersweet'),
  tense('tense'),
  dark('dark'),
  heavy('emotionally heavy');

  const Tone(this.label);
  final String label;

  /// Light tones suit a moment where the user wants to switch off.
  bool get isLight => this == playful || this == uplifting;
}

enum Pacing { slow, moderate, fast }

/// Qualitative traits used for the Movie DNA and the explanations.
enum Trait {
  thoughtProvoking('thought-provoking stories'),
  characterDriven('character-driven plots'),
  clever('clever, twisty plotting'),
  feelGood('feel-good endings'),
  visuallyStriking('visually striking'),
  suspenseful('suspense');

  const Trait(this.label);
  final String label;
}

/// A film in Scene's curated demo catalogue.
///
/// The 0–1 attributes are **editorial ratings for the demo**, not measured
/// data: they only need to be consistent with each other so the scoring
/// rules behave believably.
class Film extends Equatable {
  const Film({
    required this.id,
    required this.title,
    required this.year,
    required this.runtimeMinutes,
    required this.genres,
    required this.tone,
    required this.pacing,
    required this.intensity,
    required this.cognitiveLoad,
    required this.energy,
    required this.familiarity,
    this.traits = const {},
    this.logline = '',
  });

  final String id;
  final String title;
  final int year;

  /// Approximate theatrical runtime.
  final int runtimeMinutes;
  final Set<Genre> genres;
  final Tone tone;
  final Pacing pacing;

  /// How emotionally intense / harrowing it is (0 gentle → 1 relentless).
  final double intensity;

  /// How much attention it asks for (0 easy watch → 1 demanding).
  final double cognitiveLoad;

  /// How lively it feels (0 quiet → 1 high-energy).
  final double energy;

  /// How mainstream / widely known it is (0 niche → 1 everyone knows it).
  final double familiarity;
  final Set<Trait> traits;
  final String logline;

  bool get isShort => runtimeMinutes <= 90;

  @override
  List<Object?> get props => [id];
}
