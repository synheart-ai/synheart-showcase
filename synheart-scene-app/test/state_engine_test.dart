import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/signals.dart';
import 'package:scene/app/state_engine.dart';
import 'package:scene/domain/state.dart';

import 'support/fake_signals.dart';

const unwind = CurrentState(stress: AxisReading(0.8, 0.8), source: StateSource.synheart);
const weak = CurrentState(stress: AxisReading(0.9, 0.3), source: StateSource.synheart);

void main() {
  late FakeSignals fake;
  late List<CurrentState> published;
  late DateTime now;
  late SceneStateEngine engine;

  setUp(() {
    fake = FakeSignals();
    published = [];
    now = DateTime(2026, 9, 28, 20);
    engine = SceneStateEngine(fake, onPublish: published.add, clock: () => now);
  });

  test('nothing connects before consent', () async {
    expect(engine.display, DisplayState.off);
    expect(() => engine.connectPlatformHealth(), throwsStateError);
    await expectLater(engine.startCheckIn(), throwsStateError);
    expect(fake.calls, isEmpty);
  });

  group('outside a check-in', () {
    test('a connected source only feeds the live view — readings never publish', () async {
      await engine.consent();
      await engine.connectPlatformHealth();
      expect(engine.display, DisplayState.listening);
      fake.emit(unwind);
      expect(published, isEmpty);
      expect(engine.latest, isNotNull);
    });

    test('leaving Settings pauses collection but remembers the source', () async {
      await engine.consent();
      await engine.connectBluetooth(const WearableDevice('hrm-1', 'Polar H10'));
      await engine.pauseSource();
      expect(engine.source, WearableSource.none);
      expect(fake.calls.last, 'disconnect');
      expect(engine.chosenName, 'Polar H10');
    });
  });

  group('check-in', () {
    setUp(() async {
      await engine.consent();
      await engine.connectPlatformHealth();
      await engine.pauseSource();
      fake.calls.clear();
    });

    test('reconnects the chosen source, publishes the first confident reading, then stops collecting', () async {
      await engine.startCheckIn();
      expect(fake.calls, ['disconnect', 'health']);
      expect(engine.checkIn, CheckInPhase.reading);

      fake.emit(weak); // not confident: keep reading
      expect(published, isEmpty);
      expect(engine.display, DisplayState.notEnoughEvidence);

      fake.emit(unwind);
      expect(published.single.suggestedExperience, Experience.unwind);
      expect(published.single.capturedAt, now);
      expect(engine.checkIn, CheckInPhase.done);
      await pumpEventQueue();
      expect(fake.calls.last, 'disconnect');
      expect(engine.source, WearableSource.none);

      fake.emit(unwind); // after the check-in: ignored
      expect(published, hasLength(1));
    });

    test('with no confident reading it ends as "not enough signal" after the timeout', () {
      fakeAsync((async) {
        engine.startCheckIn();
        async.flushMicrotasks();
        fake.emit(weak);
        async.elapse(SceneStateEngine.checkInTimeout + const Duration(seconds: 1));
        expect(engine.checkIn, CheckInPhase.notEnoughSignal);
        expect(published, isEmpty);
        expect(fake.calls.last, 'disconnect');
      });
    });

    test('cancelling stops collection', () async {
      await engine.startCheckIn();
      await engine.cancelCheckIn();
      expect(engine.checkIn, CheckInPhase.idle);
      expect(fake.calls.last, 'disconnect');
    });

    test('liveness follows the heart-rate samples', () async {
      await engine.startCheckIn();
      fake.heartRateCtl.add(62);
      expect(engine.isLive, isTrue);
      expect(engine.heartRate, 62);
      now = now.add(const Duration(seconds: 46));
      expect(engine.isLive, isFalse);
    });
  });

  group('Galaxy Watch', () {
    test('connecting names the watch; a check-in reconnects it', () async {
      await engine.consent();
      await engine.connectWatch();
      expect(engine.source, WearableSource.watch);
      expect(engine.chosenName, 'Galaxy Watch6');
      await engine.pauseSource();
      await engine.startCheckIn();
      expect(fake.calls.where((c) => c == 'watch'), hasLength(2));
      expect(engine.sourceName, 'Galaxy Watch6');
    });

    test('no connected watch is reported, not silently ignored', () async {
      fake.watchName = null;
      await engine.consent();
      await expectLater(engine.connectWatch(), throwsStateError);
      expect(engine.source, WearableSource.none);
      expect(engine.error, contains('No watch is connected'));
    });
  });

  group('WearSim', () {
    test('pairing links are validated', () {
      final at = DateTime(2026, 9, 28, 20);
      expect(SceneStateEngine.wearSimEndpoint(Uri.parse('wearsim://pair?endpoint=ws://192.168.1.5:8765/s'), now: at),
          Uri.parse('ws://192.168.1.5:8765/s'));
      expect(() => SceneStateEngine.wearSimEndpoint(Uri.parse('https://pair?endpoint=ws://x'), now: at), throwsFormatException);
      expect(() => SceneStateEngine.wearSimEndpoint(Uri.parse('wearsim://pair?endpoint=http://x'), now: at), throwsFormatException);
      final expired = at.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
      expect(() => SceneStateEngine.wearSimEndpoint(Uri.parse('wearsim://pair?endpoint=ws://x&expires=$expired'), now: at),
          throwsFormatException);
    });

    test('a presentation cue completes a check-in with its seeded reading', () async {
      await engine.consent();
      await engine.pairWearSim(Uri.parse('wearsim://pair?endpoint=ws://127.0.0.1:9/s'));
      expect(fake.calls.last, 'wearsim:ws://127.0.0.1:9/s');

      fake.cuesCtl.add('ease'); // outside a check-in: no effect on picks
      expect(published, isEmpty);

      await engine.startCheckIn();
      fake.cuesCtl.add('ease');
      expect(published.single.suggestedExperience, Experience.unwind);
      expect(published.single.source, StateSource.wearSim);
      expect(engine.checkIn, CheckInPhase.done);
    });
  });

  test('a failing runtime start is reported and consent is not recorded', () async {
    fake.failStart = StateError('runtime missing');
    await expectLater(engine.consent(), throwsStateError);
    expect(engine.consented, isFalse);
    expect(engine.error, contains('runtime missing'));
  });
}
