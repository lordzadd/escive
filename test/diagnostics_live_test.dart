import 'dart:convert';
import 'dart:io';
import 'package:escive/utils/scooter_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('live collector accepts app uploader and isolates read access',
      () async {
    final diagnostics = ScooterDiagnostics(schedule: false);
    expect(diagnostics.enabled, true);
    final url = Uri.parse(diagnostics.endpoint);
    expect((await http.get(url)).statusCode, 401);
    expect(
        (await http.get(url, headers: {
          'Authorization': 'Bearer ${diagnostics.token}',
        }))
            .statusCode,
        401);
    diagnostics.record('parking', {'synthetic': true, 'requested': true});
    diagnostics.record('rx', {
      'synthetic': true,
      'bytes': [250, 175]
    });
    diagnostics.record('device', {'synthetic': true, 'name': 'QA only'});
    await diagnostics.flush();
    final reply = await http.get(url, headers: {
      'Authorization':
          'Bearer ${Platform.environment['DIAGNOSTICS_READ_TOKEN']}',
    });
    expect(reply.statusCode, 200);
    final events = jsonDecode(reply.body) as List;
    expect(
        events.any((e) =>
            e['session'] == diagnostics.session &&
            e['data']['synthetic'] == true),
        true);
  }, skip: Platform.environment['DIAGNOSTICS_READ_TOKEN'] == null);
}
