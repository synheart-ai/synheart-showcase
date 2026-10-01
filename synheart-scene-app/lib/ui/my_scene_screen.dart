import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../data/catalogue.dart';
import '../domain/taste.dart';
import 'home_rows.dart';
import 'nav_bar.dart';
import 'routes.dart';
import 'state_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// My Scene: the profile tab — your state right now, the films you loved,
/// My List, and the profile sheet (Movie DNA, App Settings, Reset demo).
class MySceneScreen extends StatelessWidget {
  const MySceneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<SceneCubit>().state;
    final view = StateView.of(context);
    final loved = [
      for (final e in s.answers.ratings.entries)
        if (e.value == Rating.love) ?filmById(e.key),
    ];
    final list = [for (final id in s.myList) ?filmById(id)];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          onTap: () => _showProfile(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SceneAvatar(size: 40),
            const SizedBox(width: 12),
            const Text('You', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const Icon(Icons.arrow_drop_down, size: 32),
            ]),
          ),
        ),
        actions: const [SettingsButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            // Where a cinema app puts Downloads: your state right now.
            Material(
              color: SceneColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: SceneColors.line)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => showStateSheet(context),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(view.icon, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Right now: ${view.label}', style: t.titleLarge),
                        const SizedBox(height: 6),
                        Text(view.message, style: t.bodyLarge?.copyWith(color: SceneColors.sage)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, size: 30),
                  ]),
                ),
              ),
            ),
            PosterRow(title: "Movies You've Loved", from: 'loved', films: loved),
            if (list.isEmpty) ...[
              const SizedBox(height: 26),
              Text('My List', style: t.titleLarge),
              const SizedBox(height: 6),
              Text('Tap + My List on any title to save it here.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
            ] else
              PosterRow(title: 'My List', from: 'my-list', films: list),
          ],
        ),
      ),
    );
  }
}

/// The profile sheet: avatar and name, then Movie DNA, App Settings and
/// Reset demo, as rows.
Future<void> _showProfile(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) {
        final t = Theme.of(sheet).textTheme;
        Widget row(IconData icon, String label, VoidCallback onTap) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(icon, size: 28),
                  title: Text(label, style: t.titleMedium?.copyWith(fontSize: 18)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onTap,
                ),
              ),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Profile', style: t.headlineSmall),
              const SizedBox(height: 18),
              const SceneAvatar(size: 96),
              const SizedBox(height: 10),
              Text('You', style: t.titleLarge),
              const SizedBox(height: 24),
              row(Icons.person_outline, 'Movie DNA', () {
                Navigator.pop(sheet);
                context.push(Routes.dna);
              }),
              row(Icons.settings_outlined, 'App Settings', () {
                Navigator.pop(sheet);
                context.push(Routes.settings);
              }),
              row(Icons.restart_alt, 'Reset demo', () {
                Navigator.pop(sheet);
                confirmReset(context, onReset: () {
                  context.read<SceneCubit>().reset();
                  context.go(Routes.welcome);
                });
              }),
            ]),
          ),
        );
      },
    );
