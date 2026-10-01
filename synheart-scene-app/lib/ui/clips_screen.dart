import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../app/movie_info_store.dart';
import '../app/scene_cubit.dart';
import '../engine/recommender.dart';
import 'home_rows.dart';
import 'picks.dart';
import 'poster.dart';
import 'theme.dart';

/// Clips: a full-screen vertical feed of tonight's picks, in the order
/// Home ranks them (taste + current state). Swipe up for the next one; tap
/// Play for the trailer.
class ClipsScreen extends StatelessWidget {
  const ClipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<SceneCubit>();
    final picks = Picks.of(context.read<SceneCubit>());
    final ranked = picks.list(limit: 20);
    if (ranked.isEmpty) {
      return const Scaffold(body: Center(child: Text('Build your movie profile to see clips.')));
    }
    return Scaffold(
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: ranked.length,
        itemBuilder: (_, i) => _Clip(ranked[i], rank: i + 1),
      ),
    );
  }
}

class _Clip extends StatelessWidget {
  const _Clip(this.r, {required this.rank});
  final Recommendation r;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = r.film;
    final info = context.watch<MovieInfoStore>()[f.id];
    final trailer = info?.trailerUrl;
    final art = info?.posterUrl(size: 'w780');
    return LayoutBuilder(builder: (context, c) {
      return Stack(fit: StackFit.expand, children: [
        if (art == null)
          Poster(f, width: c.maxWidth, height: c.maxHeight, radius: 0)
        else
          ExcludeSemantics(
            child: CachedNetworkImage(
              imageUrl: art,
              fit: BoxFit.cover,
              placeholder: (_, _) => Poster(f, width: c.maxWidth, height: c.maxHeight, radius: 0),
              errorWidget: (_, _, _) => Poster(f, width: c.maxWidth, height: c.maxHeight, radius: 0),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.2, 0.55, 1],
              colors: [Color(0x99000000), Colors.transparent, Colors.transparent, Color(0xE6000000)],
            ),
          ),
        ),
        Center(
          child: IconButton(
            tooltip: trailer == null ? 'Open ${f.title}' : 'Play the trailer of ${f.title}',
            iconSize: 64,
            style: IconButton.styleFrom(backgroundColor: Colors.black38),
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            onPressed: () => trailer == null ? openTitle(context, f, 'clips') : playTrailer(context, f, trailer, 'clips-play'),
          ),
        ),
        // Side actions, as in a short-video feed.
        Positioned(
          right: 12,
          bottom: 210,
          child: Column(children: [
            _Side(child: MyListButton(film: f, compact: true)),
            const SizedBox(height: 14),
            _Side(
              child: TextButton(
                onPressed: () => openTitle(context, f, 'clips-info'),
                child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.info_outline, size: 26), SizedBox(height: 4), Text('Info')]),
              ),
            ),
          ]),
        ),
        Positioned(
          left: 16,
          right: 96,
          bottom: 116,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#$rank ${r.weights.usesState ? 'for you right now' : 'for you today'}'.toUpperCase(),
                style: t.labelSmall?.copyWith(color: SceneColors.accent)),
            const SizedBox(height: 4),
            Text(f.title, style: t.headlineSmall?.copyWith(fontSize: 28)),
            const SizedBox(height: 6),
            Text(['${f.tone.label[0].toUpperCase()}${f.tone.label.substring(1)}', ...f.genres.take(2).map((g) => g.label)].join('  •  '),
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(info?.overview ?? f.logline, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
          ]),
        ),
        Positioned(
          right: 16,
          bottom: 116,
          child: InkWell(
            onTap: () => openTitle(context, f, 'clips-poster'),
            customBorder: const CircleBorder(),
            child: Semantics(
              button: true,
              label: 'Open ${f.title}',
              child: ExcludeSemantics(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 2)),
                  clipBehavior: Clip.antiAlias,
                  child: FittedBox(fit: BoxFit.cover, child: Poster(f, width: 72, height: 104, radius: 0)),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        decoration: const BoxDecoration(color: Color(0x66000000), borderRadius: BorderRadius.all(Radius.circular(32))),
        child: child,
      );
}
