import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/state.dart';
import 'check_in_diagnostics.dart';
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

/// Where a Synheart check-in is.
enum CheckInPhase { idle, connecting, reading, done, notEnoughSignal, failed }

/// Turns the runtime's HSI stream into the few calm updates Scene needs.
///
/// **Collection is continuous (product decision, 2026-09-30).** After
/// consent, heart rate from the chosen source and behavior signals are
/// collected in the foreground and the background (an Android foreground
/// service keeps Scene running, with an ongoing notification). Every reading
/// with evidence is *published* (handed to [onPublish], which updates the
/// cubit), so the picks follow the state live. This reverses the earlier
/// check-in-only rule and RFC §5's "no passive background collection"; it
/// needs a privacy review before any external use.
///
/// A check-in is optional: [startCheckIn] waits for the next reading with
/// evidence, or [checkInTimeout]. It no longer stops collection. A WearSim
/// presentation cue publishes its seeded reading.
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

  /// HSI windows are about 60 s and arrive with a lag, so a first confident
  /// reading usually takes 1–2 minutes.
  static const checkInTimeout = Duration(minutes: 3);

  /// A source counts as live while samples arrived this recently (Resona: 45 s).
  static const liveWithin = Duration(seconds: 45);

  /// Continuous collection: with no heart rate for this long, a streaming
  /// source (the Galaxy Watch, a Bluetooth strap) is reconnected — for the
  /// watch that re-sends its start command — and again every [stalledAfter]
  /// while it stays quiet. Health Connect and WearSim are left alone: Health
  /// Connect delivers in batches, and reconnecting it repeats its 7-day read.
  static const stalledAfter = Duration(seconds: 60);
  static const _watchdogEvery = Duration(seconds: 15);

  bool _consented = false;
  bool _starting = false;
  WearableSource _source = WearableSource.none;
  String? _sourceName;
  String? _error;
  double? _heartRate;
  DateTime? _lastSampleAt;
  CurrentState? _latest;
  CurrentState? _published;

  /// A change of suggestion seen once and waiting for the next reading to
  /// confirm it ([_held] tells "pending Balanced" from "nothing").
  Experience? _pendingNeed;
  bool _held = false;
  bool _presenting = false;
  bool _settling = false;

  /// The source chosen in Settings, reconnected for each check-in.
  ({WearableSource source, String? name, Future<void> Function() connect})? _chosen;
  CheckInPhase _checkIn = CheckInPhase.idle;
  DateTime? _checkInStartedAt;
  CurrentState? _checkInResult;
  Timer? _checkInTimer;
  Timer? _diagTimer;
  Timer? _watchdog;
  // Heart rate only: a reading built from behavior alone must not reset the
  // watchdog (seen 2026-09-30: retries drifted to 105-120 s).
  DateTime? _lastHeartRateAt;
  DateTime? _connectedAt;
  DateTime? _lastRestartAt;
  bool _stalled = false;
  int _restarts = 0;
  CheckInDiagnostics? _diag;

  bool get consented => _consented;
  bool get busy => _starting;
  WearableSource get source => _source;
  String? get sourceName => _sourceName;
  String? get error => _error;
  double? get heartRate => _heartRate;
  CurrentState? get latest => _latest;

  WearableSource? get chosenSource => _chosen?.source;
  String? get chosenName => _chosen?.name ?? _chosen?.source.label;
  CheckInPhase get checkIn => _checkIn;
  DateTime? get checkInStartedAt => _checkInStartedAt;
  CurrentState? get checkInResult => _checkInResult;

  /// What the last (or current) check-in received — for the Details section
  /// of "Not enough signal" and the `[scene-signal]` log.
  CheckInDiagnostics? get diagnostics => _diag;
  bool get checkInRunning => _checkIn == CheckInPhase.connecting || _checkIn == CheckInPhase.reading;

  bool get isLive => _lastSampleAt != null && _clock().difference(_lastSampleAt!) < liveWithin;

  /// The streaming source went quiet and is being reconnected.
  bool get sourceStalled => _stalled;

  /// How many times the watchdog reconnected the source (diagnostics).
  int get restarts => _restarts;

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
    // Keep collecting in the background. A refused permission or a blocked
    // service start leaves foreground collection working, and says why.
    try {
      await backend.requestBehaviorPermissions();
      await backend.setBackground(true);
    } catch (e) {
      _error = 'Background collection is not running: ${_describe(e)}';
      notifyListeners();
    }
  }

  /// Withdraw consent: disconnect and stop the runtime. The last published
  /// reading stays in the cubit until it goes stale or the demo is reset.
  Future<void> withdraw() async {
    _watchdog?.cancel();
    _watchdog = null;
    _stalled = false;
    try {
      await backend.setBackground(false);
    } catch (_) {}
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
    _chosen = (source: WearableSource.watch, name: name, connect: () async => _sourceName = await backend.connectWatch());
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

  /// Disconnect and forget the chosen source.
  Future<void> disconnectSource() async {
    await backend.disconnectSource();
    _clearSource();
    _chosen = null;
    notifyListeners();
  }

  /// Start a check-in with the chosen source.
  Future<void> startCheckIn() async {
    final chosen = _chosen;
    if (!_consented) throw StateError('Consent is required before a check-in.');
    if (chosen == null) throw StateError('Choose a source first.');
    _checkInTimer?.cancel();
    _checkIn = CheckInPhase.connecting;
    _checkInResult = null;
    notifyListeners();
    try {
      if (_source != chosen.source) await _connect(chosen.source, chosen.connect, name: chosen.name);
    } catch (_) {
      _checkIn = CheckInPhase.failed;
      notifyListeners();
      return;
    }
    // A check-in needs a reading taken after it started.
    _published = null;
    _held = false;
    _checkIn = CheckInPhase.reading;
    _checkInStartedAt = _clock();
    final diag = _diag = CheckInDiagnostics(chosenName ?? chosen.source.label, _checkInStartedAt!);
    CheckInDiagnostics.log('check-in started · source ${diag.source} · gate >${AxisReading.minConfidence} · runtime ${backend.diagnostics()}');
    _diagTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      CheckInDiagnostics.log('${_clock().difference(diag.startedAt).inSeconds}s · ${diag.summary(_clock()).join(' · ')} · runtime ${backend.diagnostics()}');
    });
    _checkInTimer = Timer(checkInTimeout, () {
      if (_checkIn != CheckInPhase.reading) return;
      _checkIn = CheckInPhase.notEnoughSignal;
      CheckInDiagnostics.log('check-in ended: NOT ENOUGH SIGNAL · ${diag.diagnosis} · runtime ${backend.diagnostics()}');
      _endCheckIn();
    });
    notifyListeners();
  }

  /// Leave the check-in early. Collection continues.
  Future<void> cancelCheckIn() async {
    if (!checkInRunning) return;
    _checkIn = CheckInPhase.idle;
    _endCheckIn();
  }

  /// Back to idle after a result has been shown.
  void resetCheckIn() {
    if (checkInRunning || _checkIn == CheckInPhase.idle) return;
    _checkIn = CheckInPhase.idle;
    notifyListeners();
  }

  /// A check-in ended (result, timeout or cancel). Collection continues.
  void _endCheckIn() {
    _checkInTimer?.cancel();
    _checkInTimer = null;
    _diagTimer?.cancel();
    _diagTimer = null;
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
      _connectedAt = _clock();
    });
    if (source != WearableSource.watch) _chosen = (source: source, name: name, connect: connect);
    if (source == WearableSource.watch || source == WearableSource.bluetooth) {
      _watchdog ??= Timer.periodic(_watchdogEvery, (_) => _checkSource());
    }
  }

  /// The watchdog: reconnects a quiet streaming source (see [stalledAfter]).
  void _checkSource() {
    final chosen = _chosen;
    if (!_consented || chosen == null || _starting || _presenting) return;
    if (chosen.source != WearableSource.watch && chosen.source != WearableSource.bluetooth) return;
    final now = _clock();
    final since = [_lastHeartRateAt, _connectedAt, _lastRestartAt]
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    if (since == null || now.difference(since) < stalledAfter) return;
    _lastRestartAt = now;
    _restarts++;
    _stalled = true;
    CheckInDiagnostics.log('source quiet for ${now.difference(since).inSeconds}s · reconnecting ${chosen.name ?? chosen.source.label} (restart #$_restarts)');
    backend.setBackgroundStatus('No heart rate from ${chosen.name ?? chosen.source.label} — reconnecting…').catchError((_) {});
    notifyListeners();
    _connect(chosen.source, chosen.connect, name: chosen.name).catchError((Object e) {
      CheckInDiagnostics.log('reconnect failed: ${_describe(e)}');
      // Keep showing the chosen source; its setup error ("pair your watch")
      // is wrong for a watch that is only out of reach. Retries continue.
      _error = null;
      _source = chosen.source;
      _sourceName = chosen.name;
      backend.setBackgroundStatus('${chosen.name ?? chosen.source.label} not reachable — retrying every minute').catchError((_) {});
      notifyListeners();
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
    _presenting = false;
    _settling = false;
  }

  void _onHeartRate(double bpm) {
    _heartRate = bpm;
    _lastSampleAt = _clock();
    _lastHeartRateAt = _lastSampleAt;
    if (_stalled) {
      _stalled = false;
      CheckInDiagnostics.log('heart rate back after restart #$_restarts');
      backend.setBackgroundStatus(null).catchError((_) {});
    }
    if (_checkIn == CheckInPhase.reading) _diag?.onHeartRate(_lastSampleAt!);
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
    if (_checkIn == CheckInPhase.reading) {
      _diag?.onReading(raw);
      CheckInDiagnostics.log('reading #${_diag?.readings} · ${CheckInDiagnostics.describeReading(raw)} · '
          '${reading.hasEvidence ? 'passes the gate' : 'below the gate'}');
      // During a check-in the first reading with evidence is its result.
      if (reading.hasEvidence) _publish(reading);
    } else {
      final publish = reading.hasEvidence && _confirmed(reading);
      CheckInDiagnostics.log('live reading · ${CheckInDiagnostics.describeReading(raw)} · '
          '${!reading.hasEvidence ? 'no evidence' : publish ? 'published' : 'held: ${_label(reading.suggestedExperience)} needs a second reading'}'
          ' · runtime ${backend.diagnostics()}');
      if (publish) _publish(reading);
    }
    notifyListeners();
  }

  static String _label(Experience? e) => e?.label ?? 'Balanced';

  /// Live readings update the state every minute, but a change of
  /// *suggestion* (Unwind / Easy watch / Stay engaged / Balanced) is
  /// published only when the next reading agrees, so one minute of phone use
  /// does not flip it (seen on device 2026-10-01: Balanced ⇄ Easy watch as
  /// focus quality came and went). The same suggestion publishes at once.
  bool _confirmed(CurrentState reading) {
    final prev = _published;
    final next = reading.suggestedExperience;
    if (prev == null || prev.isStaleAt(_clock()) || prev.suggestedExperience == next || (_held && _pendingNeed == next)) {
      _held = false;
      return true;
    }
    _held = true;
    _pendingNeed = next;
    return false;
  }

  void _publish(CurrentState reading) {
    _published = reading;
    onPublish(reading);
    if (_checkIn == CheckInPhase.reading) {
      CheckInDiagnostics.log('check-in done: published ${CheckInDiagnostics.describeReading(reading)}');
      _checkInResult = reading;
      _checkIn = CheckInPhase.done;
      _endCheckIn();
    }
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
        // Like any reading, a cue updates the state live.
        _publish(reading);
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

  bool _disposed = false;

  /// Async work (a pause started from a screen's dispose, a disconnect after a
  /// check-in) can finish after the app is torn down; never notify then.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _checkInTimer?.cancel();
    _diagTimer?.cancel();
    _watchdog?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
