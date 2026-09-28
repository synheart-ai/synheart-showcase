import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Disconnect whichever source is active; the runtime keeps running.
  Future<void> disconnectSource();
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
        consentConfig: ConsentConfig(
          deviceId: 'scene-${Platform.operatingSystem}-device',
          platform: Platform.operatingSystem,
          userId: 'scene-viewer',
        ),
      ),
    );
    // The user agreed on Scene's own consent sheet. Record exactly that with
    // the runtime: biosignals on this device, nothing else, no cloud.
    final form = Synheart.consentGetEditableFormTyped();
    if (form == null) throw StateError('The Synheart runtime did not provide a consent form.');
    await Synheart.consentSubmitFormTyped(
      form: form.copyWith(
        biosignals: true,
        behavior: false,
        phoneContext: false,
        allowCloud: false,
        allowResearch: false,
        allowVendorSync: false,
        syni: false,
      ),
    );
    _hsi = Synheart.onStateUpdate.listen((s) => _readings.add(_fromHsi(s)), onError: _readings.addError);
    await Synheart.startSession();
    // No task type: choosing a film is not a focus task, and the type
    // modulates confidence, so Scene does not claim one.
    _running = true;
  }

  static CurrentState _fromHsi(HSIState s) {
    AxisReading? r(HSIAxisValue? a) => a == null ? null : AxisReading(a.value, a.confidence);
    return CurrentState(
      focus: r(s.hsi.focus),
      stress: r(s.hsi.stress),
      arousal: r(s.hsi.arousal),
      capacity: r(s.hsi.capacity),
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
        Synheart.pushWearHr(ts, hr, provider: 'sdk_wear');
      }
      final rr = sample.rrIntervals?.where((v) => v > 0).toList(growable: false) ?? const <double>[];
      if (rr.isNotEmpty) Synheart.pushRrBatch(ts, rr, provider: 'sdk_wear');
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
      Synheart.pushWearHr(sample.tsMs, sample.bpm, provider: 'ble_hrm');
      final rr = sample.rrIntervalsMs.where((v) => v > 0).toList(growable: false);
      if (rr.isNotEmpty) Synheart.pushRrBatch(sample.tsMs, rr, provider: 'ble_hrm');
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
      Synheart.pushWearHr(now, hr, provider: provider);
    }
    final rr = (decoded['rr_intervals_ms'] as List<dynamic>? ?? const []).whereType<num>().map((v) => v.toDouble()).where((v) => v > 0).toList();
    if (rr.isNotEmpty) Synheart.pushRrBatch(now, rr, provider: provider);
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

  @override
  Future<void> disconnectSource() async {
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
