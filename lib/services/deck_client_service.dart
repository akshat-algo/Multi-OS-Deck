import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/deck_action.dart';
import '../models/deck_packet.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

/// Manages client-side WebSocket communication to the Windows Host.
class DeckClientService extends ChangeNotifier {
  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _hostAddress = '';
  int _port = 8443;
  int _latencyMs = 0;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _autoReconnect = true;

  int _cpuPercent = 0;
  int _ramPercent = 0;
  String? _activeApp;

  final _packetController = StreamController<DeckPacket>.broadcast();

  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  String get hostAddress => _hostAddress;
  int get port => _port;
  int get latencyMs => _latencyMs;
  int get cpuPercent => _cpuPercent;
  int get ramPercent => _ramPercent;
  String? get activeApp => _activeApp;
  Stream<DeckPacket> get packetStream => _packetController.stream;

  /// Connects to the Windows host WebSocket.
  Future<bool> connect(String ipOrHost, [int port = 8443]) async {
    _hostAddress = ipOrHost.trim().replaceAll('ws://', '').replaceAll('http://', '');
    if (_hostAddress.endsWith('.') || _hostAddress.isEmpty || _hostAddress == '192.168.1.') {
      _hostAddress = (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ? '192.168.1.114' : '127.0.0.1';
    }
    if (_hostAddress.contains(':')) {
      final parts = _hostAddress.split(':');
      _hostAddress = parts[0];
      _port = int.tryParse(parts[1]) ?? port;
    } else {
      _port = port;
    }

    _autoReconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Safely close previous channel to avoid conflicting listener race conditions
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

      // Wait for handshake response or ready with timeout
      await _channel!.ready.timeout(const Duration(seconds: 3));

      _setStatus(ConnectionStatus.connected);
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _startPing();

      // Send initial Handshake
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

      _channel!.stream.listen(
        _onMessageReceived,
        onDone: _onDisconnected,
        onError: (err) => _onDisconnected(),
      );

      return true;
    } catch (e) {
      _onDisconnected();
      return false;
    }
  }

  /// Disconnects from the current server.
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
      print('[Client] Error sending packet: $e');
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

    if (_autoReconnect && _hostAddress.isNotEmpty) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (_status == ConnectionStatus.disconnected && _autoReconnect) {
          connect(_hostAddress, _port);
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

  /// Automatically scans and connects to the PC over Wi-Fi with zero typing.
  Future<bool> autoDiscoverAndConnect() async {
    // 1. Try saved/known Wi-Fi host first
    if (_hostAddress.isNotEmpty && _hostAddress != '127.0.0.1') {
      if (await connect(_hostAddress, _port)) return true;
    }

    // 2. Try the primary laptop Wi-Fi IP
    if (await connect('192.168.1.114', 8443)) return true;

    // 3. UDP broadcast ping on port 8443
    try {
      final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      udp.broadcastEnabled = true;
      udp.send('DISCOVER_DECK'.codeUnits, InternetAddress('255.255.255.255'), 8443);

      final completer = Completer<String?>();
      final sub = udp.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = udp.receive();
          if (dg != null) {
            final reply = String.fromCharCodes(dg.data);
            if (reply.contains('STREAM_DECK_HOST')) {
              if (!completer.isCompleted) completer.complete(dg.address.address);
            }
          }
        }
      });

      final discoveredIp = await completer.future.timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => null,
      );
      sub.cancel();
      udp.close();

      if (discoveredIp != null) {
        if (await connect(discoveredIp, 8443)) return true;
      }
    } catch (_) {}

    // 4. Fallback to USB cable reverse proxy (127.0.0.1)
    return await connect('127.0.0.1', 8443);
  }

  @override
  void dispose() {
    disconnect();
    _packetController.close();
    super.dispose();
  }
}
