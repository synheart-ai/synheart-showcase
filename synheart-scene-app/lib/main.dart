import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/scene_cubit.dart';
import 'app/signals.dart';
import 'app/state_engine.dart';
import 'ui/routes.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final appLinks = AppLinks();
  final links = StreamController<Uri>();
  unawaited(appLinks.getInitialLink().then((u) => u == null ? null : links.add(u)));
  appLinks.uriLinkStream.listen(links.add);
  // Nothing starts here: the Synheart runtime starts only after consent.
  runApp(SceneApp(prefs: prefs, signals: SynheartSignals(), links: links.stream));
}

class SceneApp extends StatefulWidget {
  const SceneApp({super.key, this.prefs, required this.signals, this.links, this.clock});

  final SharedPreferences? prefs;
  final SignalBackend signals;

  /// Deep links (wearsim://pair?…).
  final Stream<Uri>? links;

  /// For tests of state freshness.
  final DateTime Function()? clock;

  @override
  State<SceneApp> createState() => _SceneAppState();
}

class _SceneAppState extends State<SceneApp> {
  late final GoRouter _router = buildRouter();
  late final SceneCubit _cubit = SceneCubit(prefs: widget.prefs, clock: widget.clock);
  late final SceneStateEngine _engine = SceneStateEngine(widget.signals, onPublish: _cubit.setCurrentState, clock: widget.clock);
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    _links = widget.links?.listen(_onLink);
  }

  /// A WearSim pairing link pairs at once if consent was given; otherwise it
  /// opens Settings, where consent comes first.
  Future<void> _onLink(Uri uri) async {
    if (uri.scheme != 'wearsim') return;
    if (!_engine.consented) {
      _router.push(Routes.settings, extra: uri);
      return;
    }
    try {
      await _engine.pairWearSim(uri);
    } catch (_) {
      _router.push(Routes.settings, extra: uri);
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    _engine.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: ChangeNotifierProvider.value(
          value: _engine,
          child: MaterialApp.router(
            title: 'Scene by Synheart',
            debugShowCheckedModeBanner: false,
            theme: sceneTheme(),
            routerConfig: _router,
          ),
        ),
      );
}
