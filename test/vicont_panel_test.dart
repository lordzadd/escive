import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/widgets/vicont_panel.dart';

void main() {
  testWidgets('disconnected scooter controls remain disabled', (tester) async {
    globals.bridge = VicontBridge();
    globals.currentDevice = {
      'currentActivity': {'locked': false, 'light': false}
    };
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: VicontPanel())));
    expect(find.text('Waiting for current scooter data'), findsOneWidget);
    expect(find.text('Available gears appear when the scooter reports them.'),
        findsOneWidget);
    for (final button
        in tester.widgetList<OutlinedButton>(find.byType(OutlinedButton))) {
      expect(button.onPressed, isNull);
    }
    for (final control
        in tester.widgetList<SwitchListTile>(find.byType(SwitchListTile))) {
      expect(control.onChanged, isNull);
    }
    expect(await (globals.bridge as VicontBridge).setSpeedMode(0), false);
    globals.bridge = null;
  });
  testWidgets('Vicont panel is absent for other bridges', (tester) async {
    globals.bridge = null;
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: VicontPanel())));
    expect(find.text('Scooter settings'), findsNothing);
  });
}
