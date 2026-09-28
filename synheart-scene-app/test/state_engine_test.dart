import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/state_engine.dart';
import 'package:scene/domain/state.dart';

import 'support/fake_signals.dart';

const unwind = CurrentState(stress: AxisReading(0.8, 0.8), source: StateSource.synheart);
const engaged = CurrentState(focus: AxisReading(0.8, 0.8), source: StateSource.synheart);
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
    expect(fake.calls, isEmpty);
  });

  test('consent starts the runtime; a source starts listening', () async {
    await engine.consent();
    await engine.connectPlatformHealth();
    expect(fake.calls, ['start', 'disconnect', 'health']);
    expect(engine.source, WearableSource.platformHealth);
    expect(engine.display, DisplayState.listening);
  });

  group('publishing', () {
    setUp(() async {
      await engine.consent();
      await engine.connectPlatformHealth();
    });

    test('the first reading with evidence is published, stamped and sourced', () {
      fake.emit(unwind);
      expect(published, hasLength(1));
      expect(published.single.capturedAt, now);
      expect(published.single.source, StateSource.synheart);
      expect(engine.display, DisplayState.need);
      expect(engine.experience, Experience.unwind);
    });

    test('a change of need is published only when two windows agree', () {
      fake.emit(unwind);
      fake.emit(engaged); // one window: not yet
      expect(published, hasLength(1));
      fake.emit(engaged); // second window: confirmed
      expect(published, hasLength(2));
      expect(published.last.suggestedExperience, Experience.stayEngaged);
    });

    test('a single flicker does not re-rank', () {
      fake.emit(unwind);
      fake.emit(engaged);
      fake.emit(unwind);
      fake.emit(engaged);
      expect(published, hasLength(1));
    });

    test('the same need is re-published every five minutes to keep it fresh', () {
      fake.emit(unwind);
      now = now.add(const Duration(minutes: 4));
      fake.emit(unwind);
      expect(published, hasLength(1));
      now = now.add(const Duration(minutes: 2));
      fake.emit(unwind);
      expect(published, hasLength(2));
    });

    test('low confidence is "not enough evidence", never a negative result', () {
      fake.emit(weak);
      expect(published, isEmpty);
      expect(engine.display, DisplayState.notEnoughEvidence);
    });

    test('liveness follows the heart-rate samples', () {
      fake.heartRateCtl.add(62);
      expect(engine.isLive, isTrue);
      expect(engine.heartRate, 62);
      now = now.add(const Duration(seconds: 46));
      expect(engine.isLive, isFalse);
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

    test('presentation cues drive the story and pause live readings', () async {
      await engine.consent();
      await engine.pairWearSim(Uri.parse('wearsim://pair?endpoint=ws://127.0.0.1:9/s'));
      expect(fake.calls.last, 'wearsim:ws://127.0.0.1:9/s');

      fake.cuesCtl.add('ease');
      expect(published.last.suggestedExperience, Experience.unwind);
      expect(published.last.source, StateSource.wearSim);

      fake.emit(engaged); // ignored while presenting
      fake.emit(engaged);
      expect(published, hasLength(1));

      fake.cuesCtl.add('signal_settling');
      expect(engine.display, DisplayState.settling);

      fake.cuesCtl.add('off');
      fake.emit(engaged);
      fake.emit(engaged);
      expect(published.last.suggestedExperience, Experience.stayEngaged);
    });
  });

  group('Galaxy Watch', () {
    test('connecting names the watch and streams like any other source', () async {
      await engine.consent();
      await engine.connectWatch();
      expect(fake.calls, ['start', 'disconnect', 'watch']);
      expect(engine.source, WearableSource.watch);
      expect(engine.sourceName, 'Galaxy Watch6');
      fake.heartRateCtl.add(71);
      expect(engine.isLive, isTrue);
    });

    test('no connected watch is reported, not silently ignored', () async {
      fake.watchName = null;
      await engine.consent();
      await expectLater(engine.connectWatch(), throwsStateError);
      expect(engine.source, WearableSource.none);
      expect(engine.error, contains('No watch is connected'));
    });
  });

  test('a failing runtime start is reported and consent is not recorded', () async {
    fake.failStart = StateError('runtime missing');
    await expectLater(engine.consent(), throwsStateError);
    expect(engine.consented, isFalse);
    expect(engine.error, contains('runtime missing'));
  });
}
