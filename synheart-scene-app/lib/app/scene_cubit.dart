import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/film.dart';
import 'demo_log.dart';
import '../domain/state.dart';
import '../domain/taste.dart';
import '../engine/recommender.dart';
import '../engine/taste_builder.dart';

/// Optional reasons after "Not really" / "Wrong for me" (plan §7).
const feedbackReasons = [
  'Wrong mood', 'Wrong genre', 'Too intense', 'Too slow', 'Too long', 'Already seen', 'Not interested',
];

/// Reasons that take a film out of future picks.
const hidingReasons = {'Already seen', 'Not interested'};

/// Lightweight feedback after a recommendation (plan §7).
enum Feedback {
  perfect('Perfect'),
  prettyGood('Pretty good'),
  notReally('Not really'),
  wrongForMe('Wrong for me');

  const Feedback(this.label);
  final String label;
}

class SceneState extends Equatable {
  const SceneState({
    this.answers = const TasteAnswers(),
    this.profile,
    this.current,
    this.viewing = const ViewingContext(),
    this.mode = RecommendationMode.tasteOnly,
    this.feedback = const {},
  });

  final TasteAnswers answers;

  /// Set once onboarding is finished.
  final TasteProfile? profile;

  /// Set after the Synheart check-in (or a preset / manual adjustment).
  final CurrentState? current;
  final ViewingContext viewing;

  /// Tonight's Picks starts on taste only, so the demo can reveal the change.
  final RecommendationMode mode;

  /// Film id → feedback, with optional reasons.
  final Map<String, (Feedback, Set<String>)> feedback;

  bool get hasProfile => profile != null;

  /// Films the user's feedback asked Scene not to suggest again.
  Set<String> get hiddenFilmIds => {
        for (final e in feedback.entries)
          if (e.value.$1 == Feedback.wrongForMe || e.value.$2.any(hidingReasons.contains)) e.key,
      };

  SceneState copyWith({
    TasteAnswers? answers,
    TasteProfile? profile,
    bool clearProfile = false,
    CurrentState? current,
    bool clearCurrent = false,
    ViewingContext? viewing,
    RecommendationMode? mode,
    Map<String, (Feedback, Set<String>)>? feedback,
  }) =>
      SceneState(
        answers: answers ?? this.answers,
        profile: clearProfile ? null : (profile ?? this.profile),
        current: clearCurrent ? null : (current ?? this.current),
        viewing: viewing ?? this.viewing,
        mode: mode ?? this.mode,
        feedback: feedback ?? this.feedback,
      );

  @override
  List<Object?> get props => [answers, profile, current, viewing, mode, feedback];
}

/// The app's single source of truth.
///
/// Stored on the device (RFC §6): the user's direct taste answers, kept
/// separate from the derived profile, and the **derived** state snapshot
/// (the four HSI axes with their confidence, its source and time). Raw
/// heart-rate samples are never stored. Reset demo clears both.
class SceneCubit extends Cubit<SceneState> {
  SceneCubit({this.prefs, DateTime Function()? clock, DemoLog? log})
      : _clock = clock ?? DateTime.now,
        log = log ?? DemoLog(clock: clock),
        super(const SceneState()) {
    _restore();
  }

  final SharedPreferences? prefs;
  final DateTime Function() _clock;

  /// Demo events (RFC §10); screens record the ones the cubit cannot see.
  final DemoLog log;
  static const _key = 'scene.tasteAnswers.v1';
  static const _stateKey = 'scene.stateSnapshot.v1';

  DateTime now() => _clock();

  /// The state snapshot if it is fresh; otherwise null, so the app falls
  /// back to taste only instead of implying Synheart shaped the list
  /// (RFC §8).
  CurrentState? get freshState {
    final c = state.current;
    return c == null || c.isStaleAt(now()) ? null : c;
  }

  void _restore() {
    _restoreAnswers();
    _restoreState();
  }

  void _restoreAnswers() {
    final raw = prefs?.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final answers = TasteAnswers(
        ratings: {
          for (final e in (m['ratings'] as Map<String, dynamic>).entries) e.key: Rating.values.byName(e.value as String),
        },
        preferredGenres: {for (final g in m['genres'] as List) Genre.values.byName(g as String)},
        discovery: (m['discovery'] as num).toDouble(),
      );
      emit(state.copyWith(answers: answers, profile: m['complete'] == true ? buildTasteProfile(answers) : null));
    } catch (_) {
      // A stored profile from an older build is simply ignored.
    }
  }

  void _restoreState() {
    try {
      final raw = prefs?.getString(_stateKey);
      if (raw == null) return;
      emit(state.copyWith(current: CurrentState.fromJson(jsonDecode(raw) as Map<String, dynamic>)));
    } catch (_) {
      // An unreadable snapshot is dropped; the user can check in again.
    }
  }

  void _persistState() {
    final c = state.current;
    if (c == null) {
      prefs?.remove(_stateKey);
      return;
    }
    prefs?.setString(_stateKey, jsonEncode(c.toJson()));
  }

  void _persist() {
    final a = state.answers;
    prefs?.setString(
      _key,
      jsonEncode({
        'ratings': {for (final e in a.ratings.entries) e.key: e.value.name},
        'genres': [for (final g in a.preferredGenres) g.name],
        'discovery': a.discovery,
        'complete': state.hasProfile,
      }),
    );
  }

  /// Once a profile exists, every edit rebuilds it, so the rankings follow
  /// the user's edits straight away (RFC §9.2).
  void _answersChanged(TasteAnswers answers) {
    emit(state.copyWith(answers: answers, profile: state.hasProfile ? buildTasteProfile(answers) : null));
    _persist();
  }

  void rate(String filmId, Rating rating) =>
      _answersChanged(state.answers.copyWith(ratings: {...state.answers.ratings, filmId: rating}));

  /// Un-answer a film (skipped, or cleared while editing).
  void clearRating(String filmId) =>
      _answersChanged(state.answers.copyWith(ratings: {...state.answers.ratings}..remove(filmId)));

  void toggleGenre(Genre g) {
    final genres = {...state.answers.preferredGenres};
    genres.contains(g) ? genres.remove(g) : genres.add(g);
    _answersChanged(state.answers.copyWith(preferredGenres: genres));
  }

  void setDiscovery(double v) => _answersChanged(state.answers.copyWith(discovery: v));

  /// Onboarding done: derive the Movie DNA.
  void completeProfile() {
    emit(state.copyWith(profile: buildTasteProfile(state.answers)));
    _persist();
    log.record(DemoEvent.onboardingCompleted, {
      'rated': '${state.answers.answeredCount}',
      'genres': '${state.answers.preferredGenres.length}',
    });
  }

  /// "Try the demo profile" — fills onboarding with the plan's persona.
  void useAnswers(TasteAnswers answers) {
    emit(state.copyWith(answers: answers, profile: buildTasteProfile(answers)));
    _persist();
    log.record(DemoEvent.onboardingCompleted, {'profile': 'demo'});
  }

  /// A new snapshot is stamped now; an adjustment keeps the original time,
  /// because the signals are still from that check-in.
  void setCurrentState(CurrentState s) {
    emit(state.copyWith(current: s.capturedAt == null ? s.copyWith(capturedAt: now()) : s));
    _persistState();
  }

  /// Declined or skipped check-in: no state, taste only (RFC §9.7).
  void clearCurrentState() {
    emit(state.copyWith(clearCurrent: true, mode: RecommendationMode.tasteOnly));
    _persistState();
  }

  void setMode(RecommendationMode m) {
    if (m != state.mode) log.record(DemoEvent.comparisonToggled, {'mode': m.name});
    emit(state.copyWith(mode: m));
  }

  void setIntent(EveningIntent? intent) {
    if (intent != state.viewing.intent) log.record(DemoEvent.intentChanged, {'intent': intent?.name ?? 'none'});
    emit(state.copyWith(viewing: state.viewing.copyWith(intent: intent, clearIntent: intent == null)));
  }

  void setShortOnly(bool on) =>
      emit(state.copyWith(viewing: state.viewing.copyWith(maxRuntimeMinutes: 90, clearRuntime: !on)));

  void giveFeedback(String filmId, Feedback f, {Set<String> reasons = const {}}) {
    emit(state.copyWith(feedback: {...state.feedback, filmId: (f, reasons)}));
    log.record(DemoEvent.feedbackGiven, {'film': filmId, 'feedback': f.name, if (reasons.isNotEmpty) 'reasons': reasons.join('|')});
  }

  /// Reset demo: clears the stored inputs and the state snapshot (RFC §9.8).
  void reset() {
    prefs?.remove(_key);
    prefs?.remove(_stateKey);
    emit(const SceneState());
    log.record(DemoEvent.demoReset);
  }
}
