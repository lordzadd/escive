import 'dart:convert';
import 'package:escive/utils/scooter_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uploads retry after failures and stop after acceptance', () async {
    final bodies = <List<dynamic>>[];
    final diagnostics = ScooterDiagnostics(
      endpoint: 'https://collector.example/events',
      token: 'upload-only',
      schedule: false,
      clientFactory: () => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer upload-only');
        bodies.add(jsonDecode(request.body) as List<dynamic>);
        return http.Response('', bodies.length == 1 ? 503 : 202);
      }),
    );
    diagnostics.record('parking', {'requested': true});
    await diagnostics.flush();
    await diagnostics.flush();
    await diagnostics.flush();
    expect(bodies.length, 2);
    expect(bodies[0], bodies[1]);
    expect((bodies[0][0] as Map).keys.toSet(),
        {'session', 'time', 'kind', 'data'});
  });

  test('queue stays bounded during network failure', () async {
    var count = 0;
    final diagnostics = ScooterDiagnostics(
      endpoint: 'https://collector.example/events',
      token: 'upload-only',
      schedule: false,
      clientFactory: () => MockClient((request) async {
        count += (jsonDecode(request.body) as List).length;
        return http.Response('', 202);
      }),
    );
    for (var i = 0; i < 600; i++) {
      diagnostics.record('state', {'value': 'connected'});
    }
    for (var i = 0; i < 6; i++) {
      await diagnostics.flush();
    }
    expect(count, 500);
  });

  test('ordinary builds and non-HTTPS URLs do not upload', () async {
    for (final endpoint in ['', 'http://collector.example/events']) {
      final diagnostics = ScooterDiagnostics(
          endpoint: endpoint,
          token: 'test',
          schedule: false,
          clientFactory: () => throw StateError('must not upload'));
      diagnostics.record('state', {'value': 'connected'});
      await diagnostics.flush();
      expect(diagnostics.enabled, false);
    }
  });
}
