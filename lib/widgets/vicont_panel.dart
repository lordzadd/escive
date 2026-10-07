import 'dart:async';
import 'package:escive/widgets/vicont_details.dart';
import 'package:flutter/material.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;

class VicontPanel extends StatefulWidget {
  const VicontPanel({super.key, this.showPrimaryControls = true});
  final bool showPrimaryControls;

  @override
  State<VicontPanel> createState() => _VicontPanelState();
}

class _VicontPanelState extends State<VicontPanel> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // A const child does not rebuild when its parent reads new global state.
    _subscription = globals.socket.stream.listen((event) {
      if (event['type'] == 'refreshStates' &&
          (event['value'] as List).contains('home') &&
          mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bridge = globals.bridge;
    if (bridge is! VicontBridge) return const SizedBox.shrink();
    final a = globals.currentDevice['currentActivity'] as Map;
    final ready = bridge.ready;
    final stationary = ready && (a['speedKmh'] as num? ?? 0) <= 1;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showPrimaryControls)
                  Text('Parking and riding',
                      style: Theme.of(context).textTheme.titleLarge),
                Text(ready
                    ? 'Live scooter data'
                    : 'Waiting for current scooter data'),
                if (ready && !stationary)
                  const Text('Stop the scooter before changing its settings.'),
                if (a['voltage'] != null)
                  Text(
                      '${a['voltage']} V · Motor ${a['motorTemperature']} °C · Battery ${a['batteryTemperature']} °C'),
                if ((a['faultBits'] ?? 0) != 0)
                  Text('Scooter fault code: ${a['faultBits']}',
                      style: const TextStyle(color: Colors.red)),
                if (widget.showPrimaryControls) const Text('Parking lock'),
                Wrap(spacing: 8, children: [
                  if (widget.showPrimaryControls)
                    OutlinedButton(
                        onPressed: stationary
                            ? () => bridge.setLock(a['locked'] != true)
                            : null,
                        child: Text(a['locked'] == true ? 'Unlock' : 'Lock')),
                  if (widget.showPrimaryControls)
                    OutlinedButton(
                        onPressed: ready
                            ? () => bridge.turnLight(a['light'] != true)
                            : null,
                        child: Text(
                            a['light'] == true ? 'Light off' : 'Light on')),
                  for (int i = 0; i < bridge.gears.length; i++)
                    ChoiceChip(
                      label: Text('Gear ${bridge.gears[i]}'),
                      selected: a['gear'] == bridge.gears[i],
                      onSelected:
                          stationary ? (_) => bridge.setSpeedMode(i) : null,
                    ),
                  OutlinedButton(
                      onPressed: stationary ? () => bridge.findScooter() : null,
                      child: const Text('Find scooter')),
                ]),
                if (bridge.gears.isEmpty)
                  const Text(
                      'Available gears appear when the scooter reports them.'),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cruise control'),
                    value: a['cruise'] == true,
                    onChanged: stationary ? bridge.setCruise : null),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start without pushing'),
                    value: a['zeroStart'] == true,
                    onChanged: stationary ? bridge.setZeroStart : null),
                VicontDetails(
                    bridge: bridge, activity: a, stationary: stationary),
              ],
            )));
  }
}
