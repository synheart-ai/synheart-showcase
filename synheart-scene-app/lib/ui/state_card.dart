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
    Widget row(String label, String value, {bool strong = false, bool low = false, String? why}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: t.titleMedium),
                if (low) const LowConfidenceTag(),
                if (why != null) Text(why, style: t.bodySmall?.copyWith(color: SceneColors.sage)),
              ]),
            ),
            Text(value, style: (strong ? t.titleMedium : t.bodyLarge)?.copyWith(color: strong ? SceneColors.ink : SceneColors.sage)),
          ]),
        );
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in PlainSignal.values)
              row(
                p.label,
                reading.levelOf(p) == null ? 'Not available' : p.levelLabel(reading.levelOf(p)!),
                low: reading.levelOf(p) != null && reading.isLowConfidenceSignal(p),
                why: reading.whyUnavailableSignal(p),
              ),
            const Divider(height: 18),
            row('Suggested experience', need?.label ?? 'No clear need', strong: true, low: reading.isLowConfidence),
            if (reading.isLowConfidence)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Synheart is not sure about this reading, so treat it lightly.', style: t.bodySmall?.copyWith(color: SceneColors.sage)),
              ),
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
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Text(a.label, style: t.bodyMedium)),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(raw(a), textAlign: TextAlign.end, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                        ),
                      ]),
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
        ),
      ),
    );
  }
}
