// QA-only entry point. Never use this target for a distributable build.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:escive/main.dart' as app;
import '../test/support/fake_vicont_platform.dart';

void main() {
  if (!kDebugMode) throw StateError('The scooter simulator is debug-only.');
  final platform = FakeVicontPlatform();
  FlutterBluePlusPlatform.instance = platform;
  var locked = false, light = false, cruise = false, zeroStart = false;
  var gear = 1;
  var electronic = false;
  platform.onWrite = (bytes) {
    debugPrint('QA TX: $bytes');
    if (bytes.length != 8) return;
    switch (bytes[4]) {
      case 0x33:
        electronic = locked = bytes[6] == 2;
        break;
      case 0x45:
        light = bytes[6] == 2;
        break;
      case 0x42:
        gear = bytes[6];
        break;
      case 0x36:
        cruise = bytes[6] == 2;
        break;
      case 0x35:
        zeroStart = bytes[6] == 2;
        break;
    }
  };
  Timer.periodic(const Duration(seconds: 1), (_) {
    if (platform.connectCount > platform.disconnectCount) {
      platform.telemetry(
          locked: electronic,
          brakeLocked: locked,
          bluetoothBound: locked,
          light: light,
          gear: gear,
          cruise: cruise,
          zeroStart: zeroStart);
    }
  });
  app.main();
}
