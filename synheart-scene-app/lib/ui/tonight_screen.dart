import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../data/catalogue.dart';
import '../domain/film.dart';
import '../domain/state.dart';
import '../domain/taste.dart';
import '../engine/collections.dart';
import 'home_rows.dart';
import 'picks.dart';
import 'routes.dart';
import 'state_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Home — a state-aware cinema home. Everything on it is ranked by taste and,
/// whenever a usable reading exists, by the current HSI state; there is no
/// taste-only switch (product decision, 2026-10-01).
class TonightScreen extends StatefulWidget {
  const TonightScreen({super.key});

  @override
  State<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends State<TonightScreen> {
  Genre? _genre;

  static String rowTitle(Genre g) => switch (g) {
    Genre.comedy => 'Movies That Make You Laugh',
    Genre.thriller => 'Edge-of-Your-Seat Thrillers',
    Genre.sciFi => 'Mind-Bending Sci-Fi',
    Genre.crime => 'Crime Movies',
    Genre.action => 'Action Movies',
    Genre.drama => 'Dramas',
    Genre.horror => 'Scary Movies',
    Genre.documentary => 'Documentaries',
    Genre.romance => 'Romantic Movies',
    Genre.animation => 'Animated Movies',
    _ => '${g.label} Movies',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<SceneCubit>().state;
    final cubit = context.read<SceneCubit>();

    if (s.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.push(Routes.profile), child: const Text('Build my movie profile')),
          children: const [Callout(child: Text('Scene needs your movie profile first.'))],
        ),
      );
    }

    final picks = Picks.of(cubit);
    final all = picks.list(limit: 1000).where((r) => _genre == null || r.film.genres.contains(_genre)).toList();
    final need = picks.hasUsableState ? picks.state!.suggestedExperience : null;
    final loved = [
      for (final e in s.answers.ratings.entries)
        if (e.value == Rating.love) ?filmById(e.key),
    ];
    final because = loved.isEmpty ? null : loved.first;

    return LogOnShow(
      event: DemoEvent.recommendationsViewed,
      fields: {'mode': picks.mode.name, 'stale': '${picks.isStale}'},
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            children: [
              Image.asset('assets/scene_mark.png', height: 36, semanticLabel: 'Scene'),
              const SizedBox(width: 14),
              const Flexible(
                child: Text(
                  'Home',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          actions: const [StatePill(), SettingsButton(), SizedBox(width: 4)],
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              _ChipRow(genre: _genre, onGenre: (g) => setState(() => _genre = g), onMyList: () => context.go(Routes.myScene)),
              const SizedBox(height: 12),
              const BuildProfileCard(),
              const SizedBox(height: 12),
              if (all.isEmpty)
                const Callout(child: Text('Nothing fits these filters — try removing one.'))
              else ...[
                HeroPick(recommendation: all.first, tagline: all.first.fitLabel),
                PosterRow(
                  title: picks.withState ? 'Top Picks for Right Now' : "Today's Top Picks for You",
                  from: 'top-picks',
                  films: [for (final r in all.skip(1).take(10)) r.film],
                  badges: {for (final r in all.skip(1).take(3)) r.film.id: need?.label ?? r.fit.label},
                ),
                StateBanner(picks: picks, films: all.skip(1).take(3).toList()),
                TopRow(title: picks.withState ? 'Top 10 for You Right Now' : 'Top 10 for You Today', picks: all.take(10).toList()),
                if (because != null && _genre == null)
                  PosterRow(
                    title: 'Because you loved ${because.title}',
                    from: 'because-${because.id}',
                    films: [
                      for (final r in all)
                        if (r.film.genres.any(because.genres.contains)) r.film,
                    ].take(10).toList(),
                  ),
                if (picks.withState && _genre == null)
                  for (final e in buildCollections(s.profile!, state: picks.state!, context: s.viewing, hidden: s.hiddenFilmIds).entries)
                    PosterRow(title: e.key.title, from: e.key.name, films: e.value),
                for (final g in (_genre == null ? s.profile!.rankedGenres.take(3).map((e) => e.key) : [_genre!]))
                  PosterRow(
                    title: rowTitle(g),
                    from: 'genre-${g.name}',
                    films: [
                      for (final r in all)
                        if (r.film.genres.contains(g)) r.film,
                    ].take(12).toList(),
                  ),
                const SizedBox(height: 24),
                Text('Ranked on your taste${picks.withState ? ' and your current state' : ''}.', textAlign: TextAlign.center, style: t.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The chip row under the header: Movies, My List and Categories ▾ (genres
/// and "Tonight I want…"), as a cinema app's Shows / Movies / Categories.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.genre, required this.onGenre, required this.onMyList});

  final Genre? genre;
  final ValueChanged<Genre?> onGenre;
  final VoidCallback onMyList;

  @override
  Widget build(BuildContext context) {
    final viewing = context.select((SceneCubit c) => c.state.viewing);
    Widget chip(String label, VoidCallback onTap, {bool selected = false, IconData? trailing}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (trailing != null) ...[const SizedBox(width: 4), Icon(trailing, size: 18, color: selected ? SceneColors.paper : SceneColors.ink)],
          ],
        ),
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: selected ? SceneColors.paper : SceneColors.ink),
        backgroundColor: selected ? SceneColors.ink : SceneColors.paper,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFF808080))),
        onPressed: onTap,
      ),
    );
    final intent = viewing.intent;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (genre != null) chip(genre!.label, () => onGenre(null), selected: true, trailing: Icons.close),
          if (intent != null) chip(intent.label, () => context.read<SceneCubit>().setIntent(null), selected: true, trailing: Icons.close),
          if (genre == null) chip('Movies', () => onGenre(null)),
          chip('My List', onMyList),
          chip('Categories', () => _showCategories(context, onGenre), trailing: Icons.keyboard_arrow_down),
        ],
      ),
    );
  }
}

Future<void> _showCategories(BuildContext context, ValueChanged<Genre?> onGenre) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xF2232323),
  builder: (sheet) {
    final t = Theme.of(sheet).textTheme;
    final cubit = context.read<SceneCubit>();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text('Tonight I want…', style: t.labelSmall),
          for (final i in EveningIntent.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(i.label, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
              trailing: cubit.state.viewing.intent == i ? const Icon(Icons.check) : null,
              onTap: () {
                cubit.setIntent(cubit.state.viewing.intent == i ? null : i);
                Navigator.pop(sheet);
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('90 minutes or less', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
            trailing: cubit.state.viewing.maxRuntimeMinutes != null ? const Icon(Icons.check) : null,
            onTap: () {
              cubit.setShortOnly(cubit.state.viewing.maxRuntimeMinutes == null);
              Navigator.pop(sheet);
            },
          ),
          const SizedBox(height: 16),
          Text('Categories', style: t.labelSmall),
          for (final g in Genre.values)
            if (candidateFilms.any((f) => f.genres.contains(g)))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(g.label, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
                onTap: () {
                  onGenre(g);
                  Navigator.pop(sheet);
                },
              ),
        ],
      ),
    );
  },
);
