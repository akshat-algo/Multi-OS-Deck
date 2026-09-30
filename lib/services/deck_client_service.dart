import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/deck_action.dart';
import '../models/deck_packet.dart';
import 'deck_discovery_service.dart';

enum ConnectionStatus {
  disconnected,
  discovering,
  connecting,
  connected,
}

/// Manages client-side WebSocket communication to the Windows Host,
/// handling dynamic mDNS auto-discovery, device identification handshakes,
/// connection timeouts, and automatic reconnection.
class DeckClientService extends ChangeNotifier {
  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _hostAddress = '';
  int _port = 8443;
  String _connectedHostName = '';
  String? _targetHostName;
  int _latencyMs = 0;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _autoReconnect = true;

  int _cpuPercent = 0;
  int _ramPercent = 0;
  String? _activeApp;

  final DeckDiscoveryService _discoveryService = DeckDiscoveryService();
  final _packetController = StreamController<DeckPacket>.broadcast();

  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isDiscovering => _status == ConnectionStatus.discovering;
  bool get isConnecting => _status == ConnectionStatus.connecting;
  String get hostAddress => _hostAddress;
  int get port => _port;
  String get connectedHostName => _connectedHostName;
  String? get targetHostName => _targetHostName;
  int get latencyMs => _latencyMs;
  int get cpuPercent => _cpuPercent;
  int get ramPercent => _ramPercent;
  String? get activeApp => _activeApp;
  Stream<DeckPacket> get packetStream => _packetController.stream;
  DeckDiscoveryService get discoveryService => _discoveryService;

  void setTargetHostName(String? name) {
    _targetHostName = (name != null && name.trim().isNotEmpty) ? name.trim() : null;
    _discoveryService.setTargetHostName(_targetHostName);
    notifyListeners();
  }

  /// Automatically discovers the PC via mDNS / signature _streamdeck._tcp.local
  /// and establishes a dynamic low-latency connection without hardcoded IPs.
  Future<bool> autoDiscoverAndConnect({
    String? targetHostName,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (targetHostName != null) {
      setTargetHostName(targetHostName);
    }

    _setStatus(ConnectionStatus.discovering);

    try {
      final host = await _discoveryService.discover(
        timeout: timeout,
        preferredHostName: _targetHostName,
      );

      if (host != null) {
        debugPrint('[Client] Discovered target PC host: ${host.hostName} at ${host.ip}:${host.port}');
        return await connect(host.ip, host.port, _targetHostName);
      } else {
        debugPrint('[Client] Auto-discovery timeout. No matching host found on local Wi-Fi.');
        // If we had a previously known address, try connecting as fallback
        if (_hostAddress.isNotEmpty && _hostAddress != '127.0.0.1') {
          return await connect(_hostAddress, _port, _targetHostName);
        }
      }
    } catch (e) {
      debugPrint('[Client] Discovery error: $e');
    }

    _setStatus(ConnectionStatus.disconnected);
    return false;
  }

  /// Connects to a specific IP or Host with handshake verification and timeout protection.
  Future<bool> connect(String ipOrHost, [int port = 8443, String? targetHostName]) async {
    _hostAddress = ipOrHost.trim().replaceAll('ws://', '').replaceAll('http://', '');
    if (_hostAddress.contains(':')) {
      final parts = _hostAddress.split(':');
      _hostAddress = parts[0];
      _port = int.tryParse(parts[1]) ?? port;
    } else {
      _port = port;
    }

    if (targetHostName != null) {
      _targetHostName = targetHostName;
    }

    _autoReconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Safely close existing channel to prevent dangling sockets
    if (_channel != null) {
      try {
        _channel?.sink.close();
      } catch (_) {}
      _channel = null;
    }

    _setStatus(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://$_hostAddress:$_port');
      _channel = WebSocketChannel.connect(uri);

      // Strict connection timeout (3.5 seconds) to avoid hanging
      await _channel!.ready.timeout(const Duration(milliseconds: 3500));

      final completer = Completer<bool>();

      // Listen for initial handshake verification before declaring fully connected
      _channel!.stream.listen(
        (data) {
          if (!completer.isCompleted) {
            final isVerified = _verifyHandshake(data);
            if (isVerified) {
              _setStatus(ConnectionStatus.connected);
              _reconnectTimer?.cancel();
              _reconnectTimer = null;
              _startPing();
              completer.complete(true);
            } else {
              completer.complete(false);
              disconnect();
              return;
            }
          }
          _onMessageReceived(data);
        },
        onDone: _onDisconnected,
        onError: (err) {
          if (!completer.isCompleted) completer.complete(false);
          _onDisconnected();
        },
      );

      // Send initial Client Handshake
      final platform = kIsWeb
          ? 'Web'
          : Platform.isAndroid
              ? 'Android'
              : Platform.isIOS
                  ? 'iOS'
                  : Platform.isWindows
                      ? 'Windows'
                      : 'Desktop';

      sendPacket(DeckPacket.handshake(
        deviceName: 'Mobile Deck',
        platform: platform,
        appVersion: '1.0.0',
      ));

      // Wait up to 2 seconds for server Handshake ACK
      final connected = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('[Client] Handshake ACK timeout.');
          return false;
        },
      );

      if (!connected) {
        disconnect();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[Client] Connection failed to $_hostAddress:$_port ($e)');
      _onDisconnected();
      return false;
    }
  }

  /// Verifies server device identity and ensures it matches preferred hostname if configured.
  bool _verifyHandshake(dynamic data) {
    if (data is! String) return false;
    try {
      final packet = DeckPacket.deserialize(data);
      if (packet.type == DeckPacketType.handshakeAck) {
        final hostName = packet.payload['hostName'] as String? ?? 'Unknown';
        _connectedHostName = hostName;

        // Device Identification Filter
        if (_targetHostName != null && _targetHostName!.isNotEmpty) {
          final expected = _targetHostName!.toLowerCase().trim();
          final received = hostName.toLowerCase().trim();
          if (received != expected && !received.contains(expected)) {
            debugPrint('[Client] Hostname filter mismatch: expected "$expected", got "$received". Disconnecting.');
            return false;
          }
        }

        debugPrint('[Client] Handshake verified with verified host: $hostName');
        return true;
      }
    } catch (e) {
      debugPrint('[Client] Error deserializing handshake ACK: $e');
    }
    return false;
  }

  /// Disconnects from current server.
  void disconnect() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  /// Lifecycle callback: handles app resuming from background or network restoration.
  void onAppResume() {
    debugPrint('[Client] App resumed. Checking connection status...');
    if (_status == ConnectionStatus.disconnected) {
      autoDiscoverAndConnect();
    }
  }

  /// Sends a button press action to the host.
  void pressButton(String buttonId, int slotIndex, DeckAction action) {
    if (!isConnected) return;
    sendPacket(DeckPacket.buttonPress(
      buttonId: buttonId,
      slotIndex: slotIndex,
      action: action,
    ));
  }

  /// Sends a button release event to the host.
  void releaseButton(String buttonId, int slotIndex) {
    if (!isConnected) return;
    sendPacket(DeckPacket.buttonRelease(
      buttonId: buttonId,
      slotIndex: slotIndex,
    ));
  }

  /// Sends an arbitrary packet to the host.
  void sendPacket(DeckPacket packet) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(packet.serialize());
    } catch (e) {
      debugPrint('[Client] Error sending packet: $e');
    }
  }

  void _onMessageReceived(dynamic data) {
    if (data is! String) return;

    final packet = DeckPacket.deserialize(data);
    _packetController.add(packet);

    switch (packet.type) {
      case DeckPacketType.telemetry:
        _cpuPercent = packet.payload['cpuPercent'] as int? ?? _cpuPercent;
        _ramPercent = packet.payload['ramPercent'] as int? ?? _ramPercent;
        _activeApp = packet.payload['activeApp'] as String? ?? _activeApp;
        notifyListeners();
        break;

      case DeckPacketType.pong:
        final sentTime = packet.payload['id'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        _latencyMs = (now - sentTime).clamp(0, 9999);
        notifyListeners();
        break;

      default:
        break;
    }
  }

  void _onDisconnected() {
    _pingTimer?.cancel();
    _channel = null;
    _setStatus(ConnectionStatus.disconnected);

    if (_autoReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (_status == ConnectionStatus.disconnected && _autoReconnect) {
          debugPrint('[Client] Reconnecting dynamically...');
          autoDiscoverAndConnect();
        }
      });
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isConnected) {
        final now = DateTime.now().millisecondsSinceEpoch;
        sendPacket(DeckPacket.ping(now));
      }
    });
  }

  void _setStatus(ConnectionStatus s) {
    if (_status != s) {
      _status = s;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    _discoveryService.dispose();
    _packetController.close();
    super.dispose();
  }
}
