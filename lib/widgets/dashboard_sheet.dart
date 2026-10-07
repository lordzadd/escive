import 'package:flutter/material.dart';

/// Keep the snap configuration stable across frequent telemetry rebuilds.
class DashboardSheet extends StatelessWidget {
  const DashboardSheet(
      {super.key, required this.hasBattery, required this.builder});
  final bool hasBattery;
  final ScrollableWidgetBuilder builder;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: hasBattery ? 0.37 : 0.45,
        minChildSize: hasBattery ? 0.37 : 0.45,
        maxChildSize: 0.975,
        snap: true,
        // The endpoints are implicit. A new snapSizes list on each rebuild
        // makes Flutter call goBallistic(0), cancelling an active user drag.
        snapAnimationDuration: const Duration(milliseconds: 200),
        builder: builder,
      );
}
