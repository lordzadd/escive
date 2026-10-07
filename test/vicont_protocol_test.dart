import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:escive/protocols/vicont.dart';

void main() {
  test('extended packets match 24 extracted vendor encoder results', () {
    final vectors =
        jsonDecode(File('test/vicont_vendor_vectors.json').readAsStringSync())
            as List;
    for (final vector in vectors) {
      final bytes = VicontProtocol.command(int.parse(vector['zt'], radix: 16),
          vector['code'] as int, List<int>.from(vector['data']));
      expect(bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
          (vector['hex'] as String).toLowerCase());
    }
  });
  test('vendor hello packets retain the unusual FA-header checksum', () {
    expect(VicontProtocol.hello, [
      [250, 175, 165, 90, 1, 0, 91],
      [250, 175, 165, 250, 1, 0, 91],
    ]);
  });
  test('commands match independently recovered vendor encoder vectors', () {
    expect(VicontProtocol.lock(0x5a, true), [250, 175, 165, 90, 51, 1, 1, 143]);
    expect(
        VicontProtocol.lock(0x5a, false), [250, 175, 165, 90, 51, 1, 2, 144]);
    expect(
        VicontProtocol.light(0x5a, true), [250, 175, 165, 90, 69, 1, 2, 162]);
    expect(
        VicontProtocol.light(0xfa, false), [250, 175, 165, 250, 69, 1, 1, 65]);
    expect(VicontProtocol.gear(0x5a, 3), [250, 175, 165, 90, 66, 1, 3, 160]);
  });
  test('reject invalid commands', () {
    expect(() => VicontProtocol.command(0, 1, []), throwsArgumentError);
    expect(() => VicontProtocol.command(90, 1, [256]), throwsArgumentError);
    expect(() => VicontProtocol.gear(90, 0), throwsRangeError);
    expect(() => VicontProtocol.gear(90, 8), throwsRangeError);
  });
  // Synthetic RX fixtures derived from the vendor's indexed fields, not
  // hardware captures. The framing assumption still needs a scooter test.
  const status = [90, 17, 10, 0x6b, 3, 0, 123, 1, 244, 0, 0, 0, 0, 0];
  const live = [
    90,
    16,
    12,
    0x10,
    0x68,
    0,
    12,
    0,
    123,
    75,
    30,
    31,
    32,
    3,
    232,
    0
  ];
  test('big-endian telemetry preserves speed precision', () {
    final data = VicontProtocol.telemetry(live);
    expect(data['voltage'], 42.0);
    expect(data['speedKmh'], 12.3);
    expect(data['battery'], 75);
    expect(data['motorRpm'], 1000);
  });
  test('decode lock, light, mode, cruise and distance', () {
    final data = VicontProtocol.telemetry(status);
    expect(data['locked'], true);
    expect(data['light'], true);
    expect(data['gear'], 3);
    expect(data['cruise'], true);
    expect(data['zeroStart'], true);
    expect(data['tripDistanceKm'], 1.23);
    expect(data['totalDistanceKm'], 500);
  });
  test('fragmented and coalesced notifications retain full frames', () {
    final codec = VicontProtocol();
    expect(codec.add(live.sublist(0, 7)), isEmpty);
    expect(codec.add([...live.sublist(7), ...status]),
        [live.sublist(0, 15), status.sublist(0, 13)]);
  });
  test('discard noise and oversized headers, then recover', () {
    final codec = VicontProtocol();
    expect(codec.add([0, 90, 16, 255, ...live]), [live.sublist(0, 15)]);
  });
  test('all truncations and invalid battery fields are rejected', () {
    for (int n = 0; n < live.length - 1; n++) {
      expect(VicontProtocol.telemetry(live.sublist(0, n)), isEmpty);
    }
    final bad = [...live]..[9] = 101;
    expect(VicontProtocol.telemetry(bad), isEmpty);
    expect(VicontProtocol.telemetry([90, 17, 0, 0]), isEmpty);
  });
  test('gear capability preserves non-contiguous gear numbers', () {
    final frame = [90, 18, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0x45, 0];
    expect(VicontProtocol.telemetry(frame)['gears'], [1, 3, 7]);
  });
  test(
      'vendor-style telemetry without a checksum does not consume the next header',
      () {
    final codec = VicontProtocol();
    expect(codec.add([...live.sublist(0, 15), ...status.sublist(0, 13)]),
        [live.sublist(0, 15), status.sublist(0, 13)]);
  });
  test('diagnostics separate status flags from ten fault bits', () {
    final p = [...status]
      ..[4] = 0x7f
      ..[11] = 0xff
      ..[12] = 0x3f;
    final result = VicontProtocol.telemetry(p);
    expect(result['braking'], true);
    expect(result['cruiseActive'], true);
    expect(result['brakeLocked'], true);
    expect(result['charging'], true);
    expect(result['horn'], true);
    expect(result['faultBits'], 1023);
    expect(VicontProtocol.faults(result['faultBits']), hasLength(10));
    expect(VicontProtocol.faults(0), isEmpty);
  });
  test('versions, sensors and battery data decode with field length guards',
      () {
    final versions =
        VicontProtocol.telemetry([90, 18, 9, 1, 2, 3, 4, 5, 6, 7, 8, 7]);
    expect(versions['instrumentId'], 258);
    expect(versions['controllerSoftware'], 8);
    final sensors = VicontProtocol.telemetry(
        [90, 19, 12, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6]);
    expect(sensors['brake2Calibration'], 6);
    final bms = [
      90,
      31,
      14,
      0,
      3,
      16,
      104,
      0,
      250,
      0,
      100,
      1,
      244,
      0,
      250,
      0,
      30
    ];
    expect(VicontProtocol.telemetry(bms)['bmsVoltage'], 42);
    expect(VicontProtocol.telemetry(bms)['bmsCurrent'], 2.5);
    expect(VicontProtocol.telemetry(bms)['bmsCycles'], 100);
    for (var length = 0; length < bms.length; length++) {
      expect(VicontProtocol.telemetry(bms.sublist(0, length)), isEmpty);
    }
  });
  test('disconnect clears an incomplete notification', () {
    final codec = VicontProtocol();
    codec.add(live.sublist(0, 5));
    codec.clear();
    expect(codec.add(status), [status.sublist(0, 13)]);
  });
}
