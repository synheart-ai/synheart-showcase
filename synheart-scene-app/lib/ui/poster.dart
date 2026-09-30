import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/movie_info_store.dart';
import '../domain/film.dart';
import 'theme.dart';

/// The film's TMDB poster when one is available, otherwise a typographic
/// poster. The typographic one is also the placeholder while the image
/// loads and the fallback offline or on error, so the demo never shows an
/// empty tile. Images are cached on disk after the first load.
class Poster extends StatelessWidget {
  const Poster(this.film, {super.key, this.width = 72, this.height = 104});

  final Film film;
  final double width;
  final double height;

  static Color colorFor(Tone t) => switch (t) {
        Tone.playful => const Color(0xFFC9803D),
        Tone.uplifting => const Color(0xFF4F8A6B),
        Tone.bittersweet => const Color(0xFF7A6A9A),
        Tone.tense => const Color(0xFF3E5C76),
        Tone.dark => const Color(0xFF26323A),
        Tone.heavy => const Color(0xFF4A3A3A),
      };

  @override
  Widget build(BuildContext context) {
    final url = context.watch<MovieInfoStore>()[film.id]?.posterUrl(size: width > 140 ? 'w500' : 'w342');
    final fallback = _typographic();
    if (url == null) return fallback;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }

  Widget _typographic() {
    final c = colorFor(film.tone);
    // Decorative: the title is always shown (and read) next to the poster, or
    // the tappable poster carries its own label. Excluding it stops screen
    // readers announcing every title twice.
    return ExcludeSemantics(
      child: Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, Color.lerp(c, SceneColors.ink, 0.55)!]),
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        film.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Georgia', color: Colors.white, fontSize: width / 6.5, height: 1.1, fontWeight: FontWeight.w600),
      ),
      ),
    );
  }
}
