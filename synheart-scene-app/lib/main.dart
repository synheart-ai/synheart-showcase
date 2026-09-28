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
  final synheart = await SynheartService.start();
  runApp(SceneApp(prefs: prefs, synheart: synheart));
}

class SceneApp extends StatefulWidget {
  const SceneApp({super.key, this.prefs, required this.synheart});

  final SharedPreferences? prefs;
  final SynheartService synheart;

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
        create: (_) => SceneCubit(prefs: widget.prefs),
        // The SDK's gesture detector must wrap the app for tap / scroll signals.
        child: widget.synheart.behavior?.wrapWithGestureDetector(app) ?? app,
      ),
    );
  }
}
