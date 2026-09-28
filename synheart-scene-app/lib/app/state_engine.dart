import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/state.dart';
import 'signals.dart';

/// Where the signal comes from.
enum WearableSource {
  none('No source'),
  platformHealth('Apple Health / Health Connect'),
  bluetooth('Bluetooth heart-rate monitor'),
  watch('Galaxy Watch'),
  wearSim('WearSim demo source');

  const WearableSource(this.label);
  final String label;
}

/// What the state pill and sheet show right now.
enum DisplayState {
  /// No consent or no source.
  off,

  /// Connected, waiting for enough evidence (Resona's "Listening").
  listening,

  /// Readings arrive but no axis is confident enough.
  notEnoughEvidence,

  /// Readings are confident but point to no particular kind of evening.
  noClearNeed,

  /// A WearSim cue: movement is affecting the reading.
  settling,

  /// A need is established; see [SceneStateEngine.experience].
  need,
}

/// Turns the runtime's HSI stream into the few calm updates Scene needs.
///
/// Resona swaps a track on a mode change; Scene re-ranks films. A ranking
/// that reshuffles every second is useless, so a reading is *published*
/// (handed to [onPublish], which updates the cubit) only when:
/// * it is the first reading with evidence,
/// * the suggested experience changes and two consecutive windows agree, or
/// * five minutes have passed since the last publish.
/// Liveness is tracked separately and does not re-rank anything.
class SceneStateEngine extends ChangeNotifier {
  SceneStateEngine(this.backend, {required this.onPublish, DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _subs = [
      backend.readings.listen(_onReading, onError: _onError),
      backend.heartRate.listen(_onHeartRate),
      backend.cues.listen(_onCue),
    ];
  }

  final SignalBackend backend;
  final void Function(CurrentState) onPublish;
  final DateTime Function() _clock;
  late final List<StreamSubscription<Object?>> _subs;

  static const confirmWindows = 2;
  static const republishEvery = Duration(minutes: 5);

  /// A source counts as live while samples arrived this recently (Resona: 45 s).
  static const liveWithin = Duration(seconds: 45);

  bool _consented = false;
  bool _starting = false;
  WearableSource _source = WearableSource.none;
  String? _sourceName;
  String? _error;
  double? _heartRate;
  DateTime? _lastSampleAt;
  CurrentState? _latest;
  CurrentState? _published;
  DateTime? _publishedAt;
  Experience? _candidate;
  int _candidateWindows = 0;
  bool _presenting = false;
  bool _settling = false;

  bool get consented => _consented;
  bool get busy => _starting;
  WearableSource get source => _source;
  String? get sourceName => _sourceName;
  String? get error => _error;
  double? get heartRate => _heartRate;
  CurrentState? get latest => _latest;

  bool get isLive => _lastSampleAt != null && _clock().difference(_lastSampleAt!) < liveWithin;

  Experience? get experience => _published?.suggestedExperience;

  DisplayState get display {
    if (!_consented || _source == WearableSource.none) return DisplayState.off;
    if (_settling) return DisplayState.settling;
    final latest = _latest;
    if (latest == null) return DisplayState.listening;
    if (!latest.hasEvidence) return DisplayState.notEnoughEvidence;
    if (_published?.suggestedExperience == null) return DisplayState.noClearNeed;
    return DisplayState.need;
  }

  /// The user agreed on the consent sheet: start the runtime.
  Future<void> consent() async {
    if (_consented) return;
    await _guard(() async {
      await backend.start();
      _consented = true;
    });
  }

  /// Withdraw consent: disconnect and stop the runtime. The last published
  /// reading stays in the cubit until it goes stale or the demo is reset.
  Future<void> withdraw() async {
    await backend.stop();
    _consented = false;
    _clearSource();
    notifyListeners();
  }

  Future<void> connectPlatformHealth() => _connect(WearableSource.platformHealth, backend.connectPlatformHealth);

  Future<List<WearableDevice>> scanBluetooth() async {
    _error = null;
    notifyListeners();
    try {
      return await backend.scanBluetooth();
    } catch (e) {
      _error = _describe(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> connectBluetooth(WearableDevice d) =>
      _connect(WearableSource.bluetooth, () => backend.connectBluetooth(d), name: d.name);

  /// The Scene Galaxy Watch app (Wear OS), streaming heart rate.
  Future<void> connectWatch() async {
    String? name;
    await _connect(WearableSource.watch, () async => name = await backend.connectWatch());
    _sourceName = name;
    notifyListeners();
  }

  /// `wearsim://pair?endpoint=ws://…&expires=<ms>`, from a deep link or pasted.
  Future<void> pairWearSim(Uri link) async {
    final endpoint = wearSimEndpoint(link, now: _clock());
    await _connect(WearableSource.wearSim, () => backend.connectWearSim(endpoint));
  }

  /// Validates a WearSim pairing link and returns its WebSocket endpoint.
  static Uri wearSimEndpoint(Uri link, {required DateTime now}) {
    if (link.scheme != 'wearsim' || link.host != 'pair') {
      throw const FormatException('This is not a WearSim pairing link.');
    }
    final value = link.queryParameters['endpoint'];
    final endpoint = value == null ? null : Uri.tryParse(value);
    if (endpoint == null || (endpoint.scheme != 'ws' && endpoint.scheme != 'wss')) {
      throw const FormatException('The WearSim endpoint is not a ws:// or wss:// address.');
    }
    final expires = int.tryParse(link.queryParameters['expires'] ?? '');
    if (expires != null && DateTime.fromMillisecondsSinceEpoch(expires).isBefore(now)) {
      throw const FormatException('This WearSim pairing link has expired.');
    }
    return endpoint;
  }

  Future<void> disconnectSource() async {
    await backend.disconnectSource();
    _clearSource();
    notifyListeners();
  }

  Future<void> _connect(WearableSource source, Future<void> Function() connect, {String? name}) async {
    if (!_consented) throw StateError('Consent is required before connecting a source.');
    await _guard(() async {
      await backend.disconnectSource();
      _clearSource();
      await connect();
      _source = source;
      _sourceName = name ?? source.label;
    });
  }

  Future<void> _guard(Future<void> Function() body) async {
    _starting = true;
    _error = null;
    notifyListeners();
    try {
      await body();
    } catch (e) {
      _error = _describe(e);
      rethrow;
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  static String _describe(Object e) => e is FormatException ? e.message : '$e';

  void _clearSource() {
    _source = WearableSource.none;
    _sourceName = null;
    _heartRate = null;
    _lastSampleAt = null;
    _latest = null;
    _candidate = null;
    _candidateWindows = 0;
    _presenting = false;
    _settling = false;
  }

  void _onHeartRate(double bpm) {
    _heartRate = bpm;
    _lastSampleAt = _clock();
    notifyListeners();
  }

  void _onError(Object e) {
    _error = _describe(e);
    notifyListeners();
  }

  void _onReading(CurrentState raw) {
    if (_presenting) return; // A WearSim presentation is driving the story.
    final now = _clock();
    final reading = raw.copyWith(source: _source == WearableSource.wearSim ? StateSource.wearSim : StateSource.synheart, capturedAt: now);
    _latest = reading;
    _lastSampleAt ??= now;
    if (!reading.hasEvidence) {
      _candidate = null;
      _candidateWindows = 0;
      notifyListeners();
      return;
    }

    final next = reading.suggestedExperience;
    if (next == _candidate) {
      _candidateWindows++;
    } else {
      _candidate = next;
      _candidateWindows = 1;
    }

    final first = _published == null;
    final changed = _published?.suggestedExperience != next && _candidateWindows >= confirmWindows;
    final due = _publishedAt != null && now.difference(_publishedAt!) >= republishEvery;
    if (first || changed || due) _publish(reading, now);
    notifyListeners();
  }

  void _publish(CurrentState reading, DateTime now) {
    _published = reading;
    _publishedAt = now;
    onPublish(reading);
  }

  /// WearSim presentation cues use Resona's names; Scene maps them to its
  /// experiences with the matching seeded reading.
  void _onCue(String cue) {
    final now = _clock();
    switch (cue) {
      case 'off':
        _presenting = false;
        _settling = false;
      case 'signal_settling':
        _presenting = true;
        _settling = true;
      case 'ease' || 'clarity' || 'flow':
        _presenting = true;
        _settling = false;
        final reading = cueReading(cue).copyWith(capturedAt: now);
        _latest = reading;
        _publish(reading, now);
      default:
        return;
    }
    notifyListeners();
  }

  /// The reading a WearSim cue stands for.
  static CurrentState cueReading(String cue) => switch (cue) {
        'ease' => const CurrentState(stress: AxisReading(0.78, 0.8), capacity: AxisReading(0.3, 0.7), source: StateSource.wearSim),
        'clarity' => const CurrentState(focus: AxisReading(0.38, 0.8), source: StateSource.wearSim),
        _ => const CurrentState(focus: AxisReading(0.78, 0.8), stress: AxisReading(0.2, 0.75), source: StateSource.wearSim),
      };

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
