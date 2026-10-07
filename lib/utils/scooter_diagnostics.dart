import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Enabled only in a diagnostic build with an HTTPS collector and upload token.
/// Captures scooter diagnostics in configured builds; never include access tokens.
class ScooterDiagnostics {
  static final instance = ScooterDiagnostics();
  ScooterDiagnostics({
    this.endpoint = const String.fromEnvironment('DIAGNOSTICS_URL'),
    this.token = const String.fromEnvironment('DIAGNOSTICS_TOKEN'),
    http.Client Function()? clientFactory,
    this.schedule = true,
  }) : _clientFactory = clientFactory ?? http.Client.new;
  final String endpoint;
  final String token;
  final bool schedule;
  final http.Client Function() _clientFactory;
  final String session = const Uuid().v4();
  final List<Map<String, Object>> _pending = [];
  Timer? _timer;
  bool _sending = false;
  bool get enabled =>
      Uri.tryParse(endpoint)?.scheme == 'https' && token.isNotEmpty;

  void record(String kind, Map<String, Object> data) {
    if (!enabled) return;
    if (_pending.length >= 500) _pending.removeAt(0);
    _pending.add({
      'session': session,
      'time': DateTime.now().toUtc().toIso8601String(),
      'kind': kind,
      'data': data,
    });
    if (schedule) {
      _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => flush());
    }
  }

  Future<void> flush() async {
    if (_sending || _pending.isEmpty) return;
    _sending = true;
    final batch = _pending.take(100).toList();
    final client = _clientFactory();
    try {
      final response = await client
          .post(Uri.parse(endpoint),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(batch))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 202) {
        for (final item in batch) {
          _pending.remove(item);
        }
      }
    } catch (_) {
      // Network failure must never block Bluetooth control. Retry bounded queue.
    } finally {
      client.close();
      _sending = false;
    }
  }
}
