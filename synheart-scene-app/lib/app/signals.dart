import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:synheart_core/synheart_core.dart';

import '../domain/state.dart';

/// A heart-rate monitor found by a Bluetooth scan.
class WearableDevice {
  const WearableDevice(this.id, this.name);
  final String id;
  final String name;
}

/// What the state engine needs from the Synheart runtime and the wearable
/// sources. [SynheartSignals] is the real one; tests use a fake.
abstract class SignalBackend {
  /// HSI readings from the on-device runtime (source not yet set).
  Stream<CurrentState> get readings;

  /// Heart rate as it arrives from the active source, for the live indicator.
  Stream<double> get heartRate;

  /// WearSim presentation cues ("flow", "clarity", "ease",
  /// "signal_settling", or "off" when presentation mode ends).
  Stream<String> get cues;

  /// Initialise the runtime with local-only consent and start a session.
  Future<void> start();

  /// Stop the session and release the runtime.
  Future<void> stop();

  /// Apple Health on iOS, Health Connect on Android.
  Future<void> connectPlatformHealth();

  Future<List<WearableDevice>> scanBluetooth();

  Future<void> connectBluetooth(WearableDevice device);

  /// A WearSim demo source streaming `ai.synheart.wearsim.signal.v1`.
  Future<void> connectWearSim(Uri endpoint);

  /// Whether this platform can use the Scene Galaxy Watch (Wear OS) app.
  bool get supportsWatch;

  /// Start heart-rate streaming from the Scene watch app; returns the watch
  /// name. Throws when no watch is connected.
  Future<String> connectWatch();

  /// Disconnect whichever source is active; the runtime keeps running.
  Future<void> disconnectSource();

  /// Runtime status and sample counters for the `[scene-signal]` log.
  Map<String, Object?> diagnostics();

  /// Keep collecting while Scene is in the background (Android: a foreground
  /// service with an ongoing notification). No-op where unsupported.
  Future<void> setBackground(bool on);

  /// The runtime permissions behavior signals need: posting the background
  /// notification (Android 13+) and phone state for call events.
  Future<void> requestBehaviorPermissions();

  /// The ongoing notification's line: a problem (e.g. the watch went quiet),
  /// or null for the normal text.
  Future<void> setBackgroundStatus(String? problem);

  /// Notification access (system Settings) for notification events.
  Future<bool> notificationAccessGranted();
  Future<void> openNotificationAccess();
}

/// The real backend: synheart_core's runtime and wearable modules, wired the
/// way Resona (synheart-showcase) does it. Needs the native runtime installed
/// with the Synheart CLI and a physical device for wearable input.
class SynheartSignals implements SignalBackend {
  final _readings = StreamController<CurrentState>.broadcast();
  final _heartRate = StreamController<double>.broadcast();
  final _cues = StreamController<String>.broadcast();
  final _ble = BleHrmProvider();

  StreamSubscription<HSIState>? _hsi;
  StreamSubscription<WearSample>? _platformWear;
  StreamSubscription<HeartRateSample>? _bleSamples;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSamples;
  bool _bleConnected = false;
  bool _running = false;

  // Diagnostics: what was handed to the runtime, and how far each sample's own
  // timestamp was from the phone's clock (a batched or mis-stamped source
  // shows up here).
  int _hrPushed = 0;
  int _rrPushed = 0;
  int? _minSkewMs;
  int? _maxSkewMs;

  void _pushHr(int tsMs, double bpm, String provider) {
    final skew = DateTime.now().millisecondsSinceEpoch - tsMs;
    _hrPushed++;
    _minSkewMs = _minSkewMs == null || skew < _minSkewMs! ? skew : _minSkewMs;
    _maxSkewMs = _maxSkewMs == null || skew > _maxSkewMs! ? skew : _maxSkewMs;
    Synheart.pushWearHr(tsMs, bpm, provider: provider);
  }

  void _pushRr(int tsMs, List<double> rr, String provider) {
    _rrPushed += rr.length;
    Synheart.pushRrBatch(tsMs, rr, provider: provider);
  }

  @override
  Map<String, Object?> diagnostics() {
    // Diagnostics must never take the app down: each SDK getter is guarded.
    Object? safe(Object? Function() read) {
      try {
        return read();
      } catch (e) {
        return 'error: $e';
      }
    }

    final features = safe(() => Synheart.lastFeatures);
    return {
      'initialized': safe(() => Synheart.isInitialized),
      'session': safe(() => Synheart.isSessionRunning),
      'runtime': safe(() => Synheart.runtimeVersion),
      'hrPushed': _hrPushed,
      'rrPushed': _rrPushed,
      // Phone clock minus the sample's own timestamp, min..max.
      'sampleAgeMs': _minSkewMs == null ? null : '$_minSkewMs..$_maxSkewMs',
      'droppedHsi': safe(() => Synheart.droppedHsiFrames),
      // null here means no runtime is loaded: pushes are then silently dropped.
      'features': features is String && features.length > 300 ? '${features.substring(0, 300)}…' : features,
    };
  }

  // The Scene watch app, via the phone-side WatchRelay (android/app).
  static const _watch = MethodChannel('ai.synheart.scene/watch');
  static const _watchEvents = EventChannel('ai.synheart.scene/watch_events');
  StreamSubscription<dynamic>? _watchSamples;

  @override
  Stream<CurrentState> get readings => _readings.stream;
  @override
  Stream<double> get heartRate => _heartRate.stream;
  @override
  Stream<String> get cues => _cues.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    await Synheart.initialize(
      config: SynheartConfig(
        appId: 'ai.synheart.scene',
        subjectId: 'scene-viewer',
        appVersion: '1.0.0',
        appName: 'Scene',
        category: 'Entertainment',
        developer: 'Synheart AI',
        allowUnsignedCapabilities: true,
        wearConfig: const WearConfig(enableHighFrequencyHrv: true),
        // Behavior signals (2026-09-30): taps, scrolls and swipes in Scene,
        // plus motion (raw accelerometer into the runtime). Typing is not
        // collected. App switches, notification and call events come from
        // synheart_behavior's own collectors once their permissions exist.
        behaviorConfig: const BehaviorConfig(
          enableGestureTracking: true,
          enableTypingTracking: false,
          emitRawMotionSamples: true,
        ),
        consentConfig: ConsentConfig(
          deviceId: 'scene-${Platform.operatingSystem}-device',
          platform: Platform.operatingSystem,
          userId: 'scene-viewer',
        ),
      ),
    );
    // The user agreed on Scene's own consent sheet. Record exactly that with
    // the runtime: biosignals and behavior on this device, no cloud.
    final form = Synheart.consentGetEditableFormTyped();
    if (form == null) throw StateError('The Synheart runtime did not provide a consent form.');
    await Synheart.consentSubmitFormTyped(
      form: form.copyWith(
        biosignals: true,
        behavior: true,
        phoneContext: false,
        allowCloud: false,
        allowResearch: false,
        allowVendorSync: false,
        syni: false,
      ),
    );
    _hsi = Synheart.onStateUpdate.listen((s) {
      if (kDebugMode) debugPrint('[scene-hsi] ${describeHsi(s.rawJson)}');
      _readings.add(_fromHsi(s));
    }, onError: _readings.addError);
    await Synheart.startSession();
    // No task type: choosing a film is not a focus task, and the type
    // modulates confidence, so Scene does not claim one.
    _running = true;
  }

  /// Every HSI value in a snapshot on one line, for the debug log: each axis
  /// domain as `name=score@confidence` (`-` when the score is null), then what
  /// was withheld and why, the context guess, tiers and the engine version.
  /// No raw biosignals are in the snapshot; the embedding is left out.
  @visibleForTesting
  static String describeHsi(String rawJson) {
    try {
      final m = jsonDecode(rawJson) as Map<String, dynamic>;
      final parts = <String>[];
      final axes = m['axes'];
      if (axes is Map) {
        for (final e in axes.entries) {
          if (e.value is! List) continue;
          final items = [
            for (final r in e.value as List)
              if (r is Map)
                '${r['name']}=${r['score'] is num ? (r['score'] as num).toStringAsFixed(2) : '-'}'
                    '@${r['confidence'] is num ? (r['confidence'] as num).toStringAsFixed(2) : '-'}'
                    '${switch (r['direction']) {
                  'lower_is_more' => '↓',
                  'bidirectional' => '↔',
                  'higher_is_more' => '',
                  null => '?',
                  final other => '($other)',
                }}',
          ];
          parts.add('${e.key}{${items.join(' ')}}');
        }
      }
      final meta = m['meta'] is Map ? m['meta'] as Map : const {};
      final sh = meta['synheart'] is Map ? meta['synheart'] as Map : const {};
      if (sh['state_withheld'] is Map && (sh['state_withheld'] as Map).isNotEmpty) {
        parts.add('withheld{${[for (final e in (sh['state_withheld'] as Map).entries) '${e.key}:${e.value}'].join(' ')}}');
      }
      final ctx = sh['context'];
      if (ctx is Map) {
        parts.add('context{${ctx['context_label']}@${ctx['context_confidence']} app:${ctx['foreground_app_category']} baseline:${ctx['baseline_maturity']}}');
      }
      if (sh['tiers'] is Map) parts.add('tiers${jsonEncode(sh['tiers'])}');
      final prov = meta['provenance'] is Map ? meta['provenance'] as Map : const {};
      parts.add('hsi ${m['hsi_version']} engine ${prov['engine_version'] ?? '?'} baseline ${prov['baseline_status'] ?? '?'}');
      return parts.join(' · ');
    } catch (e) {
      return 'unparsed (${rawJson.length} chars): $e';
    }
  }

  static CurrentState _fromHsi(HSIState s) {
    AxisReading? r(HSIAxisValue? a) => a == null ? null : AxisReading(a.value, a.confidence);
    return fromHsiJson(
      s.rawJson,
      typed: {
        HsiAxis.focus: ?r(s.hsi.focus),
        HsiAxis.stress: ?r(s.hsi.stress),
        HsiAxis.arousal: ?r(s.hsi.arousal),
        HsiAxis.capacity: ?r(s.hsi.capacity),
        HsiAxis.sleep: ?r(s.hsi.sleep),
        HsiAxis.focusQuality: ?r(s.hsi.focusQuality),
        HsiAxis.interruptionPressure: ?r(s.hsi.interruptionPressure),
        HsiAxis.interactionMode: ?r(s.hsi.interactionMode),
      },
      basis: {
        if (s.modalities.physiological) Modality.physiological,
        if (s.modalities.kinematic) Modality.kinematic,
        if (s.modalities.digital) Modality.digital,
      },
    );
  }

  /// Every axis Scene reads, from an HSI 1.3 snapshot: each
  /// `axes.<domain>[]` entry by name (a null score is skipped — "could not
  /// compute", never zero), then [typed] for anything the JSON lacks (the
  /// legacy path). Reasons come from `meta.synheart.state_withheld` and, for
  /// digital axes with no score, `diagnostics.notes`. The embedding is
  /// ignored (`privacy.embedding_allowed` is false).
  @visibleForTesting
  static CurrentState fromHsiJson(String rawJson, {Map<HsiAxis, AxisReading> typed = const {}, Set<Modality> basis = const {}}) {
    final axes = <HsiAxis, AxisReading>{};
    final withheld = <HsiAxis, String>{};
    final directions = <HsiAxis, HsiDirection>{};
    String? contextLabel;
    String? appCategory;
    try {
      final m = jsonDecode(rawJson) as Map<String, dynamic>;
      final domains = m['axes'];
      final unscored = <HsiAxis>{};
      if (domains is Map) {
        for (final list in domains.values) {
          if (list is! List) continue;
          for (final e in list) {
            if (e is! Map || e['name'] is! String) continue;
            final a = HsiAxis.fromWire(e['name'] as String);
            if (a == null) continue;
            if (HsiDirection.fromWire(e['direction']) case final dir?) directions[a] = dir;
            final score = e['score'];
            if (score is num) {
              final c = e['confidence'];
              axes[a] = AxisReading(score.toDouble(), c is num ? c.toDouble() : 0.0);
            } else {
              unscored.add(a);
            }
          }
        }
      }
      final meta = m['meta'] is Map ? m['meta'] as Map : const {};
      final sh = meta['synheart'] is Map ? meta['synheart'] as Map : const {};
      final w = sh['state_withheld'];
      if (w is Map) {
        for (final e in w.entries) {
          if (HsiAxis.fromWire('${e.key}') case final a?) withheld[a] = '${e.value}';
        }
      }
      final diag = sh['diagnostics'] is Map ? sh['diagnostics'] as Map : const {};
      final notes = diag['notes'] is Map ? diag['notes'] as Map : const {};
      for (final a in unscored) {
        if (!withheld.containsKey(a) && notes[a.wireName] is String) withheld[a] = notes[a.wireName] as String;
      }
      final ctx = sh['context'];
      if (ctx is Map) {
        contextLabel = ctx['context_label'] is String ? ctx['context_label'] as String : null;
        appCategory = ctx['foreground_app_category'] is String ? ctx['foreground_app_category'] as String : null;
      }
    } catch (_) {
      // Not JSON (legacy path): the typed values are all there is.
    }
    for (final e in typed.entries) {
      axes.putIfAbsent(e.key, () => e.value);
    }
    return CurrentState(
      focus: axes[HsiAxis.focus],
      stress: axes[HsiAxis.stress],
      arousal: axes[HsiAxis.arousal],
      capacity: axes[HsiAxis.capacity],
      cognitiveLoad: axes[HsiAxis.cognitiveLoad],
      mentalFatigue: axes[HsiAxis.mentalFatigue],
      valence: axes[HsiAxis.valence],
      sleep: axes[HsiAxis.sleep],
      focusQuality: axes[HsiAxis.focusQuality],
      interruptionPressure: axes[HsiAxis.interruptionPressure],
      interactionMode: axes[HsiAxis.interactionMode],
      withheld: {
        for (final e in withheld.entries)
          if (axes[e.key] == null) e.key: e.value,
      },
      basis: basis,
      directions: directions,
      contextLabel: contextLabel,
      appCategory: appCategory,
      source: StateSource.synheart,
    );
  }

  @override
  Future<void> stop() async {
    await disconnectSource();
    await _hsi?.cancel();
    _hsi = null;
    if (_running) {
      try {
        await Synheart.stopSession();
      } catch (e) {
        debugPrint('Synheart stopSession failed: $e');
      }
      await Synheart.dispose();
    }
    _running = false;
  }

  @override
  Future<void> connectPlatformHealth() async {
    await disconnectSource();
    _platformWear = Synheart.wearSampleStream.listen((sample) {
      final ts = sample.timestamp.millisecondsSinceEpoch;
      final hr = sample.hr;
      if (hr != null && hr > 0) {
        _heartRate.add(hr);
        _pushHr(ts, hr, 'sdk_wear');
      }
      final rr = sample.rrIntervals?.where((v) => v > 0).toList(growable: false) ?? const <double>[];
      if (rr.isNotEmpty) _pushRr(ts, rr, 'sdk_wear');
      final hrv = sample.hrvRmssd;
      if (hrv != null && hrv > 0) Synheart.pushVendorHrv(ts, rmssd: hrv, provider: 'sdk_wear');
    }, onError: _readings.addError);
    await Synheart.startWearCollection(interval: const Duration(seconds: 1));
  }

  @override
  Future<List<WearableDevice>> scanBluetooth() async {
    if (Platform.isAndroid) {
      final statuses = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
      final modern = statuses[Permission.bluetoothScan]?.isGranted == true && statuses[Permission.bluetoothConnect]?.isGranted == true;
      final legacy = statuses[Permission.locationWhenInUse]?.isGranted == true;
      if (!modern && !legacy) throw StateError('Bluetooth permission is needed to find a heart-rate monitor.');
    } else if (await _ble.requestPermission() != 'granted') {
      throw StateError('Bluetooth permission was not granted.');
    }
    await _ble.warmAdapter();
    final found = await _ble.scan(timeoutMs: 6000);
    return [for (final d in found) WearableDevice(d.deviceId, d.name.isEmpty ? 'Heart-rate monitor' : d.name)];
  }

  @override
  Future<void> connectBluetooth(WearableDevice device) async {
    await disconnectSource();
    await _ble.connect(deviceId: device.id, sessionId: 'scene_${DateTime.now().millisecondsSinceEpoch}', enableBattery: true);
    _bleConnected = true;
    _bleSamples = _ble.onHeartRate.listen((sample) {
      if (sample.bpm <= 0) return;
      _heartRate.add(sample.bpm);
      _pushHr(sample.tsMs, sample.bpm, 'ble_hrm');
      final rr = sample.rrIntervalsMs.where((v) => v > 0).toList(growable: false);
      if (rr.isNotEmpty) _pushRr(sample.tsMs, rr, 'ble_hrm');
    }, onError: _readings.addError);
  }

  @override
  Future<void> connectWearSim(Uri endpoint) async {
    await disconnectSource();
    final socket = await WebSocket.connect(endpoint.toString()).timeout(const Duration(seconds: 8));
    _socket = socket;
    _socketSamples = socket.listen(_ingestWearSim, onError: _readings.addError, cancelOnError: false);
  }

  /// The WearSim message format Resona reads: heart rate, RR intervals and
  /// motion, plus optional presentation cues.
  void _ingestWearSim(dynamic message) {
    if (message is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic> || decoded['schema'] is! String) return;
    if (decoded['presentation_mode'] == false) _cues.add('off');
    final cue = decoded['presentation_cue'];
    if (cue is String) _cues.add(cue);
    if (decoded['schema'] != 'ai.synheart.wearsim.signal.v1') return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final provider = decoded['device_profile'] == 'apple_watch_workout_v1' ? 'watch_sample' : 'ble_hrm';
    final hr = (decoded['heart_rate_bpm'] as num?)?.toDouble();
    if (hr != null && hr > 0) {
      _heartRate.add(hr);
      _pushHr(now, hr, provider);
    }
    final rr = (decoded['rr_intervals_ms'] as List<dynamic>? ?? const []).whereType<num>().map((v) => v.toDouble()).where((v) => v > 0).toList();
    if (rr.isNotEmpty) _pushRr(now, rr, provider);
    final motion = decoded['motion_samples'] as List<dynamic>? ?? const [];
    for (var i = 0; i < motion.length; i++) {
      final m = motion[i];
      if (m is! Map<String, dynamic>) continue;
      final x = (m['x'] as num?)?.toDouble();
      final y = (m['y'] as num?)?.toDouble();
      final z = (m['z'] as num?)?.toDouble();
      if (x == null || y == null || z == null) continue;
      Synheart.pushAccel(now - (motion.length - 1 - i) * 40, x, y, z);
    }
  }

  static const _background = MethodChannel('ai.synheart.scene/background');

  @override
  Future<void> setBackground(bool on) async {
    if (!Platform.isAndroid) return; // iOS: foreground only for now.
    await _background.invokeMethod<bool>(on ? 'start' : 'stop');
  }

  @override
  Future<void> setBackgroundStatus(String? problem) async {
    if (!Platform.isAndroid) return;
    await _background.invokeMethod<bool>('status', problem);
  }

  @override
  Future<void> requestBehaviorPermissions() async {
    if (!Platform.isAndroid) return;
    // Denials are fine: the matching signal is simply not collected.
    await [Permission.notification, Permission.phone].request();
  }

  @override
  Future<bool> notificationAccessGranted() async =>
      Platform.isAndroid && (await _background.invokeMethod<bool>('notificationAccessGranted') ?? false);

  @override
  Future<void> openNotificationAccess() async {
    if (Platform.isAndroid) await _background.invokeMethod<bool>('openNotificationAccess');
  }

  @override
  bool get supportsWatch => Platform.isAndroid;

  @override
  Future<String> connectWatch() async {
    if (!supportsWatch) throw UnsupportedError('The Galaxy Watch app needs an Android phone.');
    final name = await _watch.invokeMethod<String>('connectedWatch');
    if (name == null) {
      throw StateError('No watch is connected. Pair your Galaxy Watch with this phone and install Scene on it.');
    }
    await disconnectSource();
    _watchSamples = _watchEvents.receiveBroadcastStream().listen((dynamic e) {
      if (e is! Map) return;
      switch (e['type']) {
        case 'hr_sample':
          final bpm = (e['bpm'] as num?)?.toDouble() ?? 0;
          if (bpm <= 0) return;
          _heartRate.add(bpm);
          // Heart rate only: Wear OS Health Services' HEART_RATE_BPM has no RR
          // intervals, so HRV-based axes may stay below the confidence gate.
          _pushHr((e['timestamp'] as num).toInt(), bpm, 'wear_os');
        case 'stream_error':
          _readings.addError(StateError(e['message'] as String? ?? 'The watch could not start heart rate.'));
      }
    }, onError: _readings.addError);
    await _watch.invokeMethod<bool>('startStream');
    return name;
  }

  @override
  Future<void> disconnectSource() async {
    if (_watchSamples != null) {
      await _watchSamples!.cancel();
      _watchSamples = null;
      try {
        await _watch.invokeMethod<bool>('stopStream');
      } catch (_) {}
    }

    await _socketSamples?.cancel();
    await _socket?.close();
    _socketSamples = null;
    _socket = null;

    await _platformWear?.cancel();
    _platformWear = null;
    if (Synheart.isWearCollecting) {
      try {
        await Synheart.stopWearCollection();
      } catch (_) {}
    }

    await _bleSamples?.cancel();
    _bleSamples = null;
    if (_bleConnected) {
      try {
        await _ble.disconnect();
      } catch (_) {}
      _bleConnected = false;
    }
  }
}
