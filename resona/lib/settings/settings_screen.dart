import 'dart:io';

import 'package:flutter/material.dart';
import 'package:synheart_wear/synheart_wear.dart';

import '../state/resona_state_engine.dart';

const _lime = Color(0xFFB9FF28);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Settings',
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -.4),
      ),
    ),
    body: AnimatedBuilder(
      animation: ResonaStateEngine.instance,
      builder: (context, _) {
        final engine = ResonaStateEngine.instance;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _ConnectionSummary(engine: engine),
            const SizedBox(height: 28),
            const _SectionLabel('WEARABLE SOURCES'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SourceRow(
                  icon: Icons.watch_rounded,
                  title: Platform.isIOS ? 'Apple Watch' : 'Health Connect',
                  subtitle: Platform.isIOS
                      ? 'Heart rate and HRV through Apple Health'
                      : 'Health data from supported Android wearables',
                  active:
                      engine.wearableSource == ResonaWearableSource.appleHealth,
                  busy: engine.connecting,
                  onTap: () => _togglePlatformHealth(context, engine),
                ),
                const _Divider(),
                _SourceRow(
                  icon: Icons.bluetooth_rounded,
                  title: 'Bluetooth heart-rate monitor',
                  subtitle:
                      engine.wearableSource == ResonaWearableSource.bluetooth
                      ? engine.wearableName ?? 'Connected'
                      : 'Chest straps and standard BLE heart-rate devices',
                  active:
                      engine.wearableSource == ResonaWearableSource.bluetooth,
                  busy: engine.connecting,
                  onTap: () => _openBluetoothPicker(context, engine),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _PrivacyNote(),
            if (engine.error != null) ...[
              const SizedBox(height: 16),
              Text(
                _cleanError(engine.error!),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE09595),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  static Future<void> _togglePlatformHealth(
    BuildContext context,
    ResonaStateEngine engine,
  ) async {
    try {
      if (engine.wearableSource == ResonaWearableSource.appleHealth) {
        await engine.disconnectWearable();
      } else {
        await engine.connectAppleHealth();
      }
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, _cleanError(error.toString()));
    }
  }

  static Future<void> _openBluetoothPicker(
    BuildContext context,
    ResonaStateEngine engine,
  ) async {
    if (engine.wearableSource == ResonaWearableSource.bluetooth) {
      await engine.disconnectWearable();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BluetoothPicker(engine: engine),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static String _cleanError(String value) => value
      .replaceFirst('Bad state: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');
}

class _ConnectionSummary extends StatelessWidget {
  const _ConnectionSummary({required this.engine});

  final ResonaStateEngine engine;

  @override
  Widget build(BuildContext context) {
    final connected = engine.wearableSource != ResonaWearableSource.none;
    final live = engine.hasLiveWearableSignal;
    final title = !connected
        ? 'No wearable connected'
        : live
        ? engine.wearableName ?? 'Wearable connected'
        : 'Waiting for ${engine.wearableName ?? 'wearable'} data';
    final subtitle = !connected
        ? 'Choose a source below when you want Resona to respond to your state.'
        : live
        ? 'Receiving a live signal'
        : 'Connected. New readings will appear when available.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF19231E), Color(0xFF101311)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: connected
                  ? _lime.withValues(alpha: .12)
                  : Colors.white.withValues(alpha: .055),
              shape: BoxShape.circle,
            ),
            child: Icon(
              live ? Icons.graphic_eq_rounded : Icons.favorite_border_rounded,
              color: connected ? _lime : const Color(0xFF858987),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8D918F),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (live && engine.heartRateBpm != null) ...[
            const SizedBox(width: 10),
            Text(
              '${engine.heartRateBpm!.round()}',
              style: const TextStyle(
                color: _lime,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 3),
            const Text(
              'BPM',
              style: TextStyle(
                color: Color(0xFF7D817F),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BluetoothPicker extends StatefulWidget {
  const _BluetoothPicker({required this.engine});

  final ResonaStateEngine engine;

  @override
  State<_BluetoothPicker> createState() => _BluetoothPickerState();
}

class _BluetoothPickerState extends State<_BluetoothPicker> {
  bool _scanning = true;
  String? _error;
  List<BleHrmDevice> _devices = const [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final devices = await widget.engine.scanBluetoothDevices();
      if (!mounted) return;
      setState(() => _devices = devices);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = SettingsScreen._cleanError(error.toString()));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(BleHrmDevice device) async {
    setState(() => _error = null);
    try {
      await widget.engine.connectBluetooth(device);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = SettingsScreen._cleanError(error.toString()));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .72,
    ),
    padding: EdgeInsets.fromLTRB(
      18,
      10,
      18,
      18 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: Color(0xFF111312),
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3C3B),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Bluetooth devices',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Keep your heart-rate device awake and nearby.',
          style: TextStyle(color: Color(0xFF8D918F), fontSize: 13),
        ),
        const SizedBox(height: 18),
        if (_scanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                CircularProgressIndicator(color: _lime),
                SizedBox(height: 16),
                Text(
                  'Looking for devices…',
                  style: TextStyle(color: Color(0xFF9A9D9B)),
                ),
              ],
            ),
          )
        else if (_devices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: Color(0xFF7F8381),
                  size: 34,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No heart-rate devices found',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: _scan, child: const Text('Scan again')),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _devices.length,
              separatorBuilder: (_, _) => const _Divider(),
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF202522),
                    foregroundColor: _lime,
                    child: Icon(Icons.favorite_rounded),
                  ),
                  title: Text(
                    device.name.isEmpty ? 'Heart-rate monitor' : device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _signalLabel(device.rssi),
                    style: const TextStyle(color: Color(0xFF7F8381)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _connect(device),
                );
              },
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE09595), fontSize: 12),
          ),
        ],
      ],
    ),
  );

  static String _signalLabel(int rssi) {
    if (rssi >= -60) return 'Strong signal';
    if (rssi >= -75) return 'Good signal';
    return 'Nearby';
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: active
            ? _lime.withValues(alpha: .12)
            : Colors.white.withValues(alpha: .05),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: active ? _lime : const Color(0xFF959997),
        size: 21,
      ),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF7F8381),
          fontSize: 12,
          height: 1.25,
        ),
      ),
    ),
    trailing: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _lime),
          )
        : Text(
            active ? 'Disconnect' : 'Connect',
            style: TextStyle(
              color: active ? const Color(0xFF9A9D9B) : _lime,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
    onTap: busy ? null : onTap,
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF111312),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: .065)),
    ),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 70,
    color: Colors.white.withValues(alpha: .065),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 5),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6F7371),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.35,
      ),
    ),
  );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.lock_outline_rounded, color: Color(0xFF6E7471), size: 16),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Your wearable signals are processed on this device to shape the listening experience.',
            style: TextStyle(
              color: Color(0xFF6E7471),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
