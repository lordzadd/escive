/// Vicont 2.0.4 BLE wire format. See docs/VICONT_PROTOCOL.md.
class VicontProtocol {
  static const profiles = {'fff0': 'fff1', 'fee0': 'fee2'};
  static const hello = [
    [0xfa, 0xaf, 0xa5, 0x5a, 1, 0, 0x5b],
    [0xfa, 0xaf, 0xa5, 0xfa, 1, 0, 0x5b],
  ];

  static List<int> command(int header, int code, List<int> data) {
    if (![0x5a, 0xfa].contains(header) ||
        code < 0 ||
        code > 255 ||
        data.length > 255 ||
        data.any((v) => v < 0 || v > 255)) {
      throw ArgumentError('Invalid Vicont command');
    }
    final body = [header, code, data.length, ...data];
    return [
      0xfa,
      0xaf,
      0xa5,
      ...body,
      body.fold<int>(0, (sum, v) => sum + v) & 255
    ];
  }

  static List<int> lock(int header, bool locked) =>
      command(header, 0x33, [locked ? 1 : 2]);
  static List<int> light(int header, bool on) =>
      command(header, 0x45, [on ? 2 : 1]);
  static List<int> gear(int header, int gear) {
    if (gear < 1 || gear > 7) throw RangeError.range(gear, 1, 7);
    return command(header, 0x42, [gear]);
  }

  /// RX has no FA AF A5 prefix. Payload length is inferred from TX and offsets.
  /// Preserve complete frames; do not assume one notification equals one frame.
  final List<int> _buffer = [];
  void clear() => _buffer.clear();
  List<List<int>> add(List<int> bytes) {
    if (bytes.any((v) => v < 0 || v > 255)) return [];
    _buffer.addAll(bytes);
    final frames = <List<int>>[];
    while (_buffer.length >= 3) {
      if (![0x5a, 0xfa].contains(_buffer[0]) ||
          _buffer[2] > 64 ||
          ![1, 16, 17, 18, 19, 20, 31, ...List.generate(26, (i) => 51 + i)]
              .contains(_buffer[1])) {
        _buffer.removeAt(0);
        continue;
      }
      final size = _buffer[2] + 3;
      if (_buffer.length < size) break;
      final frame = _buffer.sublist(0, size);
      // The vendor RX path does not check a checksum. Match that behavior;
      // length and field checks below reject incomplete telemetry. Ignore optional
      // trailer bytes while seeking the next header; never require a checksum
      // that the vendor RX path does not establish.
      _buffer.removeRange(0, size);
      frames.add(frame);
    }
    return frames;
  }

  static Map<String, dynamic> telemetry(List<int> p) {
    if (p.length < 3 || ![0x5a, 0xfa].contains(p[0]) || p.length < p[2] + 3) {
      return {};
    }
    int u16(int at) => p[at] * 256 + p[at + 1];
    if (p[1] == 0x10 && p[2] >= 12) {
      if (p[9] > 100) return {};
      return {
        'voltage': u16(3) / 100.0,
        'currentRaw': u16(5),
        'speedKmh': u16(7) / 10.0,
        'battery': p[9],
        'controllerTemperature': p[10],
        'motorTemperature': p[11],
        'batteryTemperature': p[12],
        'motorRpm': u16(13),
      };
    }
    if (p[1] == 0x11 && p[2] >= 10) {
      return {
        'gear': p[3] & 7,
        'light': (p[3] & 8) != 0,
        'tailLight': (p[3] & 16) != 0,
        'zeroStart': (p[3] & 32) != 0,
        'cruise': (p[3] & 64) != 0,
        'imperial': (p[3] & 128) != 0,
        'poweredOn': (p[4] & 1) != 0,
        'locked': (p[4] & 2) != 0,
        'horn': (p[4] & 4) != 0,
        'leftIndicator': (p[4] & 8) != 0,
        'rightIndicator': (p[4] & 16) != 0,
        'ambientLight': (p[4] & 32) != 0,
        'bluetoothBound': (p[4] & 64) != 0,
        'cruiseActive': (p[11] & 1) != 0,
        'braking': (p[11] & 2) != 0,
        'brakeLocked': (p[11] & 4) != 0,
        'tripDistanceKm': u16(5) / 100.0,
        'totalDistanceKm': u16(7),
        'faultBits': ((p[11] >> 3) & 15) | ((p[12] & 63) << 4),
        'charging': (p[11] & 128) != 0,
      };
    }
    if (p[1] == 0x12 && p[2] >= 9) {
      return {
        'instrumentId': u16(3),
        'instrumentHardware': p[5],
        'instrumentSoftware': p[6],
        'controllerId': u16(7),
        'controllerHardware': p[9],
        'controllerSoftware': p[10],
        'gears': [
          for (int i = 0; i < 7; i++)
            if ((p[11] & (1 << i)) != 0) i + 1
        ]
      };
    }
    if (p[1] == 0x13 && p[2] >= 12) {
      return {
        'throttleRaw': u16(3),
        'brake1Raw': u16(5),
        'brake2Raw': u16(7),
        'throttleCalibration': u16(9),
        'brake1Calibration': u16(11),
        'brake2Calibration': u16(13),
      };
    }
    if (p[1] == 0x1f && p[2] >= 14) {
      return {
        'bmsId': u16(3),
        'bmsVoltage': u16(5) / 100,
        'bmsCurrent': u16(7) / 100,
        'bmsCycles': u16(9),
        'bmsCapacityRaw': u16(11),
        'bmsRemainingRaw': u16(13),
        'bmsTemperature': u16(15),
        'bmsCharging': (p[4] & 1) != 0,
        'bmsDischarging': (p[4] & 2) != 0,
        'bmsLowVoltage': (p[4] & 4) != 0,
        'bmsOvervoltage': (p[4] & 8) != 0,
        'bmsFault': (p[4] & 16) != 0,
      };
    }
    return {};
  }

  static const faultNames = [
    'Communication fault',
    'Battery overvoltage',
    'Battery undervoltage',
    'Motor phase fault',
    'Motor locked rotor',
    'Hardware overcurrent',
    'Controller fault',
    'Throttle sensor fault',
    'Brake sensor fault',
    'Motor Hall sensor fault',
  ];
  static List<String> faults(int bits) => [
        for (var i = 0; i < faultNames.length; i++)
          if (bits & (1 << i) != 0) faultNames[i],
      ];
}
