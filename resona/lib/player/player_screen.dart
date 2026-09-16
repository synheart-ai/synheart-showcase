import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../platform/resona_live_activity.dart';
import '../state/resona_state_engine.dart';

const _lime = Color(0xFFB9FF28);
const _mediaBase = 'https://resona-media.devefy.workers.dev';

class ResonaTrack {
  const ResonaTrack({
    required this.title,
    required this.artist,
    required this.artwork,
    required this.objectKey,
    required this.accent,
    required this.support,
  });

  final String title;
  final String artist;
  final String artwork;
  final String objectKey;
  final Color accent;
  final String support;

  String get url => '$_mediaBase/$objectKey';

  String get artworkUrl =>
      '$_mediaBase/art/${artwork.substring(artwork.lastIndexOf('/') + 1)}';
}

const resonaTracks = <ResonaTrack>[
  ResonaTrack(
    title: 'No Hook',
    artist: 'Arlo Vale',
    artwork: 'assets/music_art/c7c871ce-1fff-4b6c-9a56-a895d8fc6688.png',
    objectKey: 'music/sub-clair-background-music-591220.mp3',
    accent: Color(0xFFFF5A35),
    support: 'Supporting sustained focus',
  ),
  ResonaTrack(
    title: 'Deep Flow',
    artist: 'Lumen North',
    artwork: 'assets/music_art/8d1aa432-aeaa-41cb-81a8-159153d15146.png',
    objectKey: 'music/maksymmalko-background-music-594961.mp3',
    accent: Color(0xFF1575C9),
    support: 'Protecting your momentum',
  ),
  ResonaTrack(
    title: 'Skyline Focus',
    artist: 'Atlas Bloom',
    artwork: 'assets/music_art/0d8a1ea2-60df-4aed-a0c8-495a6e8b60d6.png',
    objectKey: 'music/soundsurfer-stylish-music-587940.mp3',
    accent: Color(0xFF79B9DF),
    support: 'Keeping attention light',
  ),
  ResonaTrack(
    title: 'Open Signal',
    artist: 'Nova Field',
    artwork: 'assets/music_art/2a7f2586-5cad-4ad3-91c7-017a86763a09.png',
    objectKey: 'music/high-arpmedia-background-music-577823.mp3',
    accent: Color(0xFF7B83EB),
    support: 'Opening creative space',
  ),
  ResonaTrack(
    title: 'Weightless',
    artist: 'Sora Grey',
    artwork: 'assets/music_art/93a28e61-fe48-4de3-9720-dc3c491d04db.png',
    objectKey: 'music/kontraa-no-sleep-hiphop-music-473847.mp3',
    accent: Color(0xFF7C9EB3),
    support: 'Settling into a rhythm',
  ),
  ResonaTrack(
    title: 'After Hours',
    artist: 'Velvet Static',
    artwork: 'assets/music_art/1b36806b-fadc-465b-a41e-42e68d25d3a1.png',
    objectKey:
        'music/alex-morgan-smooth-jazz-lounge-relaxing-evening-537465.mp3',
    accent: Color(0xFF4B58B8),
    support: 'Easing the mental pace',
  ),
  ResonaTrack(
    title: 'Soft Landing',
    artist: 'Elian Moss',
    artwork: 'assets/music_art/ec574bbd-4a52-46c8-a210-9455c4adf47c.png',
    objectKey: 'music/lofi-music-selection.mp3',
    accent: Color(0xFFC8A68A),
    support: 'Supporting a calm reset',
  ),
  ResonaTrack(
    title: 'Still Moving',
    artist: 'Echo Harbor',
    artwork: 'assets/music_art/8cc0a063-b22c-4314-ada9-9e602eb3b58e.png',
    objectKey: 'music/instrumental-lofi-hip-hop.mp3',
    accent: Color(0xFFB9A9C7),
    support: 'Balancing energy and ease',
  ),
  ResonaTrack(
    title: 'Reflection',
    artist: 'Mira Sol',
    artwork: 'assets/music_art/bf9f265c-92cb-4046-ba43-7205b912cb87.png',
    objectKey: 'music/prettyjohn1-background-background-music-581651.mp3',
    accent: Color(0xFF3E8EA9),
    support: 'Making room to think',
  ),
  ResonaTrack(
    title: 'Neon Quiet',
    artist: 'Night Meridian',
    artwork: 'assets/music_art/694319cd-c689-452d-8073-a60ef5b7d293.png',
    objectKey: 'music/vibemode-background-music-581673.mp3',
    accent: Color(0xFF4562B6),
    support: 'Holding a steady pace',
  ),
];

class ResonaPlayback extends ChangeNotifier {
  ResonaPlayback() {
    player.playerStateStream.listen((_) => notifyListeners());
  }

  final AudioPlayer player = AudioPlayer();
  final Map<String, File> _cachedAudio = {};
  Future<void>? _preloadTask;
  int trackIndex = 0;
  bool prepared = false;

  ResonaTrack get track => resonaTracks[trackIndex];
  bool get playing => player.playing;

  File? cachedFileFor(ResonaTrack track) => _cachedAudio[track.objectKey];

  void preloadAdaptiveTracks() {
    _preloadTask ??= _preloadAdaptiveTracks();
  }

  Future<void> _preloadAdaptiveTracks() async {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final cacheDirectory = Directory('${supportDirectory.path}/resona_audio');
      await cacheDirectory.create(recursive: true);
      for (final index in const [1, 2, 6]) {
        final track = resonaTracks[index];
        final fileName = track.objectKey.split('/').last;
        final destination = File('${cacheDirectory.path}/$fileName');
        if (await destination.exists() && await destination.length() > 0) {
          _cachedAudio[track.objectKey] = destination;
          continue;
        }
        final partial = File('${destination.path}.download');
        try {
          if (await partial.exists()) await partial.delete();
          final client = HttpClient();
          try {
            final request = await client.getUrl(Uri.parse(track.url));
            final response = await request.close();
            if (response.statusCode != HttpStatus.ok) {
              throw HttpException(
                'Audio preload returned ${response.statusCode}',
                uri: Uri.parse(track.url),
              );
            }
            await response.pipe(partial.openWrite());
          } finally {
            client.close(force: true);
          }
          await partial.rename(destination.path);
          _cachedAudio[track.objectKey] = destination;
        } catch (_) {
          if (await partial.exists()) await partial.delete();
        }
      }
    } catch (_) {
      // Preloading is an optimization; streaming remains the fallback.
    }
  }

  void selectTrack(int index) {
    trackIndex = index;
    prepared = true;
    notifyListeners();
  }

  Future<void> pause() async {
    await player.pause();
    final state = ResonaStateEngine.instance.displayRecommendation;
    await ResonaLiveActivity.update(
      title: track.title,
      artist: track.artist,
      isPlaying: false,
      state: state.label,
      stateImage: _activityImageFor(state.mode),
    );
  }
}

String _activityImageFor(ResonaAdaptiveMode mode) => switch (mode) {
  ResonaAdaptiveMode.flow => 'd16cbf7e-5125-4b51-ad96-eada0666f402',
  ResonaAdaptiveMode.clarity => 'a863c00f-2322-4277-ab3c-e6efff2c745f',
  ResonaAdaptiveMode.ease => '4081ec38-2646-4ffd-bd52-c5226b4299f7',
};

final resonaPlayback = ResonaPlayback();
bool resonaPlayerVisible = false;

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, this.initialIndex = 0, this.autoplay = false});

  final int initialIndex;
  final bool autoplay;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _player = resonaPlayback.player;
  late final AnimationController _ambientController;
  late final AnimationController _waveController;
  late final AnimationController _bannerController;
  late final Animation<double> _bannerCurve;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _countdownTimer;

  late int _trackIndex;
  int _switchCountdown = 8;
  bool _loading = true;
  bool _showAdaptation = false;
  bool _animateArtworkReveal = false;
  ResonaRecommendation? _pendingRecommendation;
  ResonaAdaptiveMode? _lastOfferedMode;
  ResonaAdaptiveMode? _lastLiveActivityMode;
  String? _error;

  ResonaTrack get _track => resonaTracks[_trackIndex];
  ResonaRecommendation get _state =>
      ResonaStateEngine.instance.displayRecommendation;

  @override
  void initState() {
    super.initState();
    resonaPlayerVisible = true;
    _trackIndex = widget.initialIndex.clamp(0, resonaTracks.length - 1);
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _bannerCurve = CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        unawaited(_changeTrack(1));
      }
      setState(() {});
    });
    _lastOfferedMode = ResonaStateEngine.instance.recommendation?.mode;
    ResonaStateEngine.instance.addListener(_handleStateUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleStateUpdate());
    if (resonaPlayback.prepared && resonaPlayback.trackIndex == _trackIndex) {
      _loading = false;
      if (widget.autoplay && !_player.playing) {
        _playCurrentTrack();
      }
    } else {
      unawaited(
        _prepareTrack(autoplay: widget.autoplay || resonaPlayback.playing),
      );
    }
  }

  void _playCurrentTrack() {
    unawaited(_player.play());
    ResonaStateEngine.instance.recordInteraction();
    _handleStateUpdate();
    unawaited(
      ResonaLiveActivity.start(
        title: _track.title,
        artist: _track.artist,
        isPlaying: true,
        state: _state.label,
        stateImage: _activityImageFor(_state.mode),
      ),
    );
    _lastLiveActivityMode = _state.mode;
  }

  Future<void> _prepareTrack({bool autoplay = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          resonaPlayback.cachedFileFor(_track)?.uri ?? Uri.parse(_track.url),
          tag: MediaItem(
            id: _track.objectKey,
            album: 'Resona · Flow',
            title: _track.title,
            artist: _track.artist,
            artUri: Uri.parse(_track.artworkUrl),
          ),
        ),
      );
      resonaPlayback.selectTrack(_trackIndex);
      if (autoplay) unawaited(_player.play());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Audio is taking a moment to connect.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;
    if (_player.playing) {
      await _player.pause();
      _cancelAdaptationOffer();
      unawaited(
        ResonaLiveActivity.update(
          title: _track.title,
          artist: _track.artist,
          isPlaying: false,
          state: _state.label,
          stateImage: _activityImageFor(_state.mode),
        ),
      );
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      _playCurrentTrack();
    }
  }

  Future<void> _changeTrack(int delta, {bool fromAdaptation = false}) async {
    final wasPlaying = _player.playing;
    _cancelAdaptationOffer();
    if (!fromAdaptation) ResonaStateEngine.instance.recordInteraction();
    const transitionSteps = 12;
    for (var step = transitionSteps; step >= 0; step--) {
      final progress = step / transitionSteps;
      await _player.setVolume(Curves.easeInOut.transform(progress));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    setState(() {
      _trackIndex = (_trackIndex + delta) % resonaTracks.length;
      if (_trackIndex < 0) _trackIndex += resonaTracks.length;
      _animateArtworkReveal = true;
    });
    await _prepareTrack(autoplay: wasPlaying || fromAdaptation);
    unawaited(
      ResonaLiveActivity.update(
        title: _track.title,
        artist: _track.artist,
        isPlaying: wasPlaying || fromAdaptation,
        state: _state.label,
        stateImage: _activityImageFor(_state.mode),
      ),
    );
    for (var step = 1; step <= transitionSteps; step++) {
      final progress = step / transitionSteps;
      await _player.setVolume(Curves.easeInOut.transform(progress));
      await Future<void>.delayed(const Duration(milliseconds: 65));
    }
  }

  void _handleStateUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_player.playing && _lastLiveActivityMode != _state.mode) {
      _lastLiveActivityMode = _state.mode;
      unawaited(
        ResonaLiveActivity.update(
          title: _track.title,
          artist: _track.artist,
          isPlaying: true,
          state: _state.label,
          stateImage: _activityImageFor(_state.mode),
          message: _state.message,
        ),
      );
    }
    final recommendation = ResonaStateEngine.instance.recommendation;
    if (recommendation == null) {
      _lastOfferedMode = null;
      return;
    }
    if (!_player.playing ||
        _showAdaptation ||
        recommendation.targetTrackIndex == _trackIndex ||
        recommendation.mode == _lastOfferedMode) {
      return;
    }
    _pendingRecommendation = recommendation;
    _lastOfferedMode = recommendation.mode;
    _showOffer();
  }

  void _showOffer() {
    if (!mounted || !_player.playing || _pendingRecommendation == null) {
      return;
    }
    setState(() {
      _showAdaptation = true;
      _switchCountdown = 8;
    });
    unawaited(HapticFeedback.lightImpact());
    _bannerController.forward(from: 0);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_switchCountdown <= 1) {
        timer.cancel();
        unawaited(_acceptAdaptation());
      } else {
        setState(() => _switchCountdown--);
      }
    });
  }

  Future<void> _dismissOffer() async {
    _countdownTimer?.cancel();
    await _bannerController.reverse();
    if (mounted) {
      setState(() {
        _showAdaptation = false;
        _pendingRecommendation = null;
      });
    }
  }

  Future<void> _acceptAdaptation() async {
    final recommendation = _pendingRecommendation;
    if (recommendation == null) return;
    unawaited(HapticFeedback.selectionClick());
    await _dismissOffer();
    final delta = recommendation.targetTrackIndex - _trackIndex;
    await _changeTrack(delta, fromAdaptation: true);
    unawaited(
      ResonaLiveActivity.showAdaptation(
        title: _track.title,
        artist: _track.artist,
        state: recommendation.label,
        stateImage: _activityImageFor(recommendation.mode),
      ),
    );
  }

  void _cancelAdaptationOffer() {
    _countdownTimer?.cancel();
    if (_showAdaptation) unawaited(_dismissOffer());
  }

  void _openStateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StateSheet(
        onContinue: () {
          final targetIndex = _state.targetTrackIndex;
          Navigator.pop(context);
          if (targetIndex >= 0 && targetIndex != _trackIndex) {
            unawaited(
              _changeTrack(targetIndex - _trackIndex, fromAdaptation: true),
            );
          } else if (!_player.playing) {
            unawaited(_togglePlayback());
          }
        },
        onOpenDiagnostics: () {
          Navigator.pop(context);
          Navigator.of(this.context).pushNamed('/diagnostics');
        },
      ),
    );
  }

  @override
  void dispose() {
    resonaPlayerVisible = false;
    ResonaStateEngine.instance.removeListener(_handleStateUpdate);
    _countdownTimer?.cancel();
    _playerStateSubscription?.cancel();
    _ambientController.dispose();
    _waveController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 350) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _ambientController,
              builder: (context, child) {
                final drift = _ambientController.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        -0.65 + drift * .25,
                        -0.82 + drift * .08,
                      ),
                      radius: 1.08,
                      colors: [
                        Color.lerp(_track.accent, Colors.black, .61)!,
                        Color.lerp(_track.accent, Colors.black, .84)!,
                        Colors.black,
                      ],
                      stops: const [0, .44, 1],
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 720;
                  final side = compact ? 22.0 : 24.0;
                  final artWidth = math.min(
                    constraints.maxWidth - side * 2,
                    compact
                        ? constraints.maxHeight * .34
                        : constraints.maxHeight * .46,
                  );
                  final artHeight = math.min(
                    artWidth * (compact ? 1.10 : 1.18),
                    constraints.maxHeight * (compact ? .39 : .56),
                  );
                  return Padding(
                    padding: EdgeInsets.fromLTRB(side, 12, side, 10),
                    child: Column(
                      children: [
                        _TopStatus(
                          track: _track,
                          stateAsset: _state.stateAsset,
                          stateLabel: _state.label,
                          onStateTap: _openStateSheet,
                        ),
                        SizedBox(height: compact ? 14 : 24),
                        _MotionParallax(
                          accent: _track.accent,
                          child: _ShaderArtwork(
                            key: ValueKey(_track.artwork),
                            path: _track.artwork,
                            heroTag: _track.objectKey,
                            width: artWidth,
                            height: artHeight,
                            animation: _ambientController,
                            animateReveal: _animateArtworkReveal,
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 26),
                        _TrackMetadata(
                          key: ValueKey(_track.title),
                          title: _track.title,
                          artist: _track.artist,
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 12 : 18),
                        StreamBuilder<Duration>(
                          stream: _player.positionStream,
                          initialData: Duration.zero,
                          builder: (context, positionSnapshot) {
                            final position =
                                positionSnapshot.data ?? Duration.zero;
                            final duration = _player.duration ?? Duration.zero;
                            final progress = duration.inMilliseconds <= 0
                                ? 0.0
                                : (position.inMilliseconds /
                                          duration.inMilliseconds)
                                      .clamp(0.0, 1.0);
                            return Column(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragUpdate:
                                      duration == Duration.zero
                                      ? null
                                      : (details) {
                                          final width =
                                              constraints.maxWidth - side * 2;
                                          final next =
                                              (details.localPosition.dx / width)
                                                  .clamp(0.0, 1.0);
                                          unawaited(
                                            _player.seek(duration * next),
                                          );
                                        },
                                  child: SizedBox(
                                    height: 44,
                                    width: double.infinity,
                                    child: AnimatedBuilder(
                                      animation: _waveController,
                                      builder: (context, child) => CustomPaint(
                                        painter: _WaveformPainter(
                                          progress: progress,
                                          phase: _waveController.value,
                                          active: _player.playing,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children:
                                      [
                                            Text(_format(position)),
                                            Text(_format(duration)),
                                          ]
                                          .map(
                                            (text) => DefaultTextStyle.merge(
                                              style: const TextStyle(
                                                color: Color(0xFF565658),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              child: text,
                                            ),
                                          )
                                          .toList(),
                                ),
                              ],
                            );
                          },
                        ),
                        const Spacer(),
                        _TransportControls(
                          playing: _player.playing,
                          loading:
                              _loading ||
                              _player.processingState ==
                                  ProcessingState.loading ||
                              _player.processingState ==
                                  ProcessingState.buffering,
                          pulse: _ambientController,
                          onPrevious: () => unawaited(_changeTrack(-1)),
                          onToggle: () => unawaited(_togglePlayback()),
                          onNext: () => unawaited(_changeTrack(1)),
                        ),
                        SizedBox(height: compact ? 4 : 8),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF8E8E92),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (!compact)
                          IconButton(
                            tooltip: 'Listening state',
                            onPressed: _openStateSheet,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 30,
                            ),
                            icon: const Icon(
                              Icons.headphones_rounded,
                              color: Color(0xFF777779),
                              size: 19,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_showAdaptation)
              Positioned(
                left: 16,
                right: 16,
                bottom: math.max(18, size.height * .04),
                child: ScaleTransition(
                  alignment: Alignment.bottomCenter,
                  scale: _bannerCurve,
                  child: FadeTransition(
                    opacity: _bannerController,
                    child: _AdaptationCard(
                      recommendation: _pendingRecommendation!,
                      targetTitle:
                          resonaTracks[_pendingRecommendation!.targetTrackIndex]
                              .title,
                      seconds: _switchCountdown,
                      onKeep: () => unawaited(_dismissOffer()),
                      onSwitch: () => unawaited(_acceptAdaptation()),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackMetadata extends StatefulWidget {
  const _TrackMetadata({
    super.key,
    required this.title,
    required this.artist,
    required this.compact,
  });

  final String title;
  final String artist;
  final bool compact;

  @override
  State<_TrackMetadata> createState() => _TrackMetadataState();
}

class _TrackMetadataState extends State<_TrackMetadata>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleAnimation;
  late final Animation<double> _artistAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
    _titleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.18, .72, curve: Curves.easeOutCubic),
    );
    _artistAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.40, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _MetadataReveal(
        animation: _titleAnimation,
        offset: .22,
        child: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.compact ? 20 : 22,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -.35,
          ),
        ),
      ),
      const SizedBox(height: 5),
      _MetadataReveal(
        animation: _artistAnimation,
        offset: .32,
        child: Text(
          widget.artist,
          style: const TextStyle(color: Color(0xFF777779), fontSize: 16),
        ),
      ),
    ],
  );
}

class _MetadataReveal extends StatelessWidget {
  const _MetadataReveal({
    required this.animation,
    required this.offset,
    required this.child,
  });

  final Animation<double> animation;
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: Offset(0, offset),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
  );
}

class _TopStatus extends StatelessWidget {
  const _TopStatus({
    required this.track,
    required this.stateAsset,
    required this.stateLabel,
    required this.onStateTap,
  });

  final ResonaTrack track;
  final String stateAsset;
  final String stateLabel;
  final VoidCallback onStateTap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      InkWell(
        onTap: onStateTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .12),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween(begin: .72, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Image.asset(stateAsset, key: ValueKey(stateAsset)),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: stateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' · ${track.support}'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: -.15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              track.artist,
              style: const TextStyle(color: Color(0xFF858589), fontSize: 12),
            ),
          ],
        ),
      ),
      SizedBox(
        width: 42,
        height: 42,
        child: IconButton(
          onPressed: onStateTap,
          tooltip: 'State and settings',
          padding: EdgeInsets.zero,
          alignment: Alignment.centerRight,
          icon: const Icon(
            Icons.headphones_rounded,
            color: Color(0xFFA4A4A7),
            size: 21,
          ),
        ),
      ),
    ],
  );
}

class _MotionParallax extends StatefulWidget {
  const _MotionParallax({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  State<_MotionParallax> createState() => _MotionParallaxState();
}

class _MotionParallaxState extends State<_MotionParallax>
    with WidgetsBindingObserver {
  StreamSubscription<AccelerometerEvent>? _motionSubscription;
  Timer? _startDelay;
  Offset? _baseline;
  Offset _tilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startDelay = Timer(const Duration(milliseconds: 700), _startListening);
  }

  void _startListening() {
    if (!mounted || _motionSubscription != null) return;
    _motionSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 33),
    ).listen(_handleMotion, onError: (_) {});
  }

  void _handleMotion(AccelerometerEvent event) {
    if (!mounted) return;
    final roll = math.atan2(
      event.x,
      math.sqrt(event.y * event.y + event.z * event.z),
    );
    final pitch = math.atan2(
      event.z,
      math.sqrt(event.x * event.x + event.y * event.y),
    );
    final reading = Offset(roll, pitch);
    _baseline ??= reading;
    final origin = _baseline!;
    final target = Offset(
      ((reading.dx - origin.dx) / .32).clamp(-1.0, 1.0),
      ((reading.dy - origin.dy) / .32).clamp(-1.0, 1.0),
    );
    final next = Offset.lerp(_tilt, target, .14)!;
    if ((next - _tilt).distance < .002) return;
    setState(() => _tilt = next);
  }

  void _stopListening() {
    _startDelay?.cancel();
    _startDelay = null;
    unawaited(_motionSubscription?.cancel());
    _motionSubscription = null;
    _baseline = null;
    if (mounted) setState(() => _tilt = Offset.zero);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startDelay = Timer(const Duration(milliseconds: 300), _startListening);
    } else {
      _stopListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startDelay?.cancel();
    unawaited(_motionSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return TweenAnimationBuilder<Offset>(
      tween: Tween(end: _tilt),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      builder: (context, tilt, child) {
        final intensity = math.min(1.0, tilt.distance);
        final transform = Matrix4.identity()
          ..setEntry(3, 2, .0012)
          ..setEntry(0, 3, tilt.dx * 9)
          ..setEntry(1, 3, tilt.dy * 7)
          ..rotateX(-tilt.dy * .026)
          ..rotateY(tilt.dx * .03);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: .06 + intensity * .025),
                blurRadius: 26 + intensity * 5,
                spreadRadius: -7,
                offset: Offset(-tilt.dx * 5, -tilt.dy * 4),
              ),
            ],
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: Transform.scale(
              scale: 1.012,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    child!,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(
                                -1.25 + tilt.dx * .85,
                                -1.1 + tilt.dy * .7,
                              ),
                              end: Alignment(
                                1.0 + tilt.dx * .85,
                                1.15 + tilt.dy * .7,
                              ),
                              colors: [
                                Colors.black.withValues(
                                  alpha: .035 + intensity * .025,
                                ),
                                Colors.transparent,
                                Colors.white.withValues(
                                  alpha: .025 + intensity * .055,
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0, .34, .59, 1],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: .025 + intensity * .035,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ShaderArtwork extends StatefulWidget {
  const _ShaderArtwork({
    super.key,
    required this.path,
    required this.heroTag,
    required this.width,
    required this.height,
    required this.animation,
    required this.animateReveal,
  });

  final String path;
  final String heroTag;
  final double width;
  final double height;
  final Animation<double> animation;
  final bool animateReveal;

  @override
  State<_ShaderArtwork> createState() => _ShaderArtworkState();
}

class _ShaderArtworkState extends State<_ShaderArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  late final Animation<double> _reveal;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
      value: widget.animateReveal ? 0 : 1,
    );
    if (widget.animateReveal) _revealController.forward();
    _reveal = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutQuart,
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.animation, _revealController]),
    builder: (context, child) {
      final reveal = _reveal.value;
      final perspective = Matrix4.identity()
        ..setEntry(3, 2, .001)
        ..rotateY((1 - reveal) * .055);
      return Transform.translate(
        offset: Offset(
          0,
          (widget.animation.value - .5) * 2.5 + (1 - reveal) * 9,
        ),
        child: Transform.scale(
          scale: (.965 + reveal * .035) + widget.animation.value * .008,
          child: Transform(
            alignment: Alignment.center,
            transform: perspective,
            child: child,
          ),
        ),
      );
    },
    child: Hero(
      tag: widget.heroTag,
      transitionOnUserGestures: true,
      createRectTween: (begin, end) =>
          MaterialRectCenterArcTween(begin: begin, end: end),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .52),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: _revealController,
          builder: (context, child) {
            final reveal = _reveal.value;
            final flash = math.sin(reveal * math.pi);
            return ShaderMask(
              blendMode: BlendMode.modulate,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(-2.4 + reveal * 3.8, -1),
                end: Alignment(-1.2 + reveal * 3.8, 1),
                colors: [
                  Colors.white,
                  Color.lerp(Colors.white, _lime, flash * .26)!,
                  Colors.white,
                ],
                stops: const [0, .5, 1],
              ).createShader(bounds),
              child: child,
            );
          },
          child: Image.asset(widget.path, fit: BoxFit.cover),
        ),
      ),
    ),
  );
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.playing,
    required this.loading,
    required this.pulse,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
  });

  final bool playing;
  final bool loading;
  final Animation<double> pulse;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _RoundControl(icon: Icons.skip_previous_rounded, onTap: onPrevious),
      AnimatedBuilder(
        animation: pulse,
        builder: (context, child) => Transform.scale(
          scale: playing ? 1 + pulse.value * .025 : 1,
          child: child,
        ),
        child: Semantics(
          button: true,
          label: playing ? 'Pause' : 'Play',
          child: InkWell(
            onTap: onToggle,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: _lime,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _lime.withValues(alpha: playing ? .22 : .08),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(27),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.black,
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 190),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(playing),
                        size: 43,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ),
      ),
      _RoundControl(icon: Icons.skip_next_rounded, onTap: onNext),
    ],
  );
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFF242426),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFFD7D7D8), size: 29),
    ),
  );
}

class _AdaptationCard extends StatelessWidget {
  const _AdaptationCard({
    required this.recommendation,
    required this.targetTitle,
    required this.seconds,
    required this.onKeep,
    required this.onSwitch,
  });
  final ResonaRecommendation recommendation;
  final String targetTitle;
  final int seconds;
  final VoidCallback onKeep;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF111312),
    elevation: 18,
    shadowColor: Colors.black,
    borderRadius: BorderRadius.circular(28),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(recommendation.stateAsset, width: 88, height: 88),
          Text(
            recommendation.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            recommendation.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF858589),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switching to $targetTitle in $seconds seconds',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD7D8D7),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onKeep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A3B3B)),
                    minimumSize: const Size(0, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Keep current'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onSwitch,
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: _lime,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Play $targetTitle',
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.headphones_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StateSheet extends StatelessWidget {
  const _StateSheet({
    required this.onContinue,
    required this.onOpenDiagnostics,
  });
  final VoidCallback onContinue;
  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ResonaStateEngine.instance,
    builder: (context, _) {
      final engine = ResonaStateEngine.instance;
      final state = engine.displayRecommendation;
      final heartRate = engine.heartRateBpm;
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF101211),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF383A39),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CURRENT STATE',
              style: TextStyle(
                color: Color(0xFF6F7270),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              child: Image.asset(
                state.stateAsset,
                key: ValueKey(state.stateAsset),
                width: 116,
                height: 116,
              ),
            ),
            Text(
              state.headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF96969A),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: .07)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded, color: _lime, size: 16),
                  const SizedBox(width: 7),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      heartRate == null ? '— BPM' : '${heartRate.round()} BPM',
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onContinue,
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
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onOpenDiagnostics,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Runtime details'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF77797B),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.progress,
    required this.phase,
    required this.active,
  });
  final double progress;
  final double phase;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 42;
    const gap = 4.0;
    final barWidth = (size.width - gap * (bars - 1)) / bars;
    final centerY = size.height / 2;
    final inactivePaint = Paint()..color = const Color(0xFF4A484A);
    final activePaint = Paint()..color = _lime;
    for (var index = 0; index < bars; index++) {
      final normalized = index / (bars - 1);
      final wave = math.sin(index * 1.37 + phase * math.pi * 2);
      final texture = math.sin(index * .47) * .5 + .5;
      final movement = active ? wave.abs() * 5 : 0.0;
      final height = 13 + texture * 17 + movement;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          index * (barWidth + gap),
          centerY - height / 2,
          barWidth,
          height,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        normalized <= progress ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.active != active;
}

String _format(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
