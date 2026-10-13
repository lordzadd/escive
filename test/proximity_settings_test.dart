import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/proximity_key.dart';
import 'package:escive/widgets/proximity_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ConnectedProximityBridge extends VicontBridge {
  @override
  bool get ready => true;
}

void main() {
  testWidgets(
      'proximity is opt-in, requires a scooter, and supports manual override',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final changes = <Map>[];
    final manual = <bool>[];
    var enabled = false;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(ProximityKey.channel, (call) async {
      if (call.method == 'manualParking') {
        manual.add(call.arguments as bool);
        return null;
      }
      if (call.method == 'proximityConfigure') {
        changes.add(call.arguments as Map);
        enabled = changes.last['enabled'] == true;
      }
      return {'enabled': enabled, 'status': 'Test status', 'rssi': -55};
    });
    globals.bridge = null;
    globals.currentDevice = {'bluetoothAddress': 'saved-scooter'};
    try {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: ProximitySettings()))));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      expect(changes, isEmpty);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(find.textContaining('Connect your Vicont scooter before'),
          findsOneWidget);
      globals.bridge = ConnectedProximityBridge();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changes.single, {'enabled': true, 'address': 'saved-scooter'});
      expect(tester.widget<Switch>(find.byType(Switch)).value, true);
      await ProximityKey.manual(true);
      await ProximityKey.manual(false);
      expect(manual, [true, false]);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changes.last['enabled'], false);
    } finally {
      await tester.pumpWidget(const SizedBox());
      globals.bridge = null;
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(ProximityKey.channel, null);
    }
  });
}
