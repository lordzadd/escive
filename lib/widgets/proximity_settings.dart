import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/proximity_key.dart';
import 'package:escive/widgets/settings_tile.dart';

class ProximitySettings extends StatefulWidget {
  const ProximitySettings({super.key});

  @override
  State<ProximitySettings> createState() => _ProximitySettingsState();
}

class _ProximitySettingsState extends State<ProximitySettings> {
  Timer? _timer;
  bool _enabled = false;
  bool _busy = false;
  String _status = 'Proximity key is off.';

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _apply(Map<String, dynamic>? data) {
    if (!mounted || data == null) return;
    setState(() {
      _enabled = data['enabled'] == true;
      _status = data['status'] as String? ?? '';
      if (data['rssi'] != null) _status += ' Signal: ${data['rssi']} dBm.';
    });
  }

  Future<void> _refresh() async {
    if (_busy) return;
    try {
      _apply(await ProximityKey.channel
          .invokeMapMethod<String, dynamic>('proximityStatus'));
    } on PlatformException catch (_) {
      // Keep the last status while the host is unavailable.
    } on MissingPluginException catch (_) {}
  }

  Future<void> _change(bool enabled) async {
    if (_busy) return;
    final bridge = globals.bridge;
    if (enabled && (bridge is! VicontBridge || !bridge.ready)) {
      setState(() => _status =
          'Connect your Vicont scooter before enabling the proximity key.');
      return;
    }
    setState(() => _busy = true);
    try {
      _apply(await ProximityKey.channel
          .invokeMapMethod<String, dynamic>('proximityConfigure', {
        'enabled': enabled,
        'address': globals.currentDevice['bluetoothAddress'],
      }));
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.message ?? 'Could not change the proximity key.');
      }
    } on MissingPluginException catch (_) {
      if (mounted) setState(() => _status = 'Install the latest eScive build.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ProximityKey.supported) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SettingsSection(title: 'Scooter key'),
      SettingsTile.toggle(
        context: context,
        title: 'Proximity key (experimental)',
        subtitle: 'Unlock on approach. Lock when walking away.\n$_status',
        value: _enabled,
        onChanged: _change,
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 20),
        child: Text('Stay beside the scooter for a few seconds to arm it. '
            'Keep Bluetooth on and leave eScive running in the background. '
            'The scooter must stay powered and report zero speed. '
            'Check the P indicator after walking away. Signal loss does not prove locking. '
            'A manual lock stays locked until you leave and return. '
            'Bluetooth signal strength does not provide a secure distance check.'),
      ),
    ]);
  }
}
