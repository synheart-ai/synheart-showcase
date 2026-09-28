import 'dart:async';

import 'package:scene/app/signals.dart';
import 'package:scene/domain/state.dart';

/// A SignalBackend driven by the test.
class FakeSignals implements SignalBackend {
  final readingsCtl = StreamController<CurrentState>.broadcast(sync: true);
  final heartRateCtl = StreamController<double>.broadcast(sync: true);
  final cuesCtl = StreamController<String>.broadcast(sync: true);
  final calls = <String>[];
  List<WearableDevice> devices = const [WearableDevice('hrm-1', 'Polar H10')];
  Object? failStart;

  @override
  Stream<CurrentState> get readings => readingsCtl.stream;
  @override
  Stream<double> get heartRate => heartRateCtl.stream;
  @override
  Stream<String> get cues => cuesCtl.stream;

  @override
  Future<void> start() async {
    calls.add('start');
    if (failStart != null) throw failStart!;
  }

  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> connectPlatformHealth() async => calls.add('health');
  @override
  Future<List<WearableDevice>> scanBluetooth() async {
    calls.add('scan');
    return devices;
  }

  @override
  Future<void> connectBluetooth(WearableDevice device) async => calls.add('ble:${device.id}');
  @override
  Future<void> connectWearSim(Uri endpoint) async => calls.add('wearsim:$endpoint');
  @override
  Future<void> disconnectSource() async => calls.add('disconnect');

  void emit(CurrentState s) => readingsCtl.add(s);
}
