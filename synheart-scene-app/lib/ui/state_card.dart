import 'package:flutter/material.dart';

import '../domain/state.dart';
import 'theme.dart';
import 'widgets.dart';

/// The plan's example state card (§4): Energy, Mental load, Engagement, plus
/// Tiredness, Interruptions and Mood from the behavior axes, and Suggested
/// experience, in plain words. A signal Synheart could not produce says why.
/// Every underlying HSI value is one tap away under Details, never the
/// headline.
class StateCard extends StatelessWidget {
  const StateCard({super.key, required this.reading});

  final CurrentState reading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final need = reading.suggestedExperience;
    String raw(HsiAxis a) {
      final r = reading.reading(a);
      if (r == null || !r.isAvailable) return reading.whyUnavailable(a) ?? 'not available';
      final note = switch (reading.directionOf(a)) {
        HsiDirection.lowerIsMore => ' (lower means more)',
        HsiDirection.bidirectional => ' (neither end is better)',
        HsiDirection.higherIsMore => '',
      };
      return '${r.value.toStringAsFixed(2)}$note · confidence ${r.confidence.toStringAsFixed(2)}';
    }

    final tint = suggestionTint(reading.hasEvidence ? need : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The suggestion first, tinted like Home's state banner.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tint),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text('Suggested experience', style: t.labelSmall?.copyWith(color: SceneColors.ink)),
                  ),
                  Text(need?.label ?? 'Balanced', style: t.headlineSmall),
                ],
              ),
              if (reading.isLowConfidence) ...[
                const SizedBox(height: 6),
                const LowConfidenceTag(),
                Text('Synheart is not sure about this reading, so treat it lightly.', style: t.bodySmall?.copyWith(color: SceneColors.body)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in PlainSignal.values)
                  SizedBox(
                    width: w,
                    child: _SignalTile(reading: reading, signal: p),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Details', style: t.bodyMedium),
            subtitle: Text('Provisional labels, from Synheart readings', style: t.bodySmall?.copyWith(color: SceneColors.sage)),
            children: [
              for (final a in HsiAxis.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(a.label, style: t.bodyMedium)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          raw(a),
                          textAlign: TextAlign.end,
                          style: t.bodyMedium?.copyWith(color: SceneColors.sage),
                        ),
                      ),
                    ],
                  ),
                ),
              if (reading.basisLabel != null || reading.contextLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [
                      if (reading.basisLabel != null) 'Read from ${reading.basisLabel}.',
                      if (reading.contextLabel != null)
                        "Synheart's activity guess: ${reading.contextLabel}${reading.appCategory == null ? '' : ' (app type ${reading.appCategory})'}. Not used for picks.",
                    ].join(' '),
                    style: t.bodySmall?.copyWith(color: SceneColors.sage),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10),
                child: Text(
                  'Energy comes from arousal; mental load from stress, capacity and cognitive load; engagement from '
                  'focus and focus quality; tiredness from mental fatigue and sleep; interruptions from interruption '
                  'pressure; mood from valence. Interaction mode is shown but not used. Readings Synheart is not '
                  'confident about are marked low confidence. This mapping is provisional.',
                  style: t.bodySmall?.copyWith(color: SceneColors.sage),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The tint of a suggestion, in the theme's own colours: a deep red to
/// black for any suggestion (its name says which), charcoal for Balanced.
/// Shared by Home's state banner, the state card and the sheet.
List<Color> suggestionTint(Experience? e) =>
    e == null ? const [Color(0xFF3A3A3A), Color(0xFF1A1A1A)] : const [Color(0xFF6B0F16), Color(0xFF1A0507)];

/// One plain signal: its name and level, a three-step meter, and either a
/// "low confidence" note or why it is not available.
class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.reading, required this.signal});
  final CurrentState reading;
  final PlainSignal signal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final level = reading.levelOf(signal);
    final available = level != null;
    final low = available && reading.isLowConfidenceSignal(signal);
    final why = reading.whyUnavailableSignal(signal);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The name small and grey, the level large: nothing wraps mid-word.
          Text(signal.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(
            available ? signal.levelLabel(level) : 'Not available',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: available ? t.titleLarge?.copyWith(fontWeight: FontWeight.w800) : t.titleSmall?.copyWith(color: SceneColors.sage),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: available && i <= level.index ? (low ? SceneColors.red.withValues(alpha: 0.55) : SceneColors.red) : Colors.white12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (low) ...[const SizedBox(height: 8), const LowConfidenceTag()] else if (why != null) ...[const SizedBox(height: 8), Text(why, style: t.bodySmall)],
        ],
      ),
    );
  }
}
