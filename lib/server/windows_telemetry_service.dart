import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

final class _FileTime extends Struct {
  @Uint32()
  external int dwLowDateTime;
  @Uint32()
  external int dwHighDateTime;

  int get value => (dwHighDateTime << 32) | dwLowDateTime;
}

final class _MemoryStatusEx extends Struct {
  @Uint32()
  external int dwLength;
  @Uint32()
  external int dwMemoryLoad;
  @Uint64()
  external int ullTotalPhys;
  @Uint64()
  external int ullAvailPhys;
  @Uint64()
  external int ullTotalPageFile;
  @Uint64()
  external int ullAvailPageFile;
  @Uint64()
  external int ullTotalVirtual;
  @Uint64()
  external int ullAvailVirtual;
  @Uint64()
  external int ullAvailExtendedVirtual;
}

typedef _GetSystemTimesC = Int32 Function(Pointer<_FileTime>, Pointer<_FileTime>, Pointer<_FileTime>);
typedef _GetSystemTimesDart = int Function(Pointer<_FileTime>, Pointer<_FileTime>, Pointer<_FileTime>);

typedef _GlobalMemoryStatusExC = Int32 Function(Pointer<_MemoryStatusEx>);
typedef _GlobalMemoryStatusExDart = int Function(Pointer<_MemoryStatusEx>);

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

/// Polls Windows system metrics (CPU load, RAM usage) natively via Win32 FFI with zero latency.
class WindowsTelemetryService {
  Timer? _timer;
  final _controller = StreamController<SystemTelemetryData>.broadcast();
  bool _isPolling = false;

  static DynamicLibrary? _kernel32;
  static _GetSystemTimesDart? _getSystemTimes;
  static _GlobalMemoryStatusExDart? _globalMemoryStatusEx;
  static bool _ffiInitialized = false;

  int _prevIdle = 0;
  int _prevKernel = 0;
  int _prevUser = 0;
  bool _hasPrevTimes = false;

  Stream<SystemTelemetryData> get telemetryStream => _controller.stream;

  static void _ensureFfi() {
    if (_ffiInitialized) return;
    _ffiInitialized = true;
    if (Platform.isWindows) {
      try {
        _kernel32 = DynamicLibrary.open('kernel32.dll');
        _getSystemTimes = _kernel32!.lookupFunction<_GetSystemTimesC, _GetSystemTimesDart>('GetSystemTimes');
        _globalMemoryStatusEx = _kernel32!.lookupFunction<_GlobalMemoryStatusExC, _GlobalMemoryStatusExDart>('GlobalMemoryStatusEx');
      } catch (_) {}
    }
  }

  void start([Duration interval = const Duration(seconds: 2)]) {
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
        _ensureFfi();
        int ram = 0;
        int cpu = 0;

        // 1. Instant RAM metric via Win32 GlobalMemoryStatusEx
        if (_globalMemoryStatusEx != null) {
          final mem = calloc<_MemoryStatusEx>();
          mem.ref.dwLength = sizeOf<_MemoryStatusEx>();
          _globalMemoryStatusEx!(mem);
          ram = mem.ref.dwMemoryLoad.clamp(0, 100);
          calloc.free(mem);
        }

        // 2. Instant CPU metric via Win32 GetSystemTimes
        if (_getSystemTimes != null) {
          final idle = calloc<_FileTime>();
          final kernel = calloc<_FileTime>();
          final user = calloc<_FileTime>();
          _getSystemTimes!(idle, kernel, user);

          final idleVal = idle.ref.value;
          final kernelVal = kernel.ref.value;
          final userVal = user.ref.value;

          if (_hasPrevTimes) {
            final idleDiff = idleVal - _prevIdle;
            final kernelDiff = kernelVal - _prevKernel;
            final userDiff = userVal - _prevUser;
            final total = kernelDiff + userDiff;
            if (total > 0) {
              cpu = (100.0 - (idleDiff * 100.0 / total)).clamp(0.0, 100.0).round();
            }
          } else {
            _hasPrevTimes = true;
          }

          _prevIdle = idleVal;
          _prevKernel = kernelVal;
          _prevUser = userVal;

          calloc.free(idle);
          calloc.free(kernel);
          calloc.free(user);
        }

        final data = SystemTelemetryData(
          cpuPercent: cpu,
          ramPercent: ram,
        );

        if (!_controller.isClosed) {
          _controller.add(data);
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
    } catch (_) {
    } finally {
      _isPolling = false;
    }
  }
}
