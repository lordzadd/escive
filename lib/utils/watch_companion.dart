import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:escive/bridges/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;

class WatchCompanion {
  static const _channel = MethodChannel('escive/watch');
  static Timer? _timer;
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _channel.setMethodCallHandler(null);
  }

  static void start() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        _timer != null) {
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'command') throw MissingPluginException();
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final bridge = globals.bridge;
      if (bridge is! VicontBridge ||
          !bridge.ready ||
          args['deviceId'] != globals.currentDevice['id']) {
        throw PlatformException(
            code: 'unavailable',
            message: 'Open eScive and connect your scooter.');
      }
      bool sent;
      switch (args['action']) {
        case 'lock':
          sent = await bridge.setLock(true);
          break;
        case 'unlock':
          sent = await bridge.setLock(false);
          break;
        case 'lightOn':
          sent = await bridge.turnLight(true);
          break;
        case 'lightOff':
          sent = await bridge.turnLight(false);
          break;
        default:
          throw PlatformException(code: 'invalid', message: 'Unknown command.');
      }
      return {'sent': sent};
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final device = globals.currentDevice;
      final bridge = globals.bridge;
      final activity = device['currentActivity'] as Map? ?? {};
      try {
        await _channel.invokeMethod('snapshot', {
          'deviceId': device['id'] ?? '',
          'name': device['name'] ?? 'eScive',
          'ready': bridge is VicontBridge && bridge.ready,
          'battery': activity['battery'] ?? 0,
          'speed': activity['speedKmh'] ?? 0,
          'locked': activity['locked'] ?? false,
          'light': activity['light'] ?? false,
          'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
        });
      } on PlatformException catch (_) {
        // Watch availability must not stop the phone's Bluetooth connection.
      } on MissingPluginException catch (_) {}
    });
  }
}
