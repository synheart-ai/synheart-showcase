import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/scene_cubit.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/domain/film.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scene starts on the demo profile and invites building your own
/// (reviewer feedback, 2026-10-02).
void main() {
  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  test('the demo profile is marked, and survives a restart', () async {
    final p = await prefs();
    final cubit = SceneCubit(prefs: p)..useAnswers(demoPersonaAnswers);
    expect(cubit.state.demoProfile, isTrue);
    expect(SceneCubit(prefs: p).state.demoProfile, isTrue);
  });

  test('building your own starts blank, and finishing it ends the demo', () async {
    final cubit = SceneCubit(prefs: await prefs())..useAnswers(demoPersonaAnswers);
    cubit.startOwnProfile();
    expect(cubit.state.answers.answeredCount, 0);
    expect(cubit.state.hasProfile, isTrue, reason: 'the demo stays in use meanwhile');
    cubit.toggleGenre(Genre.comedy);
    cubit.completeProfile();
    expect(cubit.state.demoProfile, isFalse);
  });

  test('editing the demo makes it your own', () async {
    final cubit = SceneCubit(prefs: await prefs())..useAnswers(demoPersonaAnswers);
    cubit.toggleGenre(Genre.horror);
    expect(cubit.state.demoProfile, isFalse);
  });
}
