import '../domain/film.dart';

// Scene's curated demo catalogue.
//
// Runtimes are approximate real-world theatrical runtimes. The 0–1 attributes
// (intensity, cognitive load, energy, familiarity) are editorial ratings for
// the demo, kept consistent across films so the scoring rules read sensibly.

/// Films the user rates while building their Movie Profile (the plan asks for
/// ~12–20 recognisable titles spanning genres and tones). They define the
/// baseline and are not recommended back.
const onboardingFilms = <Film>[
  Film(
    id: 'dark-knight', title: 'The Dark Knight', year: 2008, runtimeMinutes: 152,
    genres: {Genre.action, Genre.crime, Genre.thriller}, tone: Tone.dark, pacing: Pacing.fast,
    intensity: 0.85, cognitiveLoad: 0.65, energy: 0.85, familiarity: 0.95,
    traits: {Trait.suspenseful, Trait.characterDriven},
    logline: 'A city at war with an agent of chaos.',
  ),
  Film(
    id: 'inception', title: 'Inception', year: 2010, runtimeMinutes: 148,
    genres: {Genre.sciFi, Genre.thriller, Genre.action}, tone: Tone.tense, pacing: Pacing.fast,
    intensity: 0.7, cognitiveLoad: 0.9, energy: 0.8, familiarity: 0.95,
    traits: {Trait.thoughtProvoking, Trait.clever, Trait.visuallyStriking},
    logline: 'A heist set inside layered dreams.',
  ),
  Film(
    id: 'zodiac', title: 'Zodiac', year: 2007, runtimeMinutes: 157,
    genres: {Genre.crime, Genre.mystery, Genre.thriller}, tone: Tone.dark, pacing: Pacing.slow,
    intensity: 0.75, cognitiveLoad: 0.8, energy: 0.4, familiarity: 0.6,
    traits: {Trait.suspenseful, Trait.characterDriven, Trait.thoughtProvoking},
    logline: 'An obsession with an unsolved series of murders.',
  ),
  Film(
    id: 'hereditary', title: 'Hereditary', year: 2018, runtimeMinutes: 127,
    genres: {Genre.horror, Genre.drama, Genre.mystery}, tone: Tone.heavy, pacing: Pacing.slow,
    intensity: 0.95, cognitiveLoad: 0.7, energy: 0.4, familiarity: 0.55,
    traits: {Trait.suspenseful},
    logline: 'A family unravels after a death.',
  ),
  Film(
    id: 'get-out', title: 'Get Out', year: 2017, runtimeMinutes: 104,
    genres: {Genre.horror, Genre.thriller, Genre.mystery}, tone: Tone.tense, pacing: Pacing.moderate,
    intensity: 0.75, cognitiveLoad: 0.6, energy: 0.55, familiarity: 0.8,
    traits: {Trait.clever, Trait.suspenseful, Trait.thoughtProvoking},
    logline: 'A weekend visit that turns sinister.',
  ),
  Film(
    id: 'parasite', title: 'Parasite', year: 2019, runtimeMinutes: 132,
    genres: {Genre.thriller, Genre.drama, Genre.comedy}, tone: Tone.dark, pacing: Pacing.moderate,
    intensity: 0.75, cognitiveLoad: 0.75, energy: 0.6, familiarity: 0.8,
    traits: {Trait.clever, Trait.thoughtProvoking, Trait.characterDriven},
    logline: 'Two families, one house, and a slow-burning con.',
  ),
  Film(
    id: 'whiplash', title: 'Whiplash', year: 2014, runtimeMinutes: 107,
    genres: {Genre.drama}, tone: Tone.tense, pacing: Pacing.fast,
    intensity: 0.8, cognitiveLoad: 0.5, energy: 0.75, familiarity: 0.75,
    traits: {Trait.characterDriven},
    logline: 'A drummer and a teacher who will not relent.',
  ),
  Film(
    id: 'la-la-land', title: 'La La Land', year: 2016, runtimeMinutes: 128,
    genres: {Genre.romance, Genre.drama, Genre.comedy}, tone: Tone.bittersweet, pacing: Pacing.moderate,
    intensity: 0.35, cognitiveLoad: 0.35, energy: 0.6, familiarity: 0.9,
    traits: {Trait.visuallyStriking, Trait.characterDriven},
    logline: 'Two dreamers fall in love in Los Angeles.',
  ),
  Film(
    id: 'notebook', title: 'The Notebook', year: 2004, runtimeMinutes: 123,
    genres: {Genre.romance, Genre.drama}, tone: Tone.bittersweet, pacing: Pacing.slow,
    intensity: 0.4, cognitiveLoad: 0.25, energy: 0.35, familiarity: 0.85,
    traits: {Trait.characterDriven},
    logline: 'A love story told across a lifetime.',
  ),
  Film(
    id: 'superbad', title: 'Superbad', year: 2007, runtimeMinutes: 113,
    genres: {Genre.comedy}, tone: Tone.playful, pacing: Pacing.fast,
    intensity: 0.15, cognitiveLoad: 0.15, energy: 0.8, familiarity: 0.85,
    traits: {Trait.feelGood},
    logline: 'Two friends, one party, a very long night.',
  ),
  Film(
    id: 'paddington-2', title: 'Paddington 2', year: 2017, runtimeMinutes: 104,
    genres: {Genre.comedy, Genre.adventure}, tone: Tone.uplifting, pacing: Pacing.moderate,
    intensity: 0.1, cognitiveLoad: 0.2, energy: 0.6, familiarity: 0.75,
    traits: {Trait.feelGood, Trait.visuallyStriking},
    logline: 'A polite bear, a stolen book, and a prison bakery.',
  ),
  Film(
    id: 'spirited-away', title: 'Spirited Away', year: 2001, runtimeMinutes: 125,
    genres: {Genre.animation, Genre.fantasy, Genre.adventure}, tone: Tone.uplifting, pacing: Pacing.moderate,
    intensity: 0.4, cognitiveLoad: 0.5, energy: 0.5, familiarity: 0.8,
    traits: {Trait.visuallyStriking, Trait.thoughtProvoking},
    logline: 'A girl trapped in a world of spirits.',
  ),
  Film(
    id: 'toy-story', title: 'Toy Story', year: 1995, runtimeMinutes: 81,
    genres: {Genre.animation, Genre.comedy, Genre.adventure}, tone: Tone.playful, pacing: Pacing.fast,
    intensity: 0.15, cognitiveLoad: 0.15, energy: 0.7, familiarity: 0.95,
    traits: {Trait.feelGood},
    logline: 'The toys come alive when no one is looking.',
  ),
  Film(
    id: 'mad-max', title: 'Mad Max: Fury Road', year: 2015, runtimeMinutes: 120,
    genres: {Genre.action, Genre.sciFi, Genre.adventure}, tone: Tone.tense, pacing: Pacing.fast,
    intensity: 0.85, cognitiveLoad: 0.3, energy: 0.95, familiarity: 0.8,
    traits: {Trait.visuallyStriking},
    logline: 'One long chase across a desert wasteland.',
  ),
  Film(
    id: 'free-solo', title: 'Free Solo', year: 2018, runtimeMinutes: 100,
    genres: {Genre.documentary, Genre.adventure}, tone: Tone.tense, pacing: Pacing.moderate,
    intensity: 0.65, cognitiveLoad: 0.4, energy: 0.6, familiarity: 0.55,
    traits: {Trait.suspenseful, Trait.visuallyStriking},
    logline: 'A climb up El Capitan without a rope.',
  ),
  Film(
    id: 'interstellar', title: 'Interstellar', year: 2014, runtimeMinutes: 169,
    genres: {Genre.sciFi, Genre.drama, Genre.adventure}, tone: Tone.heavy, pacing: Pacing.slow,
    intensity: 0.7, cognitiveLoad: 0.9, energy: 0.55, familiarity: 0.9,
    traits: {Trait.thoughtProvoking, Trait.visuallyStriking},
    logline: 'A journey through a wormhole to save humanity.',
  ),
];

/// Films Scene can recommend. Includes the plan's worked example (Se7en …
/// Ocean's Eleven) so the "What changed?" demo reproduces its story.
const candidateFilms = <Film>[
  Film(
    id: 'se7en', title: 'Se7en', year: 1995, runtimeMinutes: 127,
    genres: {Genre.crime, Genre.thriller, Genre.mystery}, tone: Tone.dark, pacing: Pacing.moderate,
    intensity: 0.95, cognitiveLoad: 0.75, energy: 0.55, familiarity: 0.85,
    traits: {Trait.suspenseful, Trait.thoughtProvoking},
    logline: 'Two detectives hunt a killer who follows a pattern.',
  ),
  Film(
    id: 'prisoners', title: 'Prisoners', year: 2013, runtimeMinutes: 153,
    genres: {Genre.crime, Genre.thriller, Genre.mystery}, tone: Tone.dark, pacing: Pacing.slow,
    intensity: 0.9, cognitiveLoad: 0.75, energy: 0.45, familiarity: 0.6,
    traits: {Trait.suspenseful, Trait.characterDriven},
    logline: 'A father takes the search for his daughter into his own hands.',
  ),
  Film(
    id: 'gone-girl', title: 'Gone Girl', year: 2014, runtimeMinutes: 149,
    genres: {Genre.thriller, Genre.mystery, Genre.drama}, tone: Tone.dark, pacing: Pacing.moderate,
    intensity: 0.8, cognitiveLoad: 0.8, energy: 0.5, familiarity: 0.8,
    traits: {Trait.clever, Trait.suspenseful, Trait.characterDriven},
    logline: 'A marriage examined after a wife disappears.',
  ),
  Film(
    id: 'shutter-island', title: 'Shutter Island', year: 2010, runtimeMinutes: 138,
    genres: {Genre.thriller, Genre.mystery}, tone: Tone.dark, pacing: Pacing.moderate,
    intensity: 0.8, cognitiveLoad: 0.85, energy: 0.5, familiarity: 0.85,
    traits: {Trait.clever, Trait.suspenseful},
    logline: 'A marshal investigates a disappearance on an island asylum.',
  ),
  Film(
    id: 'knives-out', title: 'Knives Out', year: 2019, runtimeMinutes: 130,
    genres: {Genre.mystery, Genre.crime, Genre.comedy}, tone: Tone.playful, pacing: Pacing.moderate,
    intensity: 0.4, cognitiveLoad: 0.6, energy: 0.65, familiarity: 0.8,
    traits: {Trait.clever, Trait.suspenseful, Trait.characterDriven},
    logline: 'A detective untangles a wealthy family after a death.',
  ),
  Film(
    id: 'nice-guys', title: 'The Nice Guys', year: 2016, runtimeMinutes: 116,
    genres: {Genre.crime, Genre.comedy, Genre.mystery}, tone: Tone.playful, pacing: Pacing.fast,
    intensity: 0.4, cognitiveLoad: 0.45, energy: 0.8, familiarity: 0.5,
    traits: {Trait.clever, Trait.characterDriven},
    logline: 'Two mismatched investigators stumble through 1970s LA.',
  ),
  Film(
    id: 'catch-me', title: 'Catch Me If You Can', year: 2002, runtimeMinutes: 141,
    genres: {Genre.crime, Genre.drama, Genre.comedy}, tone: Tone.playful, pacing: Pacing.moderate,
    intensity: 0.3, cognitiveLoad: 0.45, energy: 0.65, familiarity: 0.8,
    traits: {Trait.clever, Trait.characterDriven, Trait.feelGood},
    logline: 'A young con artist stays one step ahead of the FBI.',
  ),
  Film(
    id: 'grand-budapest', title: 'The Grand Budapest Hotel', year: 2014, runtimeMinutes: 99,
    genres: {Genre.comedy, Genre.crime, Genre.adventure}, tone: Tone.playful, pacing: Pacing.fast,
    intensity: 0.3, cognitiveLoad: 0.5, energy: 0.65, familiarity: 0.7,
    traits: {Trait.clever, Trait.visuallyStriking, Trait.characterDriven},
    logline: 'A concierge, a stolen painting and a very fine hotel.',
  ),
  Film(
    id: 'oceans-eleven', title: "Ocean's Eleven", year: 2001, runtimeMinutes: 116,
    genres: {Genre.crime, Genre.thriller, Genre.comedy}, tone: Tone.playful, pacing: Pacing.fast,
    intensity: 0.35, cognitiveLoad: 0.45, energy: 0.7, familiarity: 0.85,
    traits: {Trait.clever, Trait.feelGood},
    logline: 'Eleven thieves, three casinos, one night.',
  ),
  Film(
    id: 'glass-onion', title: 'Glass Onion', year: 2022, runtimeMinutes: 139,
    genres: {Genre.mystery, Genre.comedy, Genre.crime}, tone: Tone.playful, pacing: Pacing.moderate,
    intensity: 0.35, cognitiveLoad: 0.55, energy: 0.7, familiarity: 0.65,
    traits: {Trait.clever},
    logline: 'A murder mystery on a billionaire\'s private island.',
  ),
  Film(
    id: 'baby-driver', title: 'Baby Driver', year: 2017, runtimeMinutes: 113,
    genres: {Genre.action, Genre.crime, Genre.comedy}, tone: Tone.playful, pacing: Pacing.fast,
    intensity: 0.55, cognitiveLoad: 0.3, energy: 0.9, familiarity: 0.65,
    traits: {Trait.visuallyStriking},
    logline: 'A getaway driver who works to his own soundtrack.',
  ),
  Film(
    id: 'hot-fuzz', title: 'Hot Fuzz', year: 2007, runtimeMinutes: 121,
    genres: {Genre.comedy, Genre.action, Genre.mystery}, tone: Tone.playful, pacing: Pacing.fast,
    intensity: 0.35, cognitiveLoad: 0.35, energy: 0.85, familiarity: 0.6,
    traits: {Trait.clever},
    logline: 'A big-city officer uncovers a sleepy village\'s secrets.',
  ),
  Film(
    id: 'arrival', title: 'Arrival', year: 2016, runtimeMinutes: 116,
    genres: {Genre.sciFi, Genre.drama, Genre.mystery}, tone: Tone.bittersweet, pacing: Pacing.slow,
    intensity: 0.55, cognitiveLoad: 0.9, energy: 0.35, familiarity: 0.7,
    traits: {Trait.thoughtProvoking, Trait.characterDriven},
    logline: 'A linguist tries to understand visitors from elsewhere.',
  ),
  Film(
    id: 'ex-machina', title: 'Ex Machina', year: 2014, runtimeMinutes: 108,
    genres: {Genre.sciFi, Genre.thriller, Genre.drama}, tone: Tone.tense, pacing: Pacing.slow,
    intensity: 0.65, cognitiveLoad: 0.8, energy: 0.35, familiarity: 0.6,
    traits: {Trait.thoughtProvoking, Trait.clever},
    logline: 'A programmer is asked to test an artificial mind.',
  ),
  Film(
    id: 'blade-runner-2049', title: 'Blade Runner 2049', year: 2017, runtimeMinutes: 164,
    genres: {Genre.sciFi, Genre.mystery, Genre.drama}, tone: Tone.heavy, pacing: Pacing.slow,
    intensity: 0.65, cognitiveLoad: 0.85, energy: 0.35, familiarity: 0.7,
    traits: {Trait.visuallyStriking, Trait.thoughtProvoking},
    logline: 'A replicant hunter finds a secret that could end an era.',
  ),
  Film(
    id: 'the-martian', title: 'The Martian', year: 2015, runtimeMinutes: 144,
    genres: {Genre.sciFi, Genre.adventure, Genre.comedy}, tone: Tone.uplifting, pacing: Pacing.moderate,
    intensity: 0.45, cognitiveLoad: 0.55, energy: 0.6, familiarity: 0.85,
    traits: {Trait.clever, Trait.feelGood},
    logline: 'An astronaut stranded on Mars works his way home with science.',
  ),
  Film(
    id: 'everything-everywhere', title: 'Everything Everywhere All at Once', year: 2022, runtimeMinutes: 139,
    genres: {Genre.sciFi, Genre.comedy, Genre.action}, tone: Tone.bittersweet, pacing: Pacing.fast,
    intensity: 0.6, cognitiveLoad: 0.85, energy: 0.9, familiarity: 0.7,
    traits: {Trait.thoughtProvoking, Trait.visuallyStriking},
    logline: 'A laundromat owner fights across the multiverse.',
  ),
  Film(
    id: 'palm-springs', title: 'Palm Springs', year: 2020, runtimeMinutes: 90,
    genres: {Genre.comedy, Genre.romance, Genre.sciFi}, tone: Tone.playful, pacing: Pacing.fast,
    intensity: 0.2, cognitiveLoad: 0.35, energy: 0.65, familiarity: 0.45,
    traits: {Trait.clever, Trait.feelGood},
    logline: 'Two wedding guests stuck living the same day.',
  ),
  Film(
    id: 'chef', title: 'Chef', year: 2014, runtimeMinutes: 114,
    genres: {Genre.comedy, Genre.drama}, tone: Tone.uplifting, pacing: Pacing.moderate,
    intensity: 0.1, cognitiveLoad: 0.15, energy: 0.55, familiarity: 0.5,
    traits: {Trait.feelGood, Trait.characterDriven},
    logline: 'A chef quits his job and starts a food truck.',
  ),
  Film(
    id: 'intouchables', title: 'The Intouchables', year: 2011, runtimeMinutes: 112,
    genres: {Genre.comedy, Genre.drama}, tone: Tone.uplifting, pacing: Pacing.moderate,
    intensity: 0.25, cognitiveLoad: 0.3, energy: 0.55, familiarity: 0.55,
    traits: {Trait.feelGood, Trait.characterDriven},
    logline: 'An unlikely friendship between a carer and his employer.',
  ),
  Film(
    id: 'amelie', title: 'Amélie', year: 2001, runtimeMinutes: 122,
    genres: {Genre.romance, Genre.comedy, Genre.fantasy}, tone: Tone.uplifting, pacing: Pacing.moderate,
    intensity: 0.15, cognitiveLoad: 0.35, energy: 0.55, familiarity: 0.65,
    traits: {Trait.visuallyStriking, Trait.feelGood},
    logline: 'A shy Parisian quietly changes the lives around her.',
  ),
  Film(
    id: 'up', title: 'Up', year: 2009, runtimeMinutes: 96,
    genres: {Genre.animation, Genre.adventure, Genre.comedy}, tone: Tone.uplifting, pacing: Pacing.moderate,
    intensity: 0.3, cognitiveLoad: 0.2, energy: 0.6, familiarity: 0.9,
    traits: {Trait.feelGood, Trait.characterDriven},
    logline: 'A widower ties balloons to his house and flies away.',
  ),
  Film(
    id: 'coco', title: 'Coco', year: 2017, runtimeMinutes: 105,
    genres: {Genre.animation, Genre.fantasy, Genre.adventure}, tone: Tone.uplifting, pacing: Pacing.moderate,
    intensity: 0.3, cognitiveLoad: 0.25, energy: 0.6, familiarity: 0.8,
    traits: {Trait.feelGood, Trait.visuallyStriking},
    logline: 'A boy crosses into the Land of the Dead.',
  ),
  Film(
    id: 'octopus-teacher', title: 'My Octopus Teacher', year: 2020, runtimeMinutes: 85,
    genres: {Genre.documentary}, tone: Tone.uplifting, pacing: Pacing.slow,
    intensity: 0.2, cognitiveLoad: 0.3, energy: 0.25, familiarity: 0.4,
    traits: {Trait.visuallyStriking, Trait.thoughtProvoking},
    logline: 'A year spent with an octopus in a kelp forest.',
  ),
  Film(
    id: 'quiet-place', title: 'A Quiet Place', year: 2018, runtimeMinutes: 90,
    genres: {Genre.horror, Genre.sciFi, Genre.thriller}, tone: Tone.tense, pacing: Pacing.moderate,
    intensity: 0.85, cognitiveLoad: 0.4, energy: 0.55, familiarity: 0.8,
    traits: {Trait.suspenseful},
    logline: 'A family survives in silence.',
  ),
  Film(
    id: 'john-wick', title: 'John Wick', year: 2014, runtimeMinutes: 101,
    genres: {Genre.action, Genre.thriller, Genre.crime}, tone: Tone.dark, pacing: Pacing.fast,
    intensity: 0.75, cognitiveLoad: 0.2, energy: 0.95, familiarity: 0.85,
    traits: {Trait.visuallyStriking},
    logline: 'A retired hitman returns for one reason.',
  ),
  Film(
    id: 'top-gun-maverick', title: 'Top Gun: Maverick', year: 2022, runtimeMinutes: 130,
    genres: {Genre.action, Genre.drama}, tone: Tone.uplifting, pacing: Pacing.fast,
    intensity: 0.55, cognitiveLoad: 0.25, energy: 0.9, familiarity: 0.85,
    traits: {Trait.feelGood, Trait.visuallyStriking},
    logline: 'A veteran pilot trains a team for an impossible mission.',
  ),
  Film(
    id: 'before-sunrise', title: 'Before Sunrise', year: 1995, runtimeMinutes: 101,
    genres: {Genre.romance, Genre.drama}, tone: Tone.bittersweet, pacing: Pacing.slow,
    intensity: 0.2, cognitiveLoad: 0.45, energy: 0.3, familiarity: 0.5,
    traits: {Trait.characterDriven, Trait.thoughtProvoking},
    logline: 'Two strangers walk and talk through one night in Vienna.',
  ),
  Film(
    id: 'social-network', title: 'The Social Network', year: 2010, runtimeMinutes: 120,
    genres: {Genre.drama}, tone: Tone.tense, pacing: Pacing.fast,
    intensity: 0.5, cognitiveLoad: 0.7, energy: 0.7, familiarity: 0.8,
    traits: {Trait.characterDriven, Trait.clever},
    logline: 'The founding of a social network, and the lawsuits after.',
  ),
];

/// Every film Scene knows about.
const allFilms = <Film>[...onboardingFilms, ...candidateFilms];

Film? filmById(String id) {
  for (final f in allFilms) {
    if (f.id == id) return f;
  }
  return null;
}
