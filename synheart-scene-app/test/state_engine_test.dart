import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scene/app/signals.dart';
import 'package:scene/app/state_engine.dart';
import 'package:scene/domain/state.dart';

import 'support/fake_signals.dart';

const unwind = CurrentState(stress: AxisReading(0.8, 0.8), source: StateSource.synheart);
// Zero confidence: below the (temporary) "above 0" gate.
const weak = CurrentState(stress: AxisReading(0.9, 0.0), source: StateSource.synheart);

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

  group('continuous collection (2026-09-30)', () {
    test('consent asks for the behavior permissions and starts background collection', () async {
      await engine.consent();
      expect(fake.calls, ['start', 'permissions', 'background:on']);
      expect(fake.background, isTrue);
    });

    test('withdrawing consent stops background collection and the runtime', () async {
      await engine.consent();
      await engine.withdraw();
      expect(fake.calls.sublist(fake.calls.length - 2), ['background:off', 'stop']);
      expect(fake.background, isFalse);
    });

    test('readings update the state live, without a check-in', () async {
      await engine.consent();
      await engine.connectPlatformHealth();
      expect(engine.display, DisplayState.listening);
      fake.emit(weak); // zero confidence: not used
      expect(published, isEmpty);
      fake.emit(unwind);
      expect(published.single.suggestedExperience, Experience.unwind);
      fake.emit(unwind);
      expect(published, hasLength(2));
    });

    test('a change of suggestion waits for a second reading; the same one publishes at once', () async {
      const easy = CurrentState(focus: AxisReading(0.2, 0.5), source: StateSource.synheart);
      const balanced = CurrentState(focus: AxisReading(0.5, 0.5), source: StateSource.synheart);
      await engine.consent();
      await engine.connectPlatformHealth();
      fake.emit(balanced);
      expect(published.single.suggestedExperience, isNull, reason: 'the first reading publishes');
      fake.emit(easy);
      expect(published, hasLength(1), reason: 'Easy watch seen once: held');
      fake.emit(balanced);
      expect(published, hasLength(2), reason: 'back to Balanced: same as published, so at once');
      expect(published.last.suggestedExperience, isNull);
      fake.emit(easy);
      fake.emit(easy);
      expect(published, hasLength(3), reason: 'confirmed by a second reading');
      expect(published.last.suggestedExperience, Experience.easyWatch);
    });

    test('a check-in publishes its first reading even when the suggestion changes', () async {
      await engine.consent();
      await engine.connectPlatformHealth();
      fake.emit(const CurrentState(focus: AxisReading(0.5, 0.5), source: StateSource.synheart));
      expect(published, hasLength(1));
      await engine.startCheckIn();
      fake.emit(unwind);
      expect(published, hasLength(2));
      expect(engine.checkIn, CheckInPhase.done);
    });

    test('the chosen source stays connected', () async {
      await engine.consent();
      await engine.connectBluetooth(const WearableDevice('hrm-1', 'Polar H10'));
      expect(engine.source, WearableSource.bluetooth);
      expect(engine.chosenName, 'Polar H10');
    });
  });

  group('check-in', () {
    setUp(() async {
      await engine.consent();
      await engine.connectPlatformHealth();
      fake.calls.clear();
    });

    test('waits for the next reading with evidence, and collection continues after it', () async {
      await engine.startCheckIn();
      expect(fake.calls, isEmpty, reason: 'the source is already connected');
      expect(engine.checkIn, CheckInPhase.reading);

      fake.emit(weak); // no evidence: keep waiting
      expect(published, isEmpty);
      expect(engine.display, DisplayState.notEnoughEvidence);

      fake.emit(unwind);
      expect(published.single.suggestedExperience, Experience.unwind);
      expect(published.single.capturedAt, now);
      expect(engine.checkIn, CheckInPhase.done);
      await pumpEventQueue();
      expect(fake.calls, isNot(contains('disconnect')));
      expect(engine.source, WearableSource.platformHealth);

      fake.emit(unwind); // after the check-in: still live
      expect(published, hasLength(2));
    });

    test('with no confident reading it ends as "not enough signal" after the timeout', () {
      fakeAsync((async) {
        engine.startCheckIn();
        async.flushMicrotasks();
        fake.emit(weak);
        async.elapse(SceneStateEngine.checkInTimeout + const Duration(seconds: 1));
        expect(engine.checkIn, CheckInPhase.notEnoughSignal);
        expect(published, isEmpty);
        expect(fake.calls, isNot(contains('disconnect')), reason: 'collection continues');
      });
    });

    group('watchdog: a quiet streaming source is reconnected', () {
      // Moves the engine clock with the fake timers.
      void advance(FakeAsync async, Duration d) {
        for (var t = Duration.zero; t < d; t += const Duration(seconds: 5)) {
          now = now.add(const Duration(seconds: 5));
          async.elapse(const Duration(seconds: 5));
        }
      }

      int watchConnects() => fake.calls.where((c) => c == 'watch').length;

      test('no heart rate for a minute reconnects the watch, and again each minute', () {
        fakeAsync((async) {
          engine.consent();
          async.flushMicrotasks();
          engine.connectWatch();
          async.flushMicrotasks();
          expect(watchConnects(), 1);

          fake.heartRateCtl.add(72);
          advance(async, const Duration(seconds: 55));
          expect(watchConnects(), 1, reason: 'quiet for under a minute');
          expect(engine.sourceStalled, isFalse);

          advance(async, const Duration(seconds: 20));
          expect(watchConnects(), 2);
          expect(engine.sourceStalled, isTrue);
          expect(engine.restarts, 1);
          expect(fake.backgroundProblem, contains('reconnecting'));

          advance(async, const Duration(seconds: 30));
          expect(watchConnects(), 2, reason: 'waits a minute between restarts');
          advance(async, const Duration(seconds: 35));
          expect(watchConnects(), 3);

          fake.heartRateCtl.add(74);
          expect(engine.sourceStalled, isFalse);
          expect(fake.backgroundProblem, isNull);
          advance(async, const Duration(seconds: 50));
          expect(watchConnects(), 3);
          engine.dispose();
        });
      });

      test('an unreachable watch keeps its place, and readings do not reset the minute', () {
        fakeAsync((async) {
          engine.consent();
          async.flushMicrotasks();
          engine.connectWatch();
          async.flushMicrotasks();
          fake.watchUnreachable = true;
          advance(async, const Duration(seconds: 65));
          expect(watchConnects(), 2);
          expect(engine.source, WearableSource.watch);
          expect(engine.error, isNull);
          expect(fake.backgroundProblem, contains('not reachable'));

          // A behavior-only reading arrives between retries.
          advance(async, const Duration(seconds: 30));
          fake.emit(unwind);
          advance(async, const Duration(seconds: 35));
          expect(watchConnects(), 3, reason: 'still one minute apart');

          fake.watchUnreachable = false;
          advance(async, const Duration(seconds: 60));
          expect(watchConnects(), 4);
          fake.heartRateCtl.add(71);
          expect(engine.sourceStalled, isFalse);
          expect(fake.backgroundProblem, isNull);
          engine.dispose();
        });
      });

      test('a steady watch is left alone', () {
        fakeAsync((async) {
          engine.consent();
          async.flushMicrotasks();
          engine.connectWatch();
          async.flushMicrotasks();
          for (var i = 0; i < 60; i++) {
            fake.heartRateCtl.add(70);
            advance(async, const Duration(seconds: 5));
          }
          expect(watchConnects(), 1);
          expect(engine.restarts, 0);
          engine.dispose();
        });
      });

      test('Health Connect is never reconnected (batches, and a 7-day read)', () {
        fakeAsync((async) {
          engine.consent();
          async.flushMicrotasks();
          engine.connectPlatformHealth();
          async.flushMicrotasks();
          advance(async, const Duration(minutes: 5));
          expect(fake.calls.where((c) => c == 'health').length, 1);
          engine.dispose();
        });
      });

      test('withdrawing consent stops the watchdog', () {
        fakeAsync((async) {
          engine.consent();
          async.flushMicrotasks();
          engine.connectWatch();
          async.flushMicrotasks();
          engine.withdraw();
          async.flushMicrotasks();
          advance(async, const Duration(minutes: 3));
          expect(watchConnects(), 1);
        });
      });
    });

    group('diagnostics explain "not enough signal"', () {
      void timeOut(FakeAsync async, void Function() during) {
        engine.startCheckIn();
        async.flushMicrotasks();
        during();
        async.elapse(SceneStateEngine.checkInTimeout + const Duration(seconds: 1));
        expect(engine.checkIn, CheckInPhase.notEnoughSignal);
      }

      test('no heart rate at all', () {
        fakeAsync((async) {
          timeOut(async, () {});
          expect(engine.diagnostics!.heartRateSamples, 0);
          expect(engine.diagnostics!.diagnosis, startsWith('No heart rate arrived'));
        });
      });

      test('heart rate but no Synheart reading', () {
        fakeAsync((async) {
          timeOut(async, () {
            for (var i = 0; i < 5; i++) {
              fake.heartRateCtl.add(72);
            }
          });
          expect(engine.diagnostics!.heartRateSamples, 5);
          expect(engine.diagnostics!.readings, 0);
          expect(engine.diagnostics!.diagnosis, contains('Synheart produced no reading'));
        });
      });

      test('readings below the gate report the closest axis', () {
        fakeAsync((async) {
          timeOut(async, () {
            fake.heartRateCtl.add(72);
            fake.emit(weak);
            fake.emit(const CurrentState(stress: AxisReading(0.5, 0.0), arousal: AxisReading(0.5, 0.0), source: StateSource.synheart));
          });
          final d = engine.diagnostics!;
          expect(d.readings, 2);
          expect(d.best[HsiAxis.stress], 0.0);
          expect(d.best[HsiAxis.arousal], 0.0);
          expect(d.diagnosis, contains('at 0.00'));
        });
      });

      test('a new check-in starts fresh counts', () {
        fakeAsync((async) {
          timeOut(async, () => fake.heartRateCtl.add(72));
          engine.resetCheckIn();
          engine.startCheckIn();
          async.flushMicrotasks();
          expect(engine.diagnostics!.heartRateSamples, 0);
          engine.cancelCheckIn();
          async.flushMicrotasks();
        });
      });
    });

    test('cancelling ends the check-in, not collection', () async {
      await engine.startCheckIn();
      await engine.cancelCheckIn();
      expect(engine.checkIn, CheckInPhase.idle);
      expect(fake.calls, isNot(contains('disconnect')));
      expect(engine.source, WearableSource.platformHealth);
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
    test('connecting names the watch; a check-in keeps using it', () async {
      await engine.consent();
      await engine.connectWatch();
      expect(engine.source, WearableSource.watch);
      expect(engine.chosenName, 'Galaxy Watch6');
      await engine.startCheckIn();
      expect(fake.calls.where((c) => c == 'watch'), hasLength(1));
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

    test('a presentation cue updates the state live, and completes a check-in', () async {
      await engine.consent();
      await engine.pairWearSim(Uri.parse('wearsim://pair?endpoint=ws://127.0.0.1:9/s'));
      expect(fake.calls.last, 'wearsim:ws://127.0.0.1:9/s');

      fake.cuesCtl.add('ease'); // outside a check-in: live, like any reading
      expect(published.single.suggestedExperience, Experience.unwind);
      expect(published.single.source, StateSource.wearSim);

      await engine.startCheckIn();
      fake.cuesCtl.add('clarity');
      expect(published, hasLength(2));
      expect(engine.checkIn, CheckInPhase.done);
    });
  });

  test('a failing runtime start is reported and consent is not recorded', () async {
    fake.failStart = StateError('runtime missing');
    await expectLater(engine.consent(), throwsStateError);
    expect(engine.consented, isFalse);
    expect(engine.error, contains('runtime missing'));
  });

  group('consent and the source survive a restart', () {
    Future<SharedPreferences> prefs() async {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }

    test('agreed once and the watch connected: a new engine restores both', () async {
      final p = await prefs();
      final first = SceneStateEngine(fake, onPublish: published.add, clock: () => now, prefs: p);
      await first.consent();
      await first.connectWatch();

      final again = FakeSignals();
      final second = SceneStateEngine(again, onPublish: published.add, clock: () => now, prefs: p);
      expect(second.consented, isFalse);
      await second.restore();
      expect(second.consented, isTrue);
      expect(again.calls, containsAllInOrder(['start', 'background:on', 'watch']));
      expect(second.source, WearableSource.watch);
    });

    test('a Bluetooth strap is reconnected by its id', () async {
      final p = await prefs();
      final first = SceneStateEngine(fake, onPublish: published.add, clock: () => now, prefs: p);
      await first.consent();
      await first.connectBluetooth(const WearableDevice('hrm-1', 'Polar H10'));
      final again = FakeSignals();
      final second = SceneStateEngine(again, onPublish: published.add, clock: () => now, prefs: p);
      await second.restore();
      expect(again.calls, contains('ble:hrm-1'));
      expect(second.chosenName, 'Polar H10');
    });

    test('withdrawing consent clears both: nothing is restored', () async {
      final p = await prefs();
      final first = SceneStateEngine(fake, onPublish: published.add, clock: () => now, prefs: p);
      await first.consent();
      await first.connectWatch();
      await first.withdraw();
      final again = FakeSignals();
      final second = SceneStateEngine(again, onPublish: published.add, clock: () => now, prefs: p);
      await second.restore();
      expect(second.consented, isFalse);
      expect(again.calls, isEmpty);
    });

    test('a disconnected source is not reconnected, but consent is kept', () async {
      final p = await prefs();
      final first = SceneStateEngine(fake, onPublish: published.add, clock: () => now, prefs: p);
      await first.consent();
      await first.connectWatch();
      await first.disconnectSource();
      final again = FakeSignals();
      final second = SceneStateEngine(again, onPublish: published.add, clock: () => now, prefs: p);
      await second.restore();
      expect(second.consented, isTrue);
      expect(again.calls, isNot(contains('watch')));
    });
  });
}
