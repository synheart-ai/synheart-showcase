import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../data/catalogue.dart';
import '../data/demo_persona.dart';
import 'poster.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 1 — the promise, as a streaming app's landing screen: a tilted
/// wall of the catalogue's posters behind a dark fade, the wordmark, and
/// the two ways in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasProfile = context.select((SceneCubit c) => c.state.hasProfile);
    final red = FilledButton.styleFrom(backgroundColor: SceneColors.red, foregroundColor: Colors.white);
    final ghost = OutlinedButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      side: const BorderSide(color: Colors.white54),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _PosterWall(),
          // Fade the wall to black at the top (for the wordmark) and from the
          // middle down (for the text), so every line keeps its contrast.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.18, 0.42, 0.62, 1],
                colors: [Color(0xE6000000), Color(0x66000000), Color(0x8C000000), Color(0xF2000000), Colors.black],
              ),
            ),
          ),
          SafeArea(
            // Scrolls when the screen is short (landscape, large text); otherwise
            // the text and buttons sit at the bottom, under the wall.
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            // The wordmark; its semantics label keeps the app's name for screen readers.
                            Image.asset('assets/scene_logo_light.png', height: 34, semanticLabel: 'Scene by Synheart'),
                            const Spacer(),
                            const SettingsButton(),
                          ],
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Movies that fit\nright now.', textAlign: TextAlign.center, style: t.displaySmall?.copyWith(fontSize: 40, height: 1.05)),
                              const SizedBox(height: 14),
                              Text(
                                'Taste tells us what you like.',
                                textAlign: TextAlign.center,
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Your state helps us understand what might fit right now.',
                                textAlign: TextAlign.center,
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w400, color: SceneColors.body),
                              ),
                              const SizedBox(height: 22),
                              if (hasProfile) ...[
                                FilledButton(style: red, onPressed: () => context.go(Routes.tonight), child: const Text("Tonight's picks")),
                                const SizedBox(height: 10),
                                OutlinedButton(style: ghost, onPressed: () => context.push(Routes.dna), child: const Text('See my Movie DNA')),
                                TextButton(
                                  onPressed: () => confirmReset(context, onReset: context.read<SceneCubit>().reset),
                                  child: const Text('Reset demo'),
                                ),
                              ] else ...[
                                FilledButton(style: red, onPressed: () => context.push(Routes.profile), child: const Text('Build my movie profile')),
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  style: ghost,
                                  onPressed: () {
                                    context.read<SceneCubit>().useAnswers(demoPersonaAnswers);
                                    context.push(Routes.dna);
                                  },
                                  child: const Text('Try the demo profile'),
                                ),
                                const SizedBox(height: 14),
                              ],
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(Icons.favorite, size: 14, color: SceneColors.accent),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Powered by Synheart — after you agree, it reads your heart rate and how you use your phone, '
                                      'on this device, also while Scene is in the background. Nothing is collected until you agree, '
                                      'and raw heart data is never stored.',
                                      style: t.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tilted grid of catalogue posters (TMDB art when loaded, typographic
/// otherwise). Decorative: excluded from semantics and taps. The grid is
/// laid out unconstrained (UnconstrainedBox) and clipped, so it can run past
/// the screen on every side without an overflow.
class _PosterWall extends StatelessWidget {
  const _PosterWall();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, c) {
          const columns = 5;
          final w = c.maxWidth / 3.1;
          final h = w * 1.5;
          const films = candidateFilms;
          final rows = (c.maxHeight * 1.7 / (h + 10)).ceil() + 1;
          return ClipRect(
            child: OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.rotate(
                angle: -0.21,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < columns; col++)
                      Padding(
                        // Stagger the columns, as on a poster wall.
                        padding: EdgeInsets.only(top: col.isEven ? 0 : h * 0.5, left: 5, right: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var row = 0; row < rows; row++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Poster(films[(col * 7 + row * 3) % films.length], width: w, height: h, radius: 8),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
