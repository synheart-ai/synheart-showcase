import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/demo_log.dart';
import '../app/movie_info_store.dart';
import '../app/scene_cubit.dart';
import '../app/signals.dart';
import '../app/state_engine.dart';
import '../data/catalogue.dart';
import '../data/demo_scenarios.dart';
import 'check_in_parts.dart';
import 'theme.dart';
import 'widgets.dart';

/// Signal sources, kept out of the main experience as in Resona. Consent
/// comes first and nothing is collected before it (RFC §4.4, §6); each
/// source asks only for its own permissions, when it is chosen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.pendingLink});

  /// A WearSim link that arrived before consent was given.
  final Uri? pendingLink;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _link = TextEditingController();
  List<WearableDevice>? _devices;
  bool _scanning = false;

  late final SceneStateEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = context.read<SceneStateEngine>();
    if (widget.pendingLink != null) _link.text = '${widget.pendingLink}';
  }

  @override
  void dispose() {
    // Collection is continuous: leaving Settings keeps the source connected.
    _link.dispose();
    super.dispose();
  }

  DemoLog get _log => context.read<SceneCubit>().log;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // The engine keeps the error for display.
    }
  }

  Future<void> _consent() async {
    _log.record(DemoEvent.checkInConsented);
    await _run(_engine.consent);
    if (mounted && _engine.consented && widget.pendingLink != null) await _pair();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final found = await _engine.scanBluetooth();
      if (mounted) setState(() => _devices = found);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pair() async {
    final uri = Uri.tryParse(_link.text.trim());
    if (uri == null) return;
    await _run(() => _engine.pairWearSim(uri));
  }

  void _useDemo(DemoScenario d) {
    _log.record(DemoEvent.demoScenarioUsed, {'scenario': d.name});
    context.read<SceneCubit>().setCurrentState(d.state);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SceneStateEngine>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          if (!engine.consented) ..._consentCard(context, engine) else ...[..._sources(context, engine), const SizedBox(height: 28), _BehaviorSection(backend: engine.backend)],
          const SizedBox(height: 28),
          ..._demo(context),
          const SizedBox(height: 28),
          const _FilmData(),
        ],
      ),
    );
  }

  List<Widget> _consentCard(BuildContext context, SceneStateEngine engine) => [
        ConsentCard(
          busy: engine.busy,
          error: engine.error,
          onAgree: _consent,
          onSkip: () {
            _log.record(DemoEvent.checkInSkipped);
            Navigator.of(context).maybePop();
          },
        ),
      ];

  List<Widget> _sources(BuildContext context, SceneStateEngine engine) {
    final t = Theme.of(context).textTheme;
    final connected = engine.source != WearableSource.none;
    return [
      const Eyebrow('Heart-rate source'),
      const SizedBox(height: 6),
      Text(engine.chosenName ?? 'Choose a source', style: t.headlineSmall),
      const SizedBox(height: 4),
      Text(
        'Scene reads it continuously, also in the background, while you have agreed. Withdraw consent below to stop.',
        style: t.bodyMedium?.copyWith(color: SceneColors.sage),
      ),
      if (connected) ...[
        const SizedBox(height: 4),
        Text(
          engine.sourceStalled
              ? 'No heart rate for a minute · reconnecting every minute…'
              : engine.isLive
                  ? 'Signal arriving${engine.heartRate == null ? '' : ' · ${engine.heartRate!.round()} BPM'}'
                  : 'Waiting for a signal…',
          style: t.bodyMedium?.copyWith(color: SceneColors.sage),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => _run(_engine.disconnectSource), child: const Text('Disconnect')),
      ],
      if (engine.error != null) ...[
        const SizedBox(height: 10),
        Callout(title: 'Could not connect', child: Text(engine.error!)),
      ],
      const SizedBox(height: 18),
      _SourceTile(
        icon: Icons.watch_outlined,
        title: 'Apple Health / Health Connect',
        subtitle: 'Heart-rate and HRV records from your watch. You will be asked for permission.',
        onTap: engine.busy ? null : () => _run(_engine.connectPlatformHealth),
      ),
      if (engine.backend.supportsWatch)
        _SourceTile(
          icon: Icons.watch,
          title: 'Galaxy Watch',
          subtitle: 'Live heart rate from Scene on your watch. Heart rate only — some readings may stay unavailable.',
          onTap: engine.busy ? null : () => _run(_engine.connectWatch),
        ),
      _SourceTile(
        icon: Icons.bluetooth,
        title: 'Bluetooth heart-rate monitor',
        subtitle: 'The most direct live signal — a chest strap or arm band.',
        onTap: engine.busy || _scanning ? null : _scan,
        trailing: _scanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      ),
      if (_devices != null) ...[
        if (_devices!.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No heart-rate monitors found nearby.')),
        for (final d in _devices!)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 52),
            title: Text(d.name),
            trailing: const Icon(Icons.link),
            onTap: () => _run(() => _engine.connectBluetooth(d)),
          ),
      ],
      const SizedBox(height: 10),
      Text('WearSim demo source', style: t.titleMedium),
      const SizedBox(height: 4),
      Text('Open a wearsim:// pairing link, or paste one here.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
      const SizedBox(height: 8),
      TextField(
        controller: _link,
        decoration: const InputDecoration(hintText: 'wearsim://pair?endpoint=ws://…', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: engine.busy ? null : _pair, child: const Text('Pair WearSim')),
      const SizedBox(height: 18),
      TextButton(onPressed: () => _run(_engine.withdraw), child: const Text('Withdraw consent and stop Synheart')),
    ];
  }

  List<Widget> _demo(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return [
      Text('Presenting? Use demo data', style: t.titleMedium),
      const SizedBox(height: 4),
      Text('Seeded readings, labelled as demo data wherever they appear.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
      const SizedBox(height: 10),
      for (final d in DemoScenario.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: () => _useDemo(d),
            child: Text('Demo data: ${d.title} — ${d.purpose.toLowerCase()}', textAlign: TextAlign.center),
          ),
        ),
    ];
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.icon, required this.title, required this.subtitle, this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: SceneColors.ink),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: trailing ?? const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

/// Where posters and synopses come from, with TMDB's required attribution.
class _FilmData extends StatelessWidget {
  const _FilmData();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final movies = context.watch<MovieInfoStore>();
    final status = !movies.enabled
        ? 'No TMDB token in this build, so posters are typographic. Run with --dart-define-from-file=tmdb.json.'
        : movies.loading
            ? 'Fetching film data… ${movies.matched} of ${allFilms.length}'
            : movies.error ?? '${movies.matched} of ${allFilms.length} films matched on TMDB. Cached for offline use.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Film data', style: t.titleMedium),
        const SizedBox(height: 4),
        Text(status, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        if (movies.enabled && !movies.loading)
          TextButton(
            onPressed: () async {
              await movies.clear();
              await movies.refresh(allFilms);
            },
            child: const Text('Fetch film data again'),
          ),
        const SizedBox(height: 4),
        const TmdbCredit(
          lead: 'Posters, synopses and trailers come from TMDB (and trailers from YouTube), fetched over the internet; '
              'no health data is sent with them. Recommendations use Scene\'s own film tags.',
        ),
      ],
    );
  }
}

/// What behavior signals Scene collects, and Notification access (only the
/// person can grant it, in system Settings; re-checked on return).
class _BehaviorSection extends StatefulWidget {
  const _BehaviorSection({required this.backend});

  final SignalBackend backend;

  @override
  State<_BehaviorSection> createState() => _BehaviorSectionState();
}

class _BehaviorSectionState extends State<_BehaviorSection> with WidgetsBindingObserver {
  bool? _access;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final granted = await widget.backend.notificationAccessGranted();
    if (mounted) setState(() => _access = granted);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Eyebrow('Behavior signals'),
      const SizedBox(height: 6),
      Text(
        'Taps, scrolls and swipes in Scene, app switches, notification and call events, and motion — '
        'never content, text, senders or numbers. Collected continuously, also in the background.',
        style: t.bodyMedium?.copyWith(color: SceneColors.sage),
      ),
      const SizedBox(height: 10),
      if (_access == true)
        Text('Notification events: on', style: t.bodyMedium)
      else ...[
        Text('Notification events need Notification access.', style: t.bodyMedium),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: widget.backend.openNotificationAccess,
          child: const Text('Allow notification access'),
        ),
      ],
    ]);
  }
}
