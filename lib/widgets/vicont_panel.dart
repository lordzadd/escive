import 'package:flutter/material.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;

class VicontPanel extends StatelessWidget {
  const VicontPanel({super.key});
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
                Text('Werhy / Vicont',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(ready
                    ? 'Live scooter data'
                    : 'Waiting for current scooter data'),
                const Text(
                    'Controls use scooter feedback. A sent command does not confirm a change.'),
                if (ready && !stationary)
                  const Text('Stop the scooter before changing its settings.'),
                if (a['voltage'] != null)
                  Text(
                      '${a['voltage']} V · Motor ${a['motorTemperature']} °C · Battery ${a['batteryTemperature']} °C'),
                if ((a['faultBits'] ?? 0) != 0)
                  Text('Scooter fault code: ${a['faultBits']}',
                      style: const TextStyle(color: Colors.red)),
                Wrap(spacing: 8, children: [
                  OutlinedButton(
                      onPressed: stationary
                          ? () => bridge.setLock(a['locked'] != true)
                          : null,
                      child: Text(a['locked'] == true ? 'Unlock' : 'Lock')),
                  OutlinedButton(
                      onPressed: ready
                          ? () => bridge.turnLight(a['light'] != true)
                          : null,
                      child:
                          Text(a['light'] == true ? 'Light off' : 'Light on')),
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
              ],
            )));
  }
}
