import 'dart:async';
import 'dart:io';

class SystemTelemetryData {
  final int cpuPercent;
  final int ramPercent;
  final String? activeApp;
  final DateTime timestamp;

  SystemTelemetryData({
    required this.cpuPercent,
    required this.ramPercent,
    this.activeApp,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'CPU: $cpuPercent% | RAM: $ramPercent%';
}

/// Polls Windows system metrics (CPU load, RAM usage) and streams updates.
class WindowsTelemetryService {
  Timer? _timer;
  final _controller = StreamController<SystemTelemetryData>.broadcast();
  bool _isPolling = false;

  Stream<SystemTelemetryData> get telemetryStream => _controller.stream;

  void start([Duration interval = const Duration(seconds: 3)]) {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => _pollMetrics());
    _pollMetrics(); // Immediate initial poll
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> _pollMetrics() async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      if (Platform.isWindows) {
        // Query CPU Load Percentage and RAM usage via lightweight PowerShell script
        const ps = '& { '
            r'$p = (Get-CimInstance Win32_Processor).LoadPercentage; '
            r'$o = Get-CimInstance Win32_OperatingSystem; '
            r'$r = [int]((($o.TotalVisibleMemorySize - $o.FreePhysicalMemory) * 100) / $o.TotalVisibleMemorySize); '
            r'Write-Output "$p,$r"'
            ' }';

        final res = await Process.run(
          'powershell',
          ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', ps],
        );

        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          final lines = res.stdout.toString().trim().split(',');
          if (lines.length >= 2) {
            final cpu = int.tryParse(lines[0].trim()) ?? 0;
            final ram = int.tryParse(lines[1].trim()) ?? 0;

            final data = SystemTelemetryData(
              cpuPercent: cpu.clamp(0, 100),
              ramPercent: ram.clamp(0, 100),
            );

            if (!_controller.isClosed) {
              _controller.add(data);
            }
          }
        }
      } else {
        // Mock data when running on iOS/Android for testing
        final data = SystemTelemetryData(
          cpuPercent: 25,
          ramPercent: 45,
        );
        if (!_controller.isClosed) {
          _controller.add(data);
        }
      }
    } catch (e) {
      // Ignored to prevent telemetry crashing
    } finally {
      _isPolling = false;
    }
  }
}
