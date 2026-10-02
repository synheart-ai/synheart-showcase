import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/demo_log.dart';
import '../app/movie_info_store.dart';
import '../app/scene_cubit.dart';
import '../domain/film.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'poster.dart';
import 'routes.dart';
import 'theme.dart';

/// Search: the whole catalogue, in tonight's order — ranked by taste, and
/// by the current state when one is in use — filtered by title, genre or
/// logline as you type.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  var _query = '';

  static bool _matches(Film f, String q) {
    if (q.isEmpty) return true;
    final needle = q.toLowerCase();
    return f.title.toLowerCase().contains(needle) ||
        f.logline.toLowerCase().contains(needle) ||
        f.genres.any((g) => g.label.toLowerCase().contains(needle));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    context.watch<SceneCubit>();
    final picks = Picks.of(context.read<SceneCubit>());
    final ranked = picks.list(limit: 1000).where((r) => _matches(r.film, _query.trim())).toList();
    final heading = _query.trim().isEmpty
        ? (picks.withState ? 'Recommended for You Right Now' : 'Recommended Movies')
        : '${ranked.length} ${ranked.length == 1 ? 'match' : 'matches'}';

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: false,
          style: t.bodyLarge?.copyWith(color: SceneColors.ink),
          cursorColor: SceneColors.ink,
          decoration: InputDecoration(
            hintText: 'Search films, genres…',
            hintStyle: t.bodyLarge?.copyWith(color: SceneColors.sage),
            prefixIcon: const Icon(Icons.search, color: SceneColors.sage),
            filled: true,
            fillColor: SceneColors.panel,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(heading, style: t.titleLarge),
            const SizedBox(height: 10),
            if (ranked.isEmpty)
              Text('No film matches "$_query".', style: t.bodyMedium?.copyWith(color: SceneColors.sage))
            else
              for (final r in ranked) _ResultRow(r),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.r);
  final Recommendation r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = r.film;
    final backdrop = context.watch<MovieInfoStore>()[f.id]?.backdropUrl(size: 'w300');
    return Semantics(
      button: true,
      label: '${f.title}, ${f.year}. ${r.fit.label}. Why this movie?',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () {
            context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': f.id, 'from': 'search'});
            context.push(Routes.why(f.id));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 140,
                  height: 78,
                  child: backdrop == null
                      ? FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: Poster(f, width: 140, height: 200, radius: 0))
                      : CachedNetworkImage(
                          imageUrl: backdrop,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const ColoredBox(color: SceneColors.panel),
                          errorWidget: (_, _, _) => Poster(f, width: 140, height: 78, radius: 0),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.title, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${f.year} · ${r.fit.label}', style: t.bodySmall),
                ]),
              ),
              const Icon(Icons.play_circle_outline, size: 36, color: SceneColors.ink),
            ]),
          ),
        ),
      ),
    );
  }
}
