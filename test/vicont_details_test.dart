import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/widgets/vicont_details.dart';

class DetailsBridge extends VicontBridge {
  final changes = <List<int>>[];
  @override
  bool get ready => true;
  @override
  Future<bool> setTuning(int code, int level) async {
    changes.add([code, level]);
    return true;
  }
}

void main() {
  testWidgets('phone-sized settings support editing and expanded diagnostics',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bridge = DetailsBridge();
    bridge.settings[0x3d] = 100;
    bridge.settingScales[0x3d] = 200;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: VicontDetails(
            bridge: bridge,
            stationary: true,
            activity: const {
              'faultBits': 129,
              'controllerTemperature': 32,
              'motorRpm': 1000,
            },
          )),
    ))));
    await tester.tap(find.text('Performance settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Starting torque'));
    await tester.tap(find.text('Starting torque'));
    await tester.pumpAndSettle();
    expect(find.text('Level 5'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(bridge.changes, [
      [0x3d, 5]
    ]);
    await tester.ensureVisible(find.text('Live diagnostics'));
    await tester.tap(find.text('Live diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Communication fault'), findsOneWidget);
    expect(find.text('Throttle sensor fault'), findsOneWidget);
    expect(find.text('32 °C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
