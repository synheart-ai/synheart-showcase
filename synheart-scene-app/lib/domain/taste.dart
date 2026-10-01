import 'package:equatable/equatable.dart';

import 'film.dart';

/// The four answers the user can give to an onboarding film.
enum Rating {
  love('Love it'),
  like('Like it'),
  notForMe('Not for me'),
  notSeen("Haven't seen it");

  const Rating(this.label);
  final String label;

  /// How much this answer says about the user's taste (−1 … 1).
  /// "Haven't seen it" says nothing.
  double get weight => switch (this) {
        Rating.love => 1.0,
        Rating.like => 0.6,
        Rating.notForMe => -0.8,
        Rating.notSeen => 0.0,
      };
}

/// What the user answered during onboarding. This is the raw input; the
/// derived [TasteProfile] is computed from it.
class TasteAnswers extends Equatable {
  const TasteAnswers({
    this.ratings = const {},
    this.preferredGenres = const {},
    this.discovery = 0.5,
  });

  /// Film id → answer.
  final Map<String, Rating> ratings;

  /// Genres the user explicitly picked as favourites.
  final Set<Genre> preferredGenres;

  /// Familiar (0) ↔ Surprise me (1).
  final double discovery;

  int get answeredCount => ratings.values.where((r) => r != Rating.notSeen).length;

  TasteAnswers copyWith({Map<String, Rating>? ratings, Set<Genre>? preferredGenres, double? discovery}) =>
      TasteAnswers(
        ratings: ratings ?? this.ratings,
        preferredGenres: preferredGenres ?? this.preferredGenres,
        discovery: discovery ?? this.discovery,
      );

  @override
  List<Object?> get props => [ratings, preferredGenres, discovery];
}

/// The user's baseline — their "Movie DNA". Derived from [TasteAnswers];
/// Synheart never changes it.
class TasteProfile extends Equatable {
  const TasteProfile({
    required this.genreAffinity,
    required this.traitAffinity,
    required this.preferredIntensity,
    required this.preferredCognitiveLoad,
    required this.preferredEnergy,
    required this.likesDarkTones,
    required this.discovery,
    required this.seenFilmIds,
    this.hasTaste = true,
  });

  /// Whether the answers say anything about taste: a genre picked, or a film
  /// rated (anything but "Haven't seen it"). Without it every genre is
  /// neutral, and the state takes taste's share of the score.
  final bool hasTaste;

  /// Genre → affinity 0–1 (shown as a percentage in Movie DNA).
  final Map<Genre, double> genreAffinity;

  /// Trait → affinity 0–1.
  final Map<Trait, double> traitAffinity;

  /// Typical intensity / cognitive load / energy of films the user likes.
  final double preferredIntensity;
  final double preferredCognitiveLoad;
  final double preferredEnergy;

  /// 0–1: how much of what they like is dark or tense.
  final double likesDarkTones;

  /// Familiar (0) ↔ Surprise me (1).
  final double discovery;

  /// Films the user has seen (anything but "Haven't seen it"). Not recommended back.
  final Set<String> seenFilmIds;

  double affinityFor(Genre g) => genreAffinity[g] ?? 0;

  /// Genres ordered by affinity, strongest first.
  List<MapEntry<Genre, double>> get rankedGenres =>
      genreAffinity.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  /// Traits ordered by affinity, strongest first.
  List<MapEntry<Trait, double>> get rankedTraits =>
      traitAffinity.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  @override
  List<Object?> get props => [
        hasTaste,
        genreAffinity,
        traitAffinity,
        preferredIntensity,
        preferredCognitiveLoad,
        preferredEnergy,
        likesDarkTones,
        discovery,
        seenFilmIds,
      ];
}
