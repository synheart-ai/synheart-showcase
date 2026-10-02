import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../data/tmdb.dart';
import 'routes.dart';
import 'theme.dart';

/// Small caps label above a title ("SCENE", "YOUR MOVIE DNA" …).
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}

/// The plan's pale green callout box.
class Callout extends StatelessWidget {
  const Callout({super.key, this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: SceneColors.panel, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
            ],
            DefaultTextStyle.merge(style: Theme.of(context).textTheme.bodyMedium, child: child),
          ],
        ),
      );
}

/// The "low confidence" marker for a state label or suggestion built from a
/// reading below Resona's 0.45 (see [AxisReading.isLowConfidence]).
class LowConfidenceTag extends StatelessWidget {
  const LowConfidenceTag({super.key});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.info_outline, size: 14, color: SceneColors.sage),
        const SizedBox(width: 4),
        Flexible(child: Text('low confidence', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SceneColors.sage))),
      ]);
}

/// TMDB's logo with its required attribution (TMDB terms of use).
class TmdbCredit extends StatelessWidget {
  const TmdbCredit({super.key, this.lead = ''});

  /// Text before the attribution, e.g. "Posters, synopses and trailers: TMDB."
  final String lead;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: SceneColors.sage);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Image.asset('assets/tmdb_logo.png', height: 12, semanticLabel: 'The Movie Database (TMDB) logo'),
      const SizedBox(height: 6),
      Text('${lead.isEmpty ? '' : '$lead '}$tmdbAttribution', style: style),
    ]);
  }
}

/// Standard padded, scrollable page body with an optional sticky bottom action.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.bottom});
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: children),
            ),
            if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: bottom),
          ],
        ),
      );
}

/// Opens Settings (consent, wearable source, demo data). On every main
/// screen, so choosing or testing a source is never more than one tap away.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => context.push(Routes.settings),
      );
}

/// Reset demo: clears the stored answers and state snapshot (RFC §9.8),
/// after a confirmation, then returns to Welcome.
Future<void> confirmReset(BuildContext context, {required VoidCallback onReset}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Reset the demo?'),
      content: const Text('This clears your ratings, genres and check-in from this device.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Reset')),
      ],
    ),
  );
  if (ok == true) onReset();
}

/// Records a demo event once, when [child] is first shown (RFC §10).
class LogOnShow extends StatefulWidget {
  const LogOnShow({super.key, required this.event, this.fields = const {}, required this.child});

  final DemoEvent event;
  final Map<String, String> fields;
  final Widget child;

  @override
  State<LogOnShow> createState() => _LogOnShowState();
}

class _LogOnShowState extends State<LogOnShow> {
  @override
  void initState() {
    super.initState();
    context.read<SceneCubit>().log.record(widget.event, widget.fields);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// While Scene runs on the demo profile: the invitation to build your own,
/// for better recommendations.
class BuildProfileCard extends StatelessWidget {
  const BuildProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.select((SceneCubit c) => c.state.demoProfile)) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A0507),
        border: Border.all(color: SceneColors.red.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        const Icon(Icons.person_add_alt_1_outlined, color: SceneColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("You're on a demo profile", style: t.titleSmall),
            Text('Build your profile for better recommendations.', style: t.bodySmall),
          ]),
        ),
        TextButton(
          onPressed: () {
            context.read<SceneCubit>().startOwnProfile();
            context.push(Routes.profile);
          },
          child: const Text('Build'),
        ),
      ]),
    );
  }
}
