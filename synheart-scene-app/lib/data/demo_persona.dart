import '../domain/film.dart';
import '../domain/taste.dart';

/// The plan's live-demo persona (§10): "I generally prefer thrillers, sci-fi
/// and darker stories." Used by "Try the demo profile" and by the tests that
/// pin the demo story.
const demoPersonaAnswers = TasteAnswers(
  ratings: {
    'dark-knight': Rating.love,
    'zodiac': Rating.love,
    'inception': Rating.love,
    'parasite': Rating.love,
    'get-out': Rating.like,
    'whiplash': Rating.like,
    'interstellar': Rating.like,
    'notebook': Rating.notForMe,
    'superbad': Rating.notForMe,
    'la-la-land': Rating.notForMe,
    'paddington-2': Rating.notForMe,
    'hereditary': Rating.notSeen,
    'spirited-away': Rating.notSeen,
    'toy-story': Rating.notSeen,
    'mad-max': Rating.notSeen,
    'free-solo': Rating.notSeen,
  },
  preferredGenres: {Genre.thriller, Genre.sciFi, Genre.crime, Genre.mystery},
  discovery: 0.4,
);
