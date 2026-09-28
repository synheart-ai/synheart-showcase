import 'package:flutter/material.dart';

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

/// Placeholder for screens that are built in a later step.
class ComingNext extends StatelessWidget {
  const ComingNext(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Coming in the next build step.')),
      );
}
