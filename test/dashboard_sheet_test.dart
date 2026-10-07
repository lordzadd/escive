import 'package:escive/widgets/dashboard_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'telemetry rebuilds do not cancel dragging or scrolling a long sheet',
      (tester) async {
    late StateSetter refresh;
    late ScrollController scroll;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        refresh = setState;
        return DashboardSheet(
            hasBattery: true,
            builder: (context, controller) {
              scroll = controller;
              return ListView.builder(
                  controller: controller,
                  itemCount: 100,
                  itemExtent: 56,
                  itemBuilder: (_, i) => Text('Diagnostic $i'));
            });
      },
    ))));
    final sheet = find.byType(ListView);
    final gesture = await tester.startGesture(tester.getCenter(sheet));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    final height = tester.getSize(sheet).height;
    refresh(() {});
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(tester.getSize(sheet).height, greaterThan(height + 40));
    await gesture.up();
    await tester.pumpAndSettle();
    // Expand fully, then scroll the readout while status rebuilds arrive.
    await tester.drag(sheet, const Offset(0, -600));
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(tester.getCenter(sheet));
    await drag.moveBy(const Offset(0, -90));
    await tester.pump();
    final offset = scroll.offset;
    refresh(() {});
    await tester.pump();
    await drag.moveBy(const Offset(0, -90));
    await tester.pump();
    expect(scroll.offset, greaterThan(offset + 40));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
