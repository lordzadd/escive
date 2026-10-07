import 'package:flutter/material.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/protocols/vicont.dart';

/// Extra Vicont controls share the panel's live refresh subscription.
class VicontDetails extends StatelessWidget {
  const VicontDetails(
      {super.key,
      required this.bridge,
      required this.activity,
      required this.stationary});
  final VicontBridge bridge;
  final Map activity;
  final bool stationary;

  Widget value(String label, String key, [String unit = '']) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
          activity[key] == null ? 'Not reported' : '${activity[key]}$unit'));
  Widget flag(String label, String key) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(activity[key] == null
          ? 'Not reported'
          : activity[key] == true
              ? 'On'
              : 'Off'));

  String tuningLabel(int code) {
    final raw = bridge.settings[code];
    if (raw == null) return 'No response yet — read scooter settings';
    if (code == 0x3c) return raw >= 99 ? 'Full speed' : '$raw km/h';
    final maximum = code == 0x3f ? 9 : 10;
    final scale = bridge.settingScales[code] ?? 200;
    final level = (raw / scale * maximum).clamp(0, maximum).toStringAsFixed(1);
    return 'Level $level / $maximum';
  }

  Future<void> tune(BuildContext context, int code, String label) async {
    final raw = bridge.settings[code];
    if (raw == null) return;
    final min = code == 0x3f ? 0 : 1;
    final max = code == 0x3c
        ? 99
        : code == 0x3f
            ? 9
            : 10;
    final scale = bridge.settingScales[code] ?? 200;
    var selected = (code == 0x3c ? raw.toDouble() : raw / scale * max)
        .round()
        .clamp(min, max)
        .toDouble();
    final chosen = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: Text(label),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Keep the scooter stationary. Changes affect riding behavior.'),
                    const SizedBox(height: 12),
                    Text(code == 0x3c
                        ? (selected >= 99
                            ? 'Full speed'
                            : '${selected.round()} km/h')
                        : 'Level ${selected.round()}'),
                    Slider(
                        min: min.toDouble(),
                        max: max.toDouble(),
                        divisions: max - min,
                        value: selected,
                        onChanged: (v) => setState(() => selected = v)),
                    const Text('Some changes require a scooter restart.'),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, selected.round()),
                        child: const Text('Apply'))
                  ],
                )));
    if (chosen == null || !context.mounted) return;
    final readBack = await bridge.setTuning(code, chosen);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(readBack
            ? 'Scooter response received. Check the reported setting.'
            : 'No confirmed setting response. Read settings again.')));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Scooter display in miles'),
            subtitle: const Text('Changes the unit setting on the scooter.'),
            value: activity['imperial'] == true,
            onChanged: stationary ? bridge.setUnits : null),
        const Divider(),
        Align(
            alignment: Alignment.centerLeft,
            child: Text('Ride modes',
                style: Theme.of(context).textTheme.titleMedium)),
        Wrap(spacing: 8, children: [
          for (final mode in {1: 'ECO', 2: 'COMFORT', 3: 'SPORT'}.entries)
            ChoiceChip(
                label: Text(mode.value),
                selected: bridge.settings[0x4a] == mode.key,
                onSelected: stationary &&
                        !bridge.readingSettings &&
                        bridge.settings.containsKey(0x4a) &&
                        bridge.gears.contains(mode.key)
                    ? (_) async {
                        final ok = await bridge.setRideMode(mode.key);
                        if (context.mounted && !ok) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Mode not confirmed. Read settings again.')));
                        }
                      }
                    : null),
        ]),
        Text(bridge.settingsMessage),
        OutlinedButton.icon(
            onPressed: bridge.ready && !bridge.readingSettings
                ? bridge.readSettings
                : null,
            icon: bridge.readingSettings
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(
                bridge.readingSettings ? 'Reading…' : 'Read scooter settings')),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Performance settings'),
            subtitle: const Text('Speed, torque and electronic brake'),
            children: [
              for (final item in {
                0x3c: 'Maximum speed',
                0x3d: 'Starting torque',
                0x3e: 'Driving torque',
                0x3f: 'Electronic brake strength'
              }.entries)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.value),
                    subtitle: Text(tuningLabel(item.key)),
                    trailing: const Icon(Icons.edit_outlined),
                    enabled: stationary &&
                        !bridge.readingSettings &&
                        bridge.settings.containsKey(item.key),
                    onTap: stationary &&
                            !bridge.readingSettings &&
                            bridge.settings.containsKey(item.key)
                        ? () => tune(context, item.key, item.value)
                        : null),
            ]),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Live diagnostics'),
            subtitle: Text(bridge.ready
                ? 'Telemetry from the scooter'
                : 'Last received values — not live'),
            children: [
              value('Voltage', 'voltage', ' V'),
              value('Controller temperature', 'controllerTemperature', ' °C'),
              value('Motor temperature', 'motorTemperature', ' °C'),
              value('Battery temperature', 'batteryTemperature', ' °C'),
              value('Motor speed', 'motorRpm', ' RPM'),
              flag('Powered on', 'poweredOn'),
              flag('Electronic lock', 'electronicLocked'),
              flag('Brake lock', 'brakeLocked'),
              flag('Braking', 'braking'),
              flag('Cruise active', 'cruiseActive'),
              flag('Charging', 'charging'),
              flag('Tail light', 'tailLight'),
              flag('Horn', 'horn'),
              flag('Left indicator', 'leftIndicator'),
              flag('Right indicator', 'rightIndicator'),
              flag('Ambient light', 'ambientLight'),
              flag('Bluetooth binding', 'bluetoothBound'),
              if (activity['faultBits'] == null)
                const ListTile(title: Text('Fault status not reported'))
              else if (activity['faultBits'] == 0)
                const ListTile(title: Text('No faults reported'))
              else
                for (final fault
                    in VicontProtocol.faults(activity['faultBits'] as int))
                  ListTile(
                      leading:
                          const Icon(Icons.warning_amber, color: Colors.orange),
                      title: Text(fault)),
              value('Throttle sensor (raw)', 'throttleRaw'),
              value('Brake sensor 1 (raw)', 'brake1Raw'),
              value('Brake sensor 2 (raw)', 'brake2Raw'),
            ]),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Battery details'),
            children: [
              if (activity['bmsVoltage'] == null)
                const Text(
                    'This scooter has not reported battery-management data.'),
              value('Battery ID', 'bmsId'),
              value('Battery voltage', 'bmsVoltage', ' V'),
              value('Battery current', 'bmsCurrent', ' A'),
              value('Charge cycles', 'bmsCycles'),
              value('Capacity (raw)', 'bmsCapacityRaw'),
              value('Remaining capacity (raw)', 'bmsRemainingRaw'),
              value('Battery temperature', 'bmsTemperature', ' °C'),
              flag('Charging', 'bmsCharging'),
              flag('Discharging', 'bmsDischarging'),
              flag('Low-voltage protection', 'bmsLowVoltage'),
              flag('Overvoltage protection', 'bmsOvervoltage'),
              flag('Battery fault', 'bmsFault'),
            ]),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Device information'),
            children: [
              value('Instrument ID', 'instrumentId'),
              value('Instrument hardware', 'instrumentHardware'),
              value('Instrument software', 'instrumentSoftware'),
              value('Controller ID', 'controllerId'),
              value('Controller hardware', 'controllerHardware'),
              value('Controller software', 'controllerSoftware'),
            ]),
      ]);
}
