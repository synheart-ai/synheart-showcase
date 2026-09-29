import '../domain/state.dart';
import 'recommender.dart';

String _level(double v, {required String low, required String moderate, required String high}) =>
    v < 0.36 ? low : (v < 0.66 ? moderate : high);

String _join(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

String _pct(double w) => '${(w * 100).round()}%';

/// "Why this movie?" in the RFC's three parts (§8): *Your taste*, *Right
/// now*, and *How that affected this pick*. Every sentence is built from the
/// film's contribution record — its weights, scores and catalogue tags — so
/// it never claims something the ranking did not do.
class Explanation {
  const Explanation({required this.taste, required this.rightNow, required this.effect, required this.headline});

  /// What in the user's own ratings and picks this film matches.
  final String taste;

  /// What the check-in and the user's choices asked for tonight — or null
  /// when neither played a part.
  final String? rightNow;

  /// How the inputs were weighed for this film.
  final String effect;

  /// The short line on the pick card.
  final String headline;
}

/// [state] is null when the list is taste only — including when no reading was
/// taken, it is stale, or no axis had enough confidence. [usualIntensity] is the intensity of the films
/// the user usually enjoys; intensity is described relative to it.
/// [tasteOnlyRank] is the film's place on taste alone, when known.
Explanation explain(
  Recommendation r, {
  CurrentState? state,
  ViewingContext viewing = const ViewingContext(),
  double? usualIntensity,
  int? tasteOnlyRank,
}) {
  final f = r.film;
  final w = r.weights;
  final genres = r.matchedGenres.take(3).map((g) => g.label.toLowerCase()).toList();
  final traits = r.matchedTraits.take(2).map((t) => t.label).toList();
  final tasteParts = [...genres, ...traits];
  final taste = tasteParts.isEmpty
      ? 'Close to the films you rated well.'
      : 'You rate ${_join(tasteParts)} highly, and this film has ${tasteParts.length == 1 ? 'it' : 'them'}.';

  final choices = <String>[
    if (viewing.intent != null) 'You chose "${viewing.intent!.label}"${w.usesState ? ', which takes precedence over your current state' : ''}.',
    if (viewing.maxRuntimeMinutes != null) 'You asked for ${viewing.maxRuntimeMinutes} minutes or less; this film runs ${f.runtimeMinutes}.',
  ];

  if (!w.usesState) {
    final effect = w.usesContext
        ? 'Ranked on taste (${_pct(w.taste)}) and your choice of evening (${_pct(w.context)}). No current state was used.'
        : 'Ranked on your taste alone — the way a conventional recommender would. No current state was used.';
    return Explanation(
      taste: taste,
      rightNow: choices.isEmpty ? null : choices.join(' '),
      effect: effect,
      headline: '${r.fitLabel}${genres.isEmpty ? '' : ': ${_join(genres)}'}.',
    );
  }

  final st = state!;
  final t = StateTargets.from(st);
  final delta = usualIntensity == null ? 0.0 : f.intensity - usualIntensity;
  final intensity = delta <= -0.2
      ? 'lower intensity than you usually choose'
      : delta >= 0.2
          ? 'more intense than you usually choose'
          : _level(f.intensity, low: 'lower intensity', moderate: 'moderate intensity', high: 'high intensity');
  final thinking = _level(f.cognitiveLoad, low: 'an easy watch', moderate: 'moderate cognitive engagement', high: 'a demanding watch');
  final tone = f.tone.isLight ? 'entertaining rather than emotionally heavy' : 'a ${f.tone.label} tone';
  final (source, s) = switch (st.source) {
    StateSource.synheart => ('Your wearable readings', ''),
    StateSource.wearSim => ('The WearSim demo readings', ''),
    StateSource.preset => ('The demo data', 's'),
  };
  // In the plan's plain language, not raw HSI axis names.
  final used = [for (final p in PlainSignal.values) if (st.plain(p) != null) '${p.label.toLowerCase()} (${st.levelOf(p)!.label.toLowerCase()})'];
  final missing = [for (final p in PlainSignal.values) if (st.plain(p) == null) p.label.toLowerCase()];
  final basis = 'Based on ${_join(used)}${missing.isEmpty ? '' : ' (${_join(missing)} not available)'}.';
  final need = st.suggestedExperience;
  final rightNow = [
    need == null
        ? '$source show$s no clear need tonight, so ${s.isEmpty ? 'they' : 'it'} only nudge$s the ranking. $basis'
        : '$source suggest$s this may be ${need.phrase}. $basis',
    'This film is ${_join([intensity, thinking, tone])}.',
    ...choices,
  ].join(' ');

  final moved = tasteOnlyRank == null
      ? ''
      : tasteOnlyRank > 5
          ? ' On taste alone it was #$tasteOnlyRank; tonight\'s context brought it into the list.'
          : ' On taste alone it was #$tasteOnlyRank.';
  final effect = 'Taste counted for ${_pct(w.taste)}, your current state for ${_pct(w.state)} and your choices for ${_pct(w.context)}. '
      'Support: ${supportLabel(r.taste).toLowerCase()} on taste, ${supportLabel(r.state).toLowerCase()} for right now.$moved';

  final what = traits.isNotEmpty ? traits.first : (genres.isNotEmpty ? '${genres.first} stories' : 'the films you like');
  final headline = t.prefersLightTone
      ? 'Keeps your taste for $what, and something ${f.tone.isLight ? 'lighter' : 'less intense'} may suit tonight.'
      : need == null
          ? 'Keeps your taste for $what, and fits how tonight looks.'
          : 'Keeps your taste for $what, and may suit ${need.phrase}.';

  return Explanation(taste: taste, rightNow: rightNow, effect: effect, headline: headline);
}

/// "just now", "12 min ago", "1 h 5 min ago" — the age of a state snapshot.
String ageLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  final m = d.inMinutes % 60;
  return '${d.inHours} h${m == 0 ? '' : ' $m min'} ago';
}
