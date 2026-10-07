import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/widgets/vicont_panel.dart';

class TestVicontBridge extends VicontBridge {
  bool connected = false;
  final List<String> actions = [];
  @override
  Future<bool> turnLight(bool state) async {
    actions.add('light:$state');
    return true;
  }

  @override
  Future<bool> setLock(bool state) async {
    actions.add('lock:$state');
    return true;
  }

  @override
  bool get ready => connected;
}

void main() {
  testWidgets('mounted panel follows connection and telemetry changes',
      (tester) async {
    final bridge = TestVicontBridge();
    globals.bridge = bridge;
    globals.currentDevice = {
      'currentActivity': {'locked': false, 'light': false, 'speedKmh': 0}
    };
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: VicontPanel())));
    expect(find.text('Waiting for current scooter data'), findsOneWidget);

    bridge.connected = true;
    bridge.gears.addAll([1, 3]);
    globals.socket.add({
      'type': 'refreshStates',
      'value': ['home']
    });
    await tester.pump();
    expect(find.text('Waiting for current scooter data'), findsNothing);
    expect(find.text('Gear 3'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Gear 3'))
            .onSelected,
        isNotNull);

    await tester.tap(find.text('Light on'));
    await tester.tap(find.text('Lock'));
    expect(bridge.actions, ['light:true', 'lock:true']);
    // Sending a command must not fabricate scooter feedback.
    expect(find.text('Light on'), findsOneWidget);
    globals.currentDevice['currentActivity']['light'] = true;
    globals.socket.add({
      'type': 'refreshStates',
      'value': ['home']
    });
    await tester.pump();
    expect(find.text('Light off'), findsOneWidget);

    globals.currentDevice['currentActivity']['speedKmh'] = 12.3;
    globals.socket.add({
      'type': 'refreshStates',
      'value': ['home']
    });
    await tester.pump();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Gear 3'))
            .onSelected,
        isNull);

    bridge.connected = false;
    globals.socket.add({
      'type': 'refreshStates',
      'value': ['home']
    });
    await tester.pump();
    expect(find.text('Waiting for current scooter data'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    globals.bridge = null;
  });
}
