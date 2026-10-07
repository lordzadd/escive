import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/watch_companion.dart';

class WatchTestBridge extends VicontBridge {
  bool available = true;
  final actions = <String>[];
  @override
  bool get ready => available;
  @override
  Future<bool> setLock(bool state) async {
    actions.add('lock:$state');
    return true;
  }

  @override
  Future<bool> turnLight(bool state) async {
    actions.add('light:$state');
    return true;
  }
}

void main() {
  testWidgets(
      'watch messages route to selected scooter and reject invalid requests',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final bridge = WatchTestBridge();
    globals.bridge = bridge;
    globals.currentDevice = {
      'id': 'scooter-a',
      'name': 'QA',
      'currentActivity': {'battery': 75, 'speedKmh': 0}
    };
    final snapshots = <Map>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('escive/watch'), (call) async {
      if (call.method == 'installation') {
        return {'version': 'test', 'build': '0'};
      }
      snapshots.add(call.arguments as Map);
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    WatchCompanion.start();
    Future<dynamic> send(String action, {String deviceId = 'scooter-a'}) async {
      final completer = Completer<ByteData?>();
      // Inject a native-to-Dart message, exercising the registered channel handler.
      // ignore: deprecated_member_use
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'escive/watch',
          const StandardMethodCodec().encodeMethodCall(
              MethodCall('command', {'action': action, 'deviceId': deviceId})),
          completer.complete);
      return const StandardMethodCodec()
          .decodeEnvelope((await completer.future)!);
    }

    try {
      for (final action in ['lock', 'unlock', 'lightOn', 'lightOff']) {
        expect(await send(action), {'sent': true});
      }
      expect(bridge.actions,
          ['lock:true', 'lock:false', 'light:true', 'light:false']);
      await expectLater(send('lock', deviceId: 'scooter-b'),
          throwsA(isA<PlatformException>()));
      await expectLater(send('unknown'), throwsA(isA<PlatformException>()));
      bridge.available = false;
      await expectLater(send('lock'), throwsA(isA<PlatformException>()));
      expect(bridge.actions.length, 4);
      await tester.pump(const Duration(seconds: 1));
      expect(snapshots.last['ready'], false);
      expect(snapshots.last['deviceId'], 'scooter-a');
      expect(snapshots.last['battery'], 75);
    } finally {
      WatchCompanion.stop();
      debugDefaultTargetPlatformOverride = null;
      globals.bridge = null;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('escive/watch'), null);
    }
  });
}
