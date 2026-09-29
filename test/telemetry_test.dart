import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_deck/server/windows_telemetry_service.dart';

void main() {
  test('WindowsTelemetryService emits data', () async {
    final service = WindowsTelemetryService();
    final completer = Completer<SystemTelemetryData>();

    service.start(const Duration(milliseconds: 500));
    final sub = service.telemetryStream.listen((data) {
      print('Emitted: $data');
      if (!completer.isCompleted && data.cpuPercent >= 0 && data.ramPercent > 0) {
        completer.complete(data);
      }
    });

    final res = await completer.future.timeout(const Duration(seconds: 4));
    expect(res.ramPercent, greaterThan(0));
    sub.cancel();
    service.stop();
  });
}
