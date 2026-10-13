import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProximityKey {
  static const channel = MethodChannel('escive/watch');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> manual(bool locked) async {
    if (!supported) return;
    try {
      await channel.invokeMethod('manualParking', locked);
    } on MissingPluginException catch (_) {
      // Older hosts and protocol test harnesses have no proximity service.
    }
  }
}
