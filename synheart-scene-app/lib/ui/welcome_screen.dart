import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../data/demo_persona.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 1 — the promise: find the right movie for right now.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasProfile = context.select((SceneCubit c) => c.state.hasProfile);

    return Scaffold(
      body: PageBody(
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasProfile) ...[
              FilledButton(onPressed: () => context.push(Routes.tonight), child: const Text("Tonight's picks")),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => context.push(Routes.dna), child: const Text('See my Movie DNA')),
              TextButton(
                onPressed: () => confirmReset(context, onReset: context.read<SceneCubit>().reset),
                child: const Text('Reset demo'),
              ),
            ] else ...[
              FilledButton(onPressed: () => context.push(Routes.profile), child: const Text('Build my movie profile')),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  context.read<SceneCubit>().useAnswers(demoPersonaAnswers);
                  context.push(Routes.dna);
                },
                child: const Text('Try the demo profile'),
              ),
            ],
          ],
        ),
        children: [
          const SizedBox(height: 24),
          const Row(children: [Expanded(child: Eyebrow('Scene')), SettingsButton()]),
          const SizedBox(height: 12),
          // The wordmark; its semantics label keeps the app's name for screen readers.
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset('assets/scene_logo.png', height: 72, semanticLabel: 'Scene by Synheart'),
          ),
          const SizedBox(height: 8),
          Container(height: 2, width: 64, color: SceneColors.accent),
          const SizedBox(height: 28),
          Text('Taste tells us what you like.', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Your state helps us understand what might fit right now.', style: t.titleLarge?.copyWith(color: SceneColors.sage)),
          const SizedBox(height: 28),
          const Callout(
            title: 'Find the right movie for right now',
            child: Text(
              'First, Scene learns what you normally enjoy. Then a short Synheart check-in adds '
              'context about this moment — so your picks fit tonight, without changing who you are.',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.favorite_border, size: 16, color: SceneColors.sage),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Powered by Synheart — reads your heart rhythm on this device during a short check-in. '
                  'Nothing is collected until you agree, and raw heart data is never stored.',
                  style: t.bodyMedium?.copyWith(color: SceneColors.sage),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
