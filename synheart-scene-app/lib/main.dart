import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/scene_cubit.dart';
import 'app/synheart.dart';
import 'ui/routes.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // The SDK is not started here: it starts only after consent on the check-in.
  runApp(SceneApp(prefs: prefs, synheart: SynheartService()));
}

class SceneApp extends StatefulWidget {
  const SceneApp({super.key, this.prefs, required this.synheart, this.clock});

  final SharedPreferences? prefs;
  final SynheartService synheart;

  /// For tests of state freshness.
  final DateTime Function()? clock;

  @override
  State<SceneApp> createState() => _SceneAppState();
}

class _SceneAppState extends State<SceneApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: 'Scene by Synheart',
      debugShowCheckedModeBanner: false,
      theme: sceneTheme(),
      routerConfig: _router,
    );
    return RepositoryProvider.value(
      value: widget.synheart,
      child: BlocProvider(
        create: (_) => SceneCubit(prefs: widget.prefs, clock: widget.clock),
        // No app-wide gesture detector: Scene uses typing signals only, and
        // only during a consented check-in.
        child: app,
      ),
    );
  }
}
