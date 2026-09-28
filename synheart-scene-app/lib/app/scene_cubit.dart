import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/film.dart';
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

/// The app's single source of truth. Taste answers are persisted so a demo
/// survives an app restart; the current state deliberately is not — it is
/// about *now*.
class SceneCubit extends Cubit<SceneState> {
  SceneCubit({this.prefs}) : super(const SceneState()) {
    _restore();
  }

  final SharedPreferences? prefs;
  static const _key = 'scene.tasteAnswers.v1';

  void _restore() {
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

  void rate(String filmId, Rating rating) {
    emit(state.copyWith(answers: state.answers.copyWith(ratings: {...state.answers.ratings, filmId: rating})));
    _persist();
  }

  void toggleGenre(Genre g) {
    final genres = {...state.answers.preferredGenres};
    genres.contains(g) ? genres.remove(g) : genres.add(g);
    emit(state.copyWith(answers: state.answers.copyWith(preferredGenres: genres)));
    _persist();
  }

  void setDiscovery(double v) {
    emit(state.copyWith(answers: state.answers.copyWith(discovery: v)));
    _persist();
  }

  /// Onboarding done: derive the Movie DNA.
  void completeProfile() {
    emit(state.copyWith(profile: buildTasteProfile(state.answers)));
    _persist();
  }

  /// "Try the demo profile" — fills onboarding with the plan's persona.
  void useAnswers(TasteAnswers answers) {
    emit(state.copyWith(answers: answers, profile: buildTasteProfile(answers)));
    _persist();
  }

  void setCurrentState(CurrentState s) => emit(state.copyWith(current: s));

  void setMode(RecommendationMode m) => emit(state.copyWith(mode: m));

  void setIntent(EveningIntent? intent) =>
      emit(state.copyWith(viewing: state.viewing.copyWith(intent: intent, clearIntent: intent == null)));

  void setShortOnly(bool on) =>
      emit(state.copyWith(viewing: state.viewing.copyWith(maxRuntimeMinutes: 90, clearRuntime: !on)));

  void giveFeedback(String filmId, Feedback f, {Set<String> reasons = const {}}) =>
      emit(state.copyWith(feedback: {...state.feedback, filmId: (f, reasons)}));

  /// Start over (for running the demo again).
  void reset() {
    prefs?.remove(_key);
    emit(const SceneState());
  }
}
