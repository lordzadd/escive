import 'dart:async';
import 'package:escive/main.dart' show logarte;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:escive/protocols/vicont.dart';
import 'package:escive/utils/globals.dart' as globals;
import 'package:escive/utils/check_bluetooth_permission.dart';
import 'package:escive/utils/show_snackbar.dart';

/// A separate bridge prevents iScooter authentication from reaching Vicont devices.
class VicontBridge {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _data;
  StreamSubscription<BluetoothConnectionState>? _connection;
  Timer? _watchdog;
  Timer? _retry;
  final _decoder = VicontProtocol();
  Future<void> _queue = Future.value();
  int? _header;
  int _generation = 0;
  DateTime? _lastSpeed;
  DateTime? _lastStatus;
  BuildContext? _context;
  Map _saved = {};
  bool _busy = false;
  bool _losing = false;
  final List<int> gears = [];
  // Session-only capabilities: never enable tuning from cached device values.
  final Map<int, int> settings = {};
  final Map<int, int> settingScales = {};
  final Map<int, Completer<bool>> _queries = {};
  bool readingSettings = false;
  String settingsMessage = 'Read scooter settings to load available options.';

  Future<bool> readSetting(int code) async {
    if (!ready ||
        _queries.containsKey(code) ||
        ![0x4a, 0x3c, 0x3d, 0x3e, 0x3f].contains(code)) {
      return false;
    }
    settings.remove(code);
    final reply = Completer<bool>();
    _queries[code] = reply;
    try {
      if (!await command(code, [0])) return false;
      return await reply.future
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
    } finally {
      if (identical(_queries[code], reply)) _queries.remove(code);
    }
  }

  Future<void> readSettings() async {
    if (readingSettings || !ready) return;
    readingSettings = true;
    settingsMessage = 'Reading scooter settings…';
    globals.refreshStates(['home']);
    try {
      for (final code in [0x4a, 0x3c, 0x3d, 0x3e, 0x3f]) {
        if (!ready) break;
        await readSetting(code);
      }
      settingsMessage = settings.isEmpty
          ? 'No settings response. These options may not be supported.'
          : 'Returned settings loaded. Unavailable options stay disabled.';
    } finally {
      readingSettings = false;
      globals.refreshStates(['home']);
    }
  }

  Future<bool> setRideMode(int mode) async {
    if (!settings.containsKey(0x4a) || mode < 1 || mode > 3) return false;
    // Vendor work modes: ECO=1, COMFORT=2, SPORT=3; matching gears 1,2,3.
    final generation = _generation;
    final gear = mode;
    if (!gears.contains(gear)) return false;
    if (!await command(0x42, [gear], stationary: true)) return false;
    if (generation != _generation) return false;
    if (!await command(0x4a, [mode], stationary: true)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (generation != _generation) return false;
    return readSetting(0x4a);
  }

  Future<bool> setUnits(bool imperial) =>
      command(0x43, [imperial ? 2 : 1], stationary: true);

  Future<bool> setTuning(int code, int level) async {
    if (!settings.containsKey(code) ||
        ![0x3c, 0x3d, 0x3e, 0x3f].contains(code)) {
      return false;
    }
    final generation = _generation;
    final maximum = code == 0x3c
        ? 99
        : code == 0x3f
            ? 9
            : 10;
    final minimum = code == 0x3f ? 0 : 1;
    if (level < minimum || level > maximum) return false;
    // Match the vendor's write scale (200), not its legacy read scale.
    final raw = code == 0x3c
        ? level
        : code == 0x3f
            ? (level == 0 ? 1 : (level / 9 * 200).floor())
            : level * 20;
    if (!await command(code, [raw], stationary: true)) return false;
    // An acknowledgement is not a setting value. Read back after the write.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (generation != _generation) return false;
    settings.remove(code);
    globals.refreshStates(['home']);
    return readSetting(code);
  }

  bool get ready =>
      _header != null &&
      _characteristic != null &&
      _lastSpeed != null &&
      DateTime.now().difference(_lastSpeed!).inSeconds < 5 &&
      _lastStatus != null &&
      DateTime.now().difference(_lastStatus!).inSeconds < 5;

  void _event(String type, dynamic value) => globals.socket.add({
        'type': 'databridge',
        'subtype': type,
        'data': value,
      });
  void setWarningLight(String name, bool enabled) =>
      _event('warningLight', {'name': name, 'value': enabled});

  void _state(String value) {
    _saved['currentActivity']['state'] = value;
    _event('state', value);
    _event('warningLight',
        {'name': 'bridgeDisconnected', 'value': value != 'connected'});
    globals.refreshStates(['home', 'speedometer']);
  }

  Future<void> init(BuildContext context) async {
    _context = context;
    _saved = globals.currentDevice;
    final generation = ++_generation;
    _retry?.cancel();
    final connectedAt = DateTime.now();
    _state('connecting');
    try {
      if (!await checkBluetoothPermission(context)) {
        throw StateError('Bluetooth permission is required.');
      }
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 15));
      if (generation != _generation) return;
      final device = BluetoothDevice.fromId(_saved['bluetoothAddress']);
      _device = device;
      await device.connect(timeout: const Duration(seconds: 15), mtu: null);
      if (generation != _generation) {
        await device.disconnect();
        return;
      }
      final services = await device.discoverServices();
      if (generation != _generation) return;
      for (final entry in VicontProtocol.profiles.entries) {
        for (final service
            in services.where((s) => s.uuid == Guid(entry.key))) {
          for (final c in service.characteristics) {
            if (c.uuid == Guid(entry.value) &&
                (c.properties.notify || c.properties.indicate) &&
                (c.properties.write || c.properties.writeWithoutResponse)) {
              _characteristic = c;
              break;
            }
          }
        }
        if (_characteristic != null) break;
      }
      final c = _characteristic;
      if (c == null) {
        throw StateError('No supported Vicont Bluetooth service was found.');
      }
      _data = c.onValueReceived.listen(_receive);
      await c.setNotifyValue(true);
      if (generation != _generation) return;
      _connection = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _lost('Scooter disconnected.');
        }
      });
      for (final hello in VicontProtocol.hello) {
        await _write(hello, generation);
      }
      _watchdog = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (ready && timer.tick % 5 == 0) globals.saveInBox();
        if (!ready) {
          if (_saved['currentActivity']['state'] == 'connected') {
            _state('connecting');
          }
          globals.bridgeReadyStates = globals.defaultReadyStates;
          globals.refreshStates(['home']);
          if (DateTime.now().difference(_lastSpeed ?? connectedAt).inSeconds >
                  10 ||
              DateTime.now().difference(_lastStatus ?? connectedAt).inSeconds >
                  10) {
            _lost('Scooter data stopped. Reconnecting.');
          }
        }
      });
      // Do not present a GATT connection as working telemetry.
      await Future<void>.delayed(const Duration(seconds: 8));
      if (generation == _generation && !ready) {
        throw StateError(
            'No complete Vicont telemetry. Close Vicont and reconnect.');
      }
    } catch (error) {
      if (generation == _generation) await _lost(error.toString());
    }
  }

  Future<void> _write(List<int> bytes, int generation) {
    final task = _queue.then((_) async {
      if (generation != _generation || _characteristic == null) {
        throw StateError('Scooter disconnected.');
      }
      final c = _characteristic!;
      logarte.log(
          'Vicont TX: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
      await c.write(bytes, withoutResponse: !c.properties.write);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    _queue = task.catchError((Object _) {});
    return task;
  }

  void _receive(List<int> bytes) {
    logarte.log(
        'Vicont RX: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    for (final frame in _decoder.add(bytes)) {
      final code = frame[1];
      if (_queries.containsKey(code) && frame[2] >= 1) {
        final value = frame[3];
        final valid = code == 0x4a
            ? value >= 1 && value <= 3
            : code == 0x3c
                ? value >= 1 && value <= 100
                : value >= 1 && value <= 200;
        if (valid) {
          settings[code] = value;
          settingScales[code] = frame[2] >= 2 && frame[4] > 0
              ? frame[4]
              : code == 0x3e
                  ? 25
                  : 99;
          final query = _queries.remove(code)!;
          if (!query.isCompleted) query.complete(true);
          globals.refreshStates(['home']);
        }
      }
      final values = VicontProtocol.telemetry(frame);
      if (values.isEmpty) continue;
      _header = frame[0];
      if (frame[1] == 0x10) _lastSpeed = DateTime.now();
      if (frame[1] == 0x11) _lastStatus = DateTime.now();
      if (values['gears'] is List<int>) {
        gears
          ..clear()
          ..addAll(values['gears'] as List<int>);
        // The upstream dashboard renders up to four modes. The Vicont panel
        // exposes all advertised gears, including non-contiguous masks.
        _saved['supportedProperties']['speedModeLength'] = 0;
      }
      final activity = _saved['currentActivity'] as Map;
      for (final entry in values.entries) {
        if (entry.key.endsWith('DistanceKm')) {
          _saved['stats'][entry.key] = entry.value;
          _event('distance', null);
        } else {
          activity[entry.key] = entry.value;
          _event(
              entry.key == 'speedKmh' ? 'speed' : entry.key,
              entry.key == 'speedKmh'
                  ? {'speedKmh': entry.value, 'source': 'bridge'}
                  : entry.value);
        }
      }
      if (ready) {
        globals.bridgeReadyStates = {
          'lock': true,
          'light': true,
          'speed': false
        };
        if (activity['state'] != 'connected') {
          activity['startTime'] = DateTime.now().millisecondsSinceEpoch;
          _saved['lastConnection'] = activity['startTime'];
          _state('connected');
        }
      }
      globals.refreshStates(['home', 'speedometer']);
    }
  }

  Future<bool> command(int code, List<int> payload,
      {bool stationary = false}) async {
    if (_busy) return false;
    try {
      if (!ready) throw StateError('Wait for current scooter data.');
      if (stationary && (_saved['currentActivity']['speedKmh'] as num) > 1) {
        throw StateError('Stop the scooter before this action.');
      }
      _busy = true;
      await _write(
          VicontProtocol.command(_header!, code, payload), _generation);
      // A successful GATT write is not a device acknowledgement. Telemetry
      // remains authoritative; the UI never changes state optimistically.
      return true;
    } catch (error) {
      final context = _context;
      if (context != null && context.mounted) {
        showSnackBar(context, error.toString());
      }
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> setLock(bool state) =>
      command(0x33, [state ? 1 : 2], stationary: true);
  Future<bool> turnLight(bool state) => command(0x45, [state ? 2 : 1]);
  Future<bool> setSpeedMode(int index) async {
    if (index < 0 || index >= gears.length) return false;
    return command(0x42, [gears[index]], stationary: true);
  }

  Future<bool> setCruise(bool state) =>
      command(0x36, [state ? 2 : 1], stationary: true);
  Future<bool> setZeroStart(bool state) =>
      command(0x35, [state ? 2 : 1], stationary: true);
  Future<bool> findScooter() => command(0x34, [2], stationary: true);

  Future<void> _lost(String reason) async {
    if (_losing) return;
    _losing = true;
    final context = _context;
    final id = _saved['id'];
    await dispose();
    _losing = false;
    if (context != null && context.mounted) showSnackBar(context, reason);
    if (!globals.settings['disableAutoBluetoothReconnection'] &&
        context != null) {
      _retry = Timer(const Duration(seconds: 5), () {
        if (context.mounted &&
            globals.currentDevice['id'] == id &&
            identical(globals.bridge, this)) {
          init(context);
        }
      });
    }
  }

  Future<bool> dispose() async {
    ++_generation;
    _retry?.cancel();
    _watchdog?.cancel();
    await _connection?.cancel();
    await _data?.cancel();
    _connection = null;
    _data = null;
    final device = _device;
    _device = null;
    _characteristic = null;
    _header = null;
    _lastSpeed = null;
    _lastStatus = null;
    _decoder.clear();
    gears.clear();
    settings.clear();
    settingScales.clear();
    for (final query in _queries.values) {
      if (!query.isCompleted) query.complete(false);
    }
    _queries.clear();
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    if (_saved.isNotEmpty) {
      globals.saveInBox();
      _saved['currentActivity']['speedKmh'] = 0;
      _event('speed', {'speedKmh': 0, 'source': 'bridge'});
      _state('none');
    }
    globals.bridgeReadyStates = globals.defaultReadyStates;
    return true;
  }
}
