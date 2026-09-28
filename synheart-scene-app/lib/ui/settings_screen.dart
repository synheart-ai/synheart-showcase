import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/demo_log.dart';
import '../app/movie_info_store.dart';
import '../app/scene_cubit.dart';
import '../app/signals.dart';
import '../app/state_engine.dart';
import '../data/catalogue.dart';
import '../data/demo_scenarios.dart';
import '../data/tmdb.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.pendingLink != null) _link.text = '${widget.pendingLink}';
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  SceneStateEngine get _engine => context.read<SceneStateEngine>();
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
          if (!engine.consented) ..._consentCard(context, engine) else ..._sources(context, engine),
          const SizedBox(height: 28),
          ..._demo(context),
          const SizedBox(height: 28),
          const _FilmData(),
        ],
      ),
    );
  }

  List<Widget> _consentCard(BuildContext context, SceneStateEngine engine) {
    final t = Theme.of(context).textTheme;
    return [
      const Eyebrow('Before you connect'),
      const SizedBox(height: 6),
      Text('Let Scene read your current state', style: t.headlineSmall),
      const SizedBox(height: 12),
      Text(
        'Scene can use a wearable to suggest films that may fit this evening. Nothing is collected until you agree.',
        style: t.bodyLarge,
      ),
      const SizedBox(height: 16),
      const _Point(
        icon: Icons.favorite_border,
        title: 'What is read',
        text: 'Heart rate and heart-rate variability from the one source you choose.',
      ),
      const _Point(
        icon: Icons.phone_iphone,
        title: 'Where',
        text: 'Synheart computes focus, stress, arousal and capacity on this device. Cloud upload is off.',
      ),
      const _Point(
        icon: Icons.visibility_outlined,
        title: 'What you see',
        text: 'Words, not medical scores. Readings Synheart is not confident about are treated as unavailable.',
      ),
      const _Point(
        icon: Icons.history,
        title: 'What is kept',
        text: 'Only the latest reading and its time, until you reset the demo. Disconnect at any time.',
      ),
      if (engine.error != null) ...[
        const SizedBox(height: 8),
        Callout(title: 'Synheart could not start', child: Text(engine.error!)),
      ],
      const SizedBox(height: 12),
      FilledButton(
        onPressed: engine.busy ? null : _consent,
        child: Text(engine.busy ? 'Starting Synheart…' : 'I agree — continue'),
      ),
      TextButton(
        onPressed: () {
          _log.record(DemoEvent.checkInSkipped);
          Navigator.of(context).maybePop();
        },
        child: const Text('Not now — use my taste only'),
      ),
    ];
  }

  List<Widget> _sources(BuildContext context, SceneStateEngine engine) {
    final t = Theme.of(context).textTheme;
    final connected = engine.source != WearableSource.none;
    return [
      const Eyebrow('Signal source'),
      const SizedBox(height: 6),
      Text(connected ? engine.sourceName! : 'Choose a source', style: t.headlineSmall),
      if (connected) ...[
        const SizedBox(height: 4),
        Text(
          engine.isLive
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

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SceneColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium),
              Text(text, style: t.bodyMedium),
            ]),
          ),
        ],
      ),
    );
  }
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
        Text('Posters, synopses and trailers: TMDB. $tmdbAttribution Recommendations use Scene\'s own film tags.',
            style: t.bodySmall?.copyWith(color: SceneColors.sage)),
      ],
    );
  }
}
