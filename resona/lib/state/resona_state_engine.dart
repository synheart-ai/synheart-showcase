import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:synheart_core/synheart_core.dart';

enum ResonaAdaptiveMode { flow, clarity, ease }

enum ResonaWearableSource { none, appleHealth, bluetooth, wearSim }

class ResonaRecommendation {
  const ResonaRecommendation({
    required this.mode,
    required this.label,
    required this.headline,
    required this.message,
    required this.targetTrackIndex,
    required this.stateAsset,
  });

  final ResonaAdaptiveMode mode;
  final String label;
  final String headline;
  final String message;
  final int targetTrackIndex;
  final String stateAsset;
}

class ResonaStateEngine extends ChangeNotifier {
  ResonaStateEngine._();

  static final instance = ResonaStateEngine._();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Uri? _endpoint;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _manualDisconnect = false;
  StreamSubscription<HSIState>? _hsiSubscription;
  StreamSubscription<WearSample>? _platformWearSubscription;
  StreamSubscription<HeartRateSample>? _bleSubscription;
  final BleHrmProvider _bleProvider = BleHrmProvider();
  ResonaWearableSource _wearableSource = ResonaWearableSource.none;
  String? _wearableName;
  DateTime? _lastWearableSampleAt;
  bool _runtimeReady = false;
  bool _connecting = false;
  bool _connected = false;
  String? _error;
  HSIState? _latestHsi;
  ResonaRecommendation? _recommendation;
  ResonaRecommendation? _displayState;
  ResonaAdaptiveMode? _candidate;
  int _candidateWindows = 0;
  bool _presentationMode = false;
  String? _lastPresentationCue;
  double? _heartRateBpm;

  bool get connecting => _connecting;
  bool get connected => _connected;
  String? get error => _error;
  ResonaWearableSource get wearableSource => _wearableSource;
  String? get wearableName => _wearableName;
  DateTime? get lastWearableSampleAt => _lastWearableSampleAt;
  bool get hasLiveWearableSignal =>
      _lastWearableSampleAt != null &&
      DateTime.now().difference(_lastWearableSampleAt!) <
          const Duration(seconds: 45);
  HSIState? get latestHsi => _latestHsi;
  double? get heartRateBpm => _heartRateBpm;
  ResonaRecommendation? get recommendation => _recommendation;
  ResonaRecommendation get displayRecommendation =>
      _displayState ?? _listeningState;

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _endpoint = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _disconnectActiveTransport();
    await _hsiSubscription?.cancel();
    if (_runtimeReady) await Synheart.stopSession();
    _socketSubscription = null;
    _socket = null;
    _hsiSubscription = null;
    _runtimeReady = false;
    _connecting = false;
    _connected = false;
    _wearableSource = ResonaWearableSource.none;
    _wearableName = null;
    _lastWearableSampleAt = null;
    _presentationMode = false;
    _lastPresentationCue = null;
    _recommendation = null;
    _displayState = null;
    _candidate = null;
    _candidateWindows = 0;
    _heartRateBpm = null;
    notifyListeners();
  }

  Future<void> connectFromPairingLink(Uri pairingLink) async {
    if (pairingLink.scheme != 'wearsim' || pairingLink.host != 'pair') {
      throw const FormatException('This wearable connection link is invalid.');
    }
    final endpointValue = pairingLink.queryParameters['endpoint'];
    final endpoint = endpointValue == null ? null : Uri.tryParse(endpointValue);
    if (endpoint == null ||
        (endpoint.scheme != 'ws' && endpoint.scheme != 'wss')) {
      throw const FormatException('The wearable endpoint is invalid.');
    }
    final expiresAt = int.tryParse(
      pairingLink.queryParameters['expires'] ?? '',
    );
    if (expiresAt != null &&
        DateTime.fromMillisecondsSinceEpoch(
          expiresAt,
        ).isBefore(DateTime.now())) {
      throw const FormatException('This wearable connection link has expired.');
    }

    await _disconnectActiveTransport();
    _wearableSource = ResonaWearableSource.wearSim;
    _wearableName = 'Wearable source';
    _manualDisconnect = false;
    _endpoint = endpoint;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _connect(endpoint);
    } catch (_) {
      _wearableSource = ResonaWearableSource.none;
      _wearableName = null;
      _endpoint = null;
      rethrow;
    }
  }

  /// Connect Apple Watch data through Apple Health and Synheart Core's wear
  /// module. This is local platform-health collection; a dedicated live
  /// ResonaWatch companion can be added later without changing the UI contract.
  Future<void> connectAppleHealth() async {
    if (_connecting) return;
    _connecting = true;
    _error = null;
    notifyListeners();
    try {
      await _disconnectActiveTransport();
      await _ensureRuntime();
      _platformWearSubscription = Synheart.wearSampleStream.listen(
        _ingestPlatformWearSample,
        onError: (Object error) {
          _error = error.toString();
          notifyListeners();
        },
      );
      await Synheart.startWearCollection(interval: const Duration(seconds: 1));
      _wearableSource = ResonaWearableSource.appleHealth;
      _wearableName = Platform.isIOS ? 'Apple Watch' : 'Health Connect';
      _connected = true;
    } catch (error) {
      _connected = false;
      _wearableSource = ResonaWearableSource.none;
      _wearableName = null;
      _error = error.toString();
      rethrow;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  /// Scan standard Bluetooth Heart Rate Service devices. The scan remains a
  /// settings-only action and does not disturb the currently playing track.
  Future<List<BleHrmDevice>> scanBluetoothDevices() async {
    _error = null;
    notifyListeners();
    try {
      if (Platform.isAndroid) {
        final statuses = await <Permission>[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
        final bluetoothGranted =
            statuses[Permission.bluetoothScan]?.isGranted == true &&
            statuses[Permission.bluetoothConnect]?.isGranted == true;
        final legacyGranted =
            statuses[Permission.locationWhenInUse]?.isGranted == true;
        if (!bluetoothGranted && !legacyGranted) {
          throw StateError(
            'Bluetooth permission is required to find a device.',
          );
        }
      } else {
        final status = await _bleProvider.requestPermission();
        if (status != 'granted') {
          throw StateError('Bluetooth permission was not granted.');
        }
      }
      await _bleProvider.warmAdapter();
      return await _bleProvider.scan(timeoutMs: 6000);
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> connectBluetooth(BleHrmDevice device) async {
    if (_connecting) return;
    _connecting = true;
    _error = null;
    notifyListeners();
    try {
      await _disconnectActiveTransport();
      await _ensureRuntime();
      await _bleProvider.connect(
        deviceId: device.deviceId,
        sessionId: 'resona_${DateTime.now().millisecondsSinceEpoch}',
        enableBattery: true,
      );
      _bleSubscription = _bleProvider.onHeartRate.listen(
        _ingestBluetoothSample,
        onError: (Object error) {
          _connected = false;
          _error = error.toString();
          notifyListeners();
        },
      );
      _wearableSource = ResonaWearableSource.bluetooth;
      _wearableName = device.name.isEmpty
          ? 'Bluetooth heart-rate monitor'
          : device.name;
      _connected = true;
    } catch (error) {
      _connected = false;
      _wearableSource = ResonaWearableSource.none;
      _wearableName = null;
      _error = error.toString();
      rethrow;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnectWearable() async {
    _manualDisconnect = true;
    _endpoint = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _disconnectActiveTransport();
    _connected = false;
    _connecting = false;
    _wearableSource = ResonaWearableSource.none;
    _wearableName = null;
    _lastWearableSampleAt = null;
    _heartRateBpm = null;
    _error = null;
    notifyListeners();
  }

  Future<void> _connect(Uri endpoint) async {
    _connecting = true;
    _connected = false;
    _error = null;
    notifyListeners();
    try {
      await _ensureRuntime();
      final previousSubscription = _socketSubscription;
      final previousSocket = _socket;
      _socketSubscription = null;
      _socket = null;
      await previousSubscription?.cancel();
      await previousSocket?.close();
      final socket = await WebSocket.connect(
        endpoint.toString(),
      ).timeout(const Duration(seconds: 8));
      if (_manualDisconnect || _endpoint != endpoint) {
        await socket.close();
        return;
      }
      _socket = socket;
      _socketSubscription = socket.listen(
        _ingestMessage,
        onError: (Object error) {
          if (identical(_socket, socket)) {
            _markDisconnected(error.toString());
          }
        },
        onDone: () {
          if (identical(_socket, socket)) _markDisconnected(null);
        },
        cancelOnError: false,
      );
      _connecting = false;
      _connected = true;
      _reconnectAttempt = 0;
      _error = null;
      notifyListeners();
    } catch (error) {
      _connecting = false;
      _connected = false;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _ensureRuntime() async {
    if (_runtimeReady) return;
    await Synheart.initialize(
      config: SynheartConfig(
        appId: 'ai.synheart.resona',
        subjectId: 'resona-listener',
        appVersion: '1.0.0',
        appName: 'Resona',
        category: 'Music',
        developer: 'Synheart AI',
        allowUnsignedCapabilities: true,
        wearConfig: const WearConfig(enableHighFrequencyHrv: true),
        behaviorConfig: const BehaviorConfig(),
        consentConfig: ConsentConfig(
          deviceId: 'resona-${Platform.operatingSystem}-device',
          platform: Platform.operatingSystem,
          userId: 'resona-listener',
        ),
      ),
    );

    final form = Synheart.consentGetEditableFormTyped();
    if (form != null) {
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
    }

    _hsiSubscription = Synheart.onStateUpdate.listen(
      _handleHsi,
      onError: (Object error) {
        _error = error.toString();
        notifyListeners();
      },
    );
    await Synheart.startSession();
    Synheart.setTaskType(TaskType.focus);
    Synheart.setFocusKind(FocusKind.medium);
    _runtimeReady = true;
  }

  void recordInteraction() {
    if (!_runtimeReady) return;
    Synheart.pushBehaviorTouch(DateTime.now().millisecondsSinceEpoch);
  }

  void _ingestMessage(dynamic message) {
    if (message is! String) return;
    final dynamic decoded;
    try {
      decoded = jsonDecode(message);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic> || decoded['schema'] is! String) {
      return;
    }

    if (decoded['presentation_mode'] == false) {
      _presentationMode = false;
      _lastPresentationCue = null;
      _recommendation = null;
      _displayState = null;
      _candidate = null;
      _candidateWindows = 0;
      notifyListeners();
    }
    final presentationCue = decoded['presentation_cue'] as String?;
    if (presentationCue != null) {
      _applyPresentationCue(presentationCue);
    }

    if (decoded['schema'] != 'ai.synheart.wearsim.signal.v1') return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final profile = decoded['device_profile'] as String?;
    final provider = profile == 'apple_watch_workout_v1'
        ? 'watch_sample'
        : 'ble_hrm';
    final heartRate = (decoded['heart_rate_bpm'] as num?)?.toDouble();
    if (heartRate != null && heartRate > 0) {
      _heartRateBpm = heartRate;
      _lastWearableSampleAt = DateTime.now();
      Synheart.pushWearHr(nowMs, heartRate, provider: provider);
    } else if (decoded['signal_state'] == 'lost') {
      _heartRateBpm = null;
    }

    final rr = (decoded['rr_intervals_ms'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((value) => value.toDouble())
        .where((value) => value > 0)
        .toList();
    if (rr.isNotEmpty) {
      Synheart.pushRrBatch(nowMs, rr, provider: provider);
    }

    final motion = decoded['motion_samples'] as List<dynamic>? ?? const [];
    for (var index = 0; index < motion.length; index++) {
      final sample = motion[index];
      if (sample is! Map<String, dynamic>) continue;
      final x = (sample['x'] as num?)?.toDouble();
      final y = (sample['y'] as num?)?.toDouble();
      final z = (sample['z'] as num?)?.toDouble();
      if (x == null || y == null || z == null) continue;
      final timestamp = nowMs - (motion.length - 1 - index) * 40;
      Synheart.pushAccel(timestamp, x, y, z);
    }
    notifyListeners();
  }

  void _ingestPlatformWearSample(WearSample sample) {
    final timestamp = sample.timestamp.millisecondsSinceEpoch;
    final heartRate = sample.hr;
    if (heartRate != null && heartRate > 0) {
      _heartRateBpm = heartRate;
      _lastWearableSampleAt = DateTime.now();
      Synheart.pushWearHr(timestamp, heartRate, provider: 'sdk_wear');
    }
    final rr =
        sample.rrIntervals
            ?.where((value) => value > 0)
            .toList(growable: false) ??
        const <double>[];
    if (rr.isNotEmpty) {
      Synheart.pushRrBatch(timestamp, rr, provider: 'sdk_wear');
    }
    final hrv = sample.hrvRmssd;
    if (hrv != null && hrv > 0) {
      Synheart.pushVendorHrv(timestamp, rmssd: hrv, provider: 'sdk_wear');
    }
    notifyListeners();
  }

  void _ingestBluetoothSample(HeartRateSample sample) {
    if (sample.bpm <= 0) return;
    _heartRateBpm = sample.bpm;
    _lastWearableSampleAt = DateTime.now();
    Synheart.pushWearHr(sample.tsMs, sample.bpm, provider: 'ble_hrm');
    final rr = sample.rrIntervalsMs
        .where((value) => value > 0)
        .toList(growable: false);
    if (rr.isNotEmpty) {
      Synheart.pushRrBatch(sample.tsMs, rr, provider: 'ble_hrm');
    }
    notifyListeners();
  }

  Future<void> _disconnectActiveTransport() async {
    final previousSource = _wearableSource;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final socketSubscription = _socketSubscription;
    final socket = _socket;
    _socketSubscription = null;
    _socket = null;
    await socketSubscription?.cancel();
    await socket?.close();

    await _platformWearSubscription?.cancel();
    _platformWearSubscription = null;
    if (Synheart.isWearCollecting) {
      try {
        await Synheart.stopWearCollection();
      } catch (_) {}
    }

    await _bleSubscription?.cancel();
    _bleSubscription = null;
    if (previousSource == ResonaWearableSource.bluetooth) {
      try {
        await _bleProvider.disconnect();
      } catch (_) {}
    }

    _connected = false;
    _wearableSource = ResonaWearableSource.none;
    _wearableName = null;
    _lastWearableSampleAt = null;
    _heartRateBpm = null;
  }

  void _handleHsi(HSIState state) {
    _latestHsi = state;
    if (_presentationMode) {
      notifyListeners();
      return;
    }
    final next = _classify(state);
    if (next == null) {
      _candidate = null;
      _candidateWindows = 0;
      notifyListeners();
      return;
    }

    if (_candidate == next) {
      _candidateWindows++;
    } else {
      _candidate = next;
      _candidateWindows = 1;
    }
    if (_candidateWindows >= 1 && _recommendation?.mode != next) {
      final state = _forMode(next);
      _recommendation = state;
      _displayState = state;
    }
    notifyListeners();
  }

  void _applyPresentationCue(String cue) {
    _presentationMode = true;
    if (_lastPresentationCue == cue) return;
    _lastPresentationCue = cue;
    switch (cue) {
      case 'flow':
        _recommendation = _forMode(ResonaAdaptiveMode.flow);
        _displayState = _recommendation;
        break;
      case 'clarity':
        _recommendation = _forMode(ResonaAdaptiveMode.clarity);
        _displayState = _recommendation;
        break;
      case 'ease':
        _recommendation = _forMode(ResonaAdaptiveMode.ease);
        _displayState = _recommendation;
        break;
      case 'signal_settling':
        _recommendation = null;
        _displayState = _signalSettlingState;
        break;
      default:
        return;
    }
    notifyListeners();
  }

  ResonaAdaptiveMode? _classify(HSIState state) {
    final focus = _available(state.hsi.focus);
    final stress = _available(state.hsi.stress);
    final arousal = _available(state.hsi.arousal);
    final capacity = _available(state.hsi.capacity);

    if ((stress != null && stress >= .62) ||
        (arousal != null && arousal >= .76) ||
        (capacity != null && capacity <= .35)) {
      return ResonaAdaptiveMode.ease;
    }
    if (focus != null && focus <= .44) return ResonaAdaptiveMode.clarity;
    if (focus != null && focus >= .60) return ResonaAdaptiveMode.flow;
    return null;
  }

  double? _available(HSIAxisValue? axis) {
    if (axis == null || axis.confidence < .45) return null;
    return axis.value;
  }

  ResonaRecommendation _forMode(ResonaAdaptiveMode mode) => switch (mode) {
    ResonaAdaptiveMode.flow => const ResonaRecommendation(
      mode: ResonaAdaptiveMode.flow,
      label: 'Flow',
      headline: 'You’re settling into flow',
      message: 'A steady soundtrack can support your momentum.',
      targetTrackIndex: 1,
      stateAsset: 'assets/states/d16cbf7e-5125-4b51-ad96-eada0666f402.png',
    ),
    ResonaAdaptiveMode.clarity => const ResonaRecommendation(
      mode: ResonaAdaptiveMode.clarity,
      label: 'Finding focus',
      headline: 'Your focus is drifting',
      message: 'A clearer rhythm may help you reconnect.',
      targetTrackIndex: 2,
      stateAsset: 'assets/states/a863c00f-2322-4277-ab3c-e6efff2c745f.png',
    ),
    ResonaAdaptiveMode.ease => const ResonaRecommendation(
      mode: ResonaAdaptiveMode.ease,
      label: 'Resetting',
      headline: 'Your rhythm has picked up',
      message: 'A softer soundtrack may help you settle.',
      targetTrackIndex: 6,
      stateAsset: 'assets/states/4081ec38-2646-4ffd-bd52-c5226b4299f7.png',
    ),
  };

  static const _listeningState = ResonaRecommendation(
    mode: ResonaAdaptiveMode.flow,
    label: 'Listening',
    headline: 'We’re listening to your rhythm',
    message: 'Resona is learning your current rhythm.',
    targetTrackIndex: -1,
    stateAsset: 'assets/states/a863c00f-2322-4277-ab3c-e6efff2c745f.png',
  );

  static const _signalSettlingState = ResonaRecommendation(
    mode: ResonaAdaptiveMode.clarity,
    label: 'Signal settling',
    headline: 'Your signal is settling',
    message: 'Movement is affecting the reading. Stay still for a moment.',
    targetTrackIndex: -1,
    stateAsset: 'assets/states/a863c00f-2322-4277-ab3c-e6efff2c745f.png',
  );

  void _markDisconnected(String? error) {
    _socket = null;
    _socketSubscription = null;
    _connecting = false;
    _connected = false;
    _error = error;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final endpoint = _endpoint;
    if (_manualDisconnect ||
        endpoint == null ||
        _connecting ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    const delays = [1, 2, 4, 8];
    final delay = delays[_reconnectAttempt.clamp(0, delays.length - 1)];
    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      _reconnectTimer = null;
      if (_manualDisconnect || _endpoint != endpoint) return;
      try {
        await _connect(endpoint);
      } catch (_) {
        _reconnectAttempt++;
        _scheduleReconnect();
      }
    });
  }
}
