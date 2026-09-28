import 'package:flutter/material.dart';

import '../domain/film.dart';
import 'theme.dart';

/// A typographic poster: no image rights needed for the demo. The colour
/// follows the film's tone so the grid reads at a glance.
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
    final c = colorFor(film.tone);
    return Container(
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
    );
  }
}
