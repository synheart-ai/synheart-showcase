import 'package:flutter/material.dart';

import '../domain/state.dart';
import 'theme.dart';
import 'widgets.dart';

/// The plan's example state card (§4): Energy, Mental load, Engagement and
/// Suggested experience, in plain words. The underlying Synheart readings are
/// one tap away under Details, never the headline.
class StateCard extends StatelessWidget {
  const StateCard({super.key, required this.reading});

  final CurrentState reading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final need = reading.suggestedExperience;
    Widget row(String label, String value, {bool strong = false, bool low = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: t.titleMedium),
                if (low) const LowConfidenceTag(),
              ]),
            ),
            Text(value, style: (strong ? t.titleMedium : t.bodyLarge)?.copyWith(color: strong ? SceneColors.ink : SceneColors.sage)),
          ]),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in PlainSignal.values)
              row(p.label, reading.levelOf(p)?.label ?? 'Not available', low: reading.levelOf(p) != null && reading.isLowConfidenceSignal(p)),
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
                      child: Row(children: [
                        Expanded(child: Text('${a.label} reading', style: t.bodyMedium)),
                        Text(
                          reading.valueOf(a) == null
                              ? 'not available'
                              : '${SignalLevel.of(reading.valueOf(a)!).label.toLowerCase()}${reading.reading(a)!.isLowConfidence ? ' (low confidence)' : ''}',
                          style: t.bodyMedium?.copyWith(color: SceneColors.sage),
                        ),
                      ]),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: Text(
                      'Energy comes from arousal, mental load from stress and capacity, engagement from focus. '
                      'Readings Synheart is not confident about are marked low confidence. This mapping is provisional.',
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
