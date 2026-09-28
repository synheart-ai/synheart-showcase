import '../domain/state.dart';
import 'recommender.dart';

String _level(double v, {required String low, required String moderate, required String high}) =>
    v < 0.36 ? low : (v < 0.66 ? moderate : high);

String _join(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

/// The plan's "Why this movie?" (§5): baseline, current context, and how the
/// recommendation meets both. Built from the same numbers that produced the
/// score, so it never claims something the scoring did not do.
class Explanation {
  const Explanation({required this.baseline, required this.context, required this.recommendation, required this.headline});

  /// "Baseline: mystery, crime, clever plots, character-driven stories."
  final String baseline;

  /// "Current context: lower intensity, moderate cognitive engagement, …" — or
  /// null when the pick was made on taste alone.
  final String? context;

  /// How the two came together.
  final String recommendation;

  /// The short match line shown on the card instead of an opaque score.
  final String headline;
}

/// [usualIntensity] is the intensity of the films the user usually enjoys
/// (from their taste profile): intensity is described relative to it.
Explanation explain(
  Recommendation r, {
  CurrentState? state,
  ViewingContext viewing = const ViewingContext(),
  RecommendationMode mode = RecommendationMode.tastePlusState,
  double? usualIntensity,
}) {
  final f = r.film;
  final genres = r.matchedGenres.take(3).map((g) => g.label.toLowerCase()).toList();
  final traits = r.matchedTraits.take(2).map((t) => t.label).toList();
  final baselineParts = [...genres, ...traits];
  final baseline = baselineParts.isEmpty
      ? 'Baseline: close to films you rated well.'
      : 'Baseline: ${_join(baselineParts)}.';

  if (mode == RecommendationMode.tasteOnly || state == null) {
    return Explanation(
      baseline: baseline,
      context: null,
      recommendation: 'Chosen on taste alone — the way a conventional recommender would.',
      headline: 'Matches what you usually enjoy${genres.isEmpty ? '' : ': ${_join(genres)}'}.',
    );
  }

  final t = StateTargets.from(state);
  final delta = usualIntensity == null ? 0.0 : f.intensity - usualIntensity;
  final intensity = delta <= -0.2
      ? 'lower intensity than you usually choose'
      : delta >= 0.2
          ? 'more intense than you usually choose'
          : _level(f.intensity, low: 'lower intensity', moderate: 'moderate intensity', high: 'high intensity');
  final thinking = _level(f.cognitiveLoad, low: 'an easy watch', moderate: 'moderate cognitive engagement', high: 'a demanding watch');
  final tone = f.tone.isLight ? 'entertaining rather than emotionally heavy' : 'a ${f.tone.label} tone';
  final contextParts = [intensity, thinking, tone];
  if (viewing.maxRuntimeMinutes != null) contextParts.add('under ${viewing.maxRuntimeMinutes} minutes');
  if (viewing.intent != null) contextParts.add('fits "${viewing.intent!.label}"');

  final softer = f.intensity < t.intensity + 0.15 && t.prefersLightTone;
  final recommendation = softer
      ? 'A film that stays true to your taste while adjusting intensity and tone for the current moment.'
      : 'A film that fits both your taste and how you are right now.';

  final what = traits.isNotEmpty ? traits.first : (genres.isNotEmpty ? '${genres.first} stories' : 'the films you like');
  final headline = t.prefersLightTone
      ? 'Matches your taste for $what, while fitting a moment where something ${f.tone.isLight ? 'lighter' : 'less intense'} may be preferable.'
      : 'Matches your taste for $what, and suits your ${state.suggestedExperience.label.toLowerCase()} mood.';

  return Explanation(
    baseline: baseline,
    context: 'Current context: ${_join(contextParts)}.',
    recommendation: recommendation,
    headline: headline,
  );
}
