import 'package:escive/widgets/warning_light.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/widgets/vicont_panel.dart';
import 'support/fake_vicont_platform.dart';

void main() {
  final platform = FakeVicontPlatform();
  setUpAll(() {
    FlutterBluePlusPlatform.instance = platform;
  });
  late VicontBridge bridge;
  late BuildContext context;
  Future<void> pumpSteps(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> mount(WidgetTester tester) async {
    globals.devices = [];
    globals.settings = {'disableAutoBluetoothReconnection': true};
    globals.currentDevice = globals.generateDeviceMap()
      ..['protocol'] = 'vicont'
      ..['bluetoothAddress'] = 'QA-SCOOTER';
    bridge = VicontBridge();
    globals.bridge = bridge;
    platform.writes.clear();
    platform.failWrites = false;
    platform.exposeService = true;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const Scaffold(body: VicontPanel());
    })));
  }

  Future<void> connect(WidgetTester tester) async {
    bridge.init(context);
    await pumpSteps(tester, 15);
    expect(platform.writes.map((w) => w.value).toList(), [
      [250, 175, 165, 90, 1, 0, 91],
      [250, 175, 165, 250, 1, 0, 91]
    ]);
    expect(bridge.ready, false);
    platform.telemetry(gearMask: 0x45);
    await pumpSteps(tester, 2);
    expect(bridge.ready, true);
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.runAsync(() => bridge.dispose());
    await tester.pumpWidget(const SizedBox());
    await pumpSteps(tester, 100);
    globals.bridge = null;
  }

  for (final profile in ['fff0', 'fee0']) {
    testWidgets('$profile connects and all controls emit vendor packets',
        (tester) async {
      platform.profile = profile;
      platform.withoutResponseOnly = profile == 'fee0';
      await mount(tester);
      await connect(tester);
      expect(globals.currentDevice['currentActivity']['battery'], 75);
      expect(globals.currentDevice['stats']['totalDistanceKm'], 69);
      expect(bridge.gears, [1, 3, 7]);
      final commands = <Future<bool> Function()>[
        () => bridge.setLock(true),
        () => bridge.setLock(false),
        () => bridge.turnLight(true),
        () => bridge.turnLight(false),
        () => bridge.setSpeedMode(1),
        () => bridge.setCruise(true),
        () => bridge.setCruise(false),
        () => bridge.setZeroStart(true),
        () => bridge.setZeroStart(false),
        () => bridge.findScooter(),
      ];
      final payloads = [
        [51, 1],
        [51, 2],
        [69, 2],
        [69, 1],
        [66, 3],
        [54, 2],
        [54, 1],
        [53, 2],
        [53, 1],
        [52, 2]
      ];
      for (var i = 0; i < commands.length; i++) {
        final result = commands[i]();
        await pumpSteps(tester, 5);
        expect(await result, true);
        final code = payloads[i][0], value = payloads[i][1];
        expect(platform.writes.last.value,
            [250, 175, 165, 90, code, 1, value, (90 + code + 1 + value) & 255]);
      }
      expect(
          platform.writes.last.writeType,
          platform.withoutResponseOnly
              ? BmWriteType.withoutResponse
              : BmWriteType.withResponse);
      expect(globals.currentDevice['currentActivity']['locked'], false);
      platform.telemetry(locked: true, light: true);
      await pumpSteps(tester, 2);
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Light off'), findsOneWidget);
      await cleanup(tester);
    });
  }
  testWidgets(
      'movement, invalid gear, busy, and write failure do not report success',
      (tester) async {
    await mount(tester);
    await connect(tester);
    platform.telemetry(speedTenths: 123);
    await pumpSteps(tester, 2);
    final before = platform.writes.length;
    expect(await bridge.setLock(true), false);
    expect(await bridge.setSpeedMode(0), false);
    expect(await bridge.setCruise(true), false);
    expect(await bridge.setZeroStart(true), false);
    expect(await bridge.findScooter(), false);
    expect(await bridge.setSpeedMode(7), false);
    expect(platform.writes.length, before);
    final light = bridge.turnLight(true);
    expect(await bridge.turnLight(false), false);
    await pumpSteps(tester, 5);
    expect(await light, true);
    platform.failWrites = true;
    final failed = bridge.turnLight(false);
    await pumpSteps(tester, 5);
    expect(await failed, false);
    expect(globals.currentDevice['currentActivity']['light'], false);
    await cleanup(tester);
  });
  testWidgets('disconnect clears controls and supports a fresh connection',
      (tester) async {
    await mount(tester);
    await connect(tester);
    platform.connection(false);
    await pumpSteps(tester, 10);
    expect(bridge.ready, false);
    expect(bridge.gears, isEmpty);
    expect(find.text('Waiting for current scooter data'), findsOneWidget);
    expect(await bridge.turnLight(true), false);
    platform.writes.clear();
    await connect(tester);
    await cleanup(tester);
  });
  testWidgets('unsupported service fails without sending scooter commands',
      (tester) async {
    await mount(tester);
    platform.exposeService = false;
    bridge.init(context);
    await pumpSteps(tester, 15);
    expect(bridge.ready, false);
    expect(platform.writes, isEmpty);
    expect(globals.currentDevice['currentActivity']['state'], 'none');
    await cleanup(tester);
  });
  testWidgets('stale telemetry disables controls and does not send a command',
      (tester) async {
    await mount(tester);
    await connect(tester);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 6)));
    await pumpSteps(tester, 25);
    expect(bridge.ready, false);
    expect(find.text('Waiting for current scooter data'), findsOneWidget);
    final before = platform.writes.length;
    expect(await bridge.turnLight(true), false);
    expect(platform.writes.length, before);
    await cleanup(tester);
  });
  testWidgets(
      'automatic reconnect requires fresh telemetry before enabling controls',
      (tester) async {
    await mount(tester);
    await connect(tester);
    globals.settings['disableAutoBluetoothReconnection'] = false;
    final before = platform.connectCount;
    platform.connection(false);
    await pumpSteps(tester, 65);
    expect(platform.connectCount, before + 1);
    expect(bridge.ready, false);
    platform.telemetry();
    await pumpSteps(tester, 2);
    expect(bridge.ready, true);
    globals.settings['disableAutoBluetoothReconnection'] = true;
    await cleanup(tester);
  });
  testWidgets('a speed packet alone cannot enable status-dependent controls',
      (tester) async {
    await mount(tester);
    bridge.init(context);
    await pumpSteps(tester, 15);
    platform.notify([90, 16, 12, 16, 104, 0, 0, 0, 0, 75, 30, 31, 32, 0, 0]);
    await pumpSteps(tester, 2);
    expect(bridge.ready, false);
    expect(await bridge.setLock(true), false);
    expect(platform.writes.length, 2);
    await cleanup(tester);
  });
  testWidgets(
      'dashboard warning handlers update indicators without Bluetooth writes',
      (tester) async {
    await mount(tester);
    await connect(tester);
    final events = <Map>[];
    final subscription = globals.socket.stream.listen((event) {
      if (event['subtype'] == 'warningLight') events.add(event as Map);
    });
    final before = platform.writes.length;
    globals.currentDevice['currentActivity']['battery'] = 10;
    redefineBatteryWarn();
    redefinePositionWarn();
    globals.bridge.setWarningLight('vehicleLightOn', true);
    globals.bridge.setWarningLight('vehicleLocked', true);
    await pumpSteps(tester, 2);
    expect(events.map((e) => e['data']).toList(), [
      {'name': 'lowBattery', 'value': true},
      {'name': 'positionPrecisionDisabled', 'value': true},
      {'name': 'vehicleLightOn', 'value': true},
      {'name': 'vehicleLocked', 'value': true},
    ]);
    expect(platform.writes.length, before);
    await tester.runAsync(() => subscription.cancel());
    await cleanup(tester);
  });
}
