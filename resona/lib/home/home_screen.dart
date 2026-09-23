import 'package:flutter/material.dart';

import '../player/player_screen.dart';
import '../state/resona_state_engine.dart';

const _lime = Color(0xFFB9FF28);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openTrack(BuildContext context, int index, {bool autoplay = false}) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, animation, secondaryAnimation) =>
            PlayerScreen(initialIndex: index, autoplay: autoplay),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween(begin: .975, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        const Positioned.fill(child: _HomeBackdrop()),
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                sliver: SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: ResonaStateEngine.instance,
                    builder: (context, _) {
                      final state =
                          ResonaStateEngine.instance.displayRecommendation;
                      return _HomeHeader(
                        stateLabel: state.label,
                        stateAsset: state.stateAsset,
                        onStateTap: () => _openStateSheet(context),
                      );
                    },
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(22, 32, 22, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Music that\nunderstands you.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: .98,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.8,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                sliver: SliverToBoxAdapter(
                  child: _FlowCard(onTap: () => _openTrack(context, 0)),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(22, 31, 22, 11),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your soundtrack',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.35,
                        ),
                      ),
                      Text(
                        '10 TRACKS',
                        style: TextStyle(
                          color: Color(0xFF6C6E6D),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                sliver: SliverList.builder(
                  itemCount: resonaTracks.length,
                  itemBuilder: (context, index) => _StaggeredTrack(
                    index: index,
                    child: _TrackTile(
                      track: resonaTracks[index],
                      onTap: () => _openTrack(context, index),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 34)),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: resonaPlayback,
          builder: (context, _) {
            if (!resonaPlayback.playing) return const SizedBox.shrink();
            return Positioned(
              left: 16,
              right: 16,
              bottom: 10 + MediaQuery.paddingOf(context).bottom,
              child: _NowPlayingBar(
                track: resonaPlayback.track,
                onTap: () => _openTrack(context, resonaPlayback.trackIndex),
                onPause: resonaPlayback.pause,
              ),
            );
          },
        ),
      ],
    ),
  );

  void _openStateSheet(BuildContext context) {
    final homeContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AnimatedBuilder(
        animation: ResonaStateEngine.instance,
        builder: (context, _) {
          final engine = ResonaStateEngine.instance;
          final state = engine.displayRecommendation;
          final heartRate = engine.heartRateBpm;
          return Container(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              22 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF111312),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3C3B),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'CURRENT STATE',
                        style: TextStyle(
                          color: Color(0xFF6F7270),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(homeContext).pushNamed('/settings');
                          },
                          tooltip: 'Settings',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: .055,
                            ),
                            foregroundColor: const Color(0xFF969A98),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: .07),
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  child: Image.asset(
                    state.stateAsset,
                    key: ValueKey(state.stateAsset),
                    width: 110,
                    height: 110,
                  ),
                ),
                Text(
                  state.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF929493),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .055),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .07),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: _lime,
                        size: 16,
                      ),
                      const SizedBox(width: 7),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          heartRate == null
                              ? '— BPM'
                              : '${heartRate.round()} BPM',
                          key: ValueKey(heartRate?.round()),
                          style: const TextStyle(
                            color: Color(0xFFD5D7D6),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    final targetIndex = state.targetTrackIndex >= 0
                        ? state.targetTrackIndex
                        : resonaPlayback.trackIndex;
                    Navigator.pop(context);
                    _openTrack(homeContext, targetIndex, autoplay: true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _lime,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                    shape: const StadiumBorder(),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue listening',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 9),
                      Icon(Icons.headphones_rounded, size: 19),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(.85, -1),
        radius: 1.15,
        colors: [Color(0xFF183023), Color(0xFF09100D), Colors.black],
        stops: [0, .42, 1],
      ),
    ),
  );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.stateLabel,
    required this.stateAsset,
    required this.onStateTap,
  });

  final String stateLabel;
  final String stateAsset;
  final VoidCallback onStateTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text(
        'RESONA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.1,
        ),
      ),
      const Spacer(),
      InkWell(
        onTap: onStateTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 43,
          padding: const EdgeInsets.fromLTRB(6, 5, 13, 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: .72, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: Image.asset(
                  stateAsset,
                  key: ValueKey(stateAsset),
                  width: 31,
                  height: 31,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                stateLabel.toUpperCase(),
                style: const TextStyle(
                  color: _lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Ink(
      height: 135,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF202522), Color(0xFF111412)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Hero(
              tag: resonaTracks.first.objectKey,
              transitionOnUserGestures: true,
              createRectTween: (begin, end) =>
                  MaterialRectCenterArcTween(begin: begin, end: end),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.asset(
                  resonaTracks.first.artwork,
                  width: 115,
                  height: 115,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MADE FOR YOUR STATE',
                  style: TextStyle(
                    color: _lime,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.05,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Flow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Supporting sustained focus',
                  style: TextStyle(color: Color(0xFF8E918F), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 45,
            height: 45,
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              color: _lime,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.black,
              size: 28,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StaggeredTrack extends StatelessWidget {
  const _StaggeredTrack({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 380 + _min(index, 6) * 55),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

int _min(int a, int b) => a < b ? a : b;

class _TrackTile extends StatelessWidget {
  const _TrackTile({required this.track, required this.onTap});

  final ResonaTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      leading: track.objectKey == resonaTracks.first.objectKey
          ? _TileArtwork(track: track)
          : Hero(
              tag: track.objectKey,
              transitionOnUserGestures: true,
              createRectTween: (begin, end) =>
                  MaterialRectCenterArcTween(begin: begin, end: end),
              child: _TileArtwork(track: track),
            ),
      title: Text(
        track.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -.2,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          track.support,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF777A78), fontSize: 12),
        ),
      ),
      trailing: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Color(0xFFD0D2D1),
          size: 22,
        ),
      ),
    ),
  );
}

class _TileArtwork extends StatelessWidget {
  const _TileArtwork({required this.track});

  final ResonaTrack track;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset(track.artwork, width: 59, height: 59, fit: BoxFit.cover),
  );
}

class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({
    required this.track,
    required this.onTap,
    required this.onPause,
  });

  final ResonaTrack track;
  final VoidCallback onTap;
  final Future<void> Function() onPause;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xF21A1D1B),
    elevation: 14,
    shadowColor: Colors.black,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.asset(
                track.artwork,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF858886),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => onPause(),
              icon: const Icon(Icons.pause_rounded, color: _lime, size: 27),
            ),
          ],
        ),
      ),
    ),
  );
}
