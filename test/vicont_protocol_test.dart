import 'package:flutter_test/flutter_test.dart';
import 'package:escive/protocols/vicont.dart';

void main() {
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
  test('disconnect clears an incomplete notification', () {
    final codec = VicontProtocol();
    codec.add(live.sublist(0, 5));
    codec.clear();
    expect(codec.add(status), [status.sublist(0, 13)]);
  });
}
