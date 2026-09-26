import 'dart:async';
import 'dart:io';
import '../models/deck_action.dart';
import '../models/deck_packet.dart';
import 'windows_action_executor.dart';
import 'windows_telemetry_service.dart';

class ConnectedClient {
  final String id;
  final WebSocket socket;
  String deviceName;
  String platform;
  final DateTime connectedAt;
  int pingMs;

  ConnectedClient({
    required this.id,
    required this.socket,
    this.deviceName = 'Unknown Device',
    this.platform = 'Unknown',
    DateTime? connectedAt,
    this.pingMs = 0,
  }) : connectedAt = connectedAt ?? DateTime.now();
}

class ServerEvent {
  final String title;
  final String details;
  final DateTime timestamp;
  final bool isError;

  ServerEvent(this.title, this.details, {this.isError = false})
      : timestamp = DateTime.now();
}

/// The local WebSocket server that runs on the Windows PC.
class DeckServer {
  final int port;
  HttpServer? _httpServer;
  final List<ConnectedClient> _clients = [];
  final WindowsTelemetryService _telemetryService = WindowsTelemetryService();
  StreamSubscription? _telemetrySub;

  final _eventsController = StreamController<ServerEvent>.broadcast();
  final _clientsController = StreamController<List<ConnectedClient>>.broadcast();

  Stream<ServerEvent> get eventsStream => _eventsController.stream;
  Stream<List<ConnectedClient>> get clientsStream => _clientsController.stream;
  List<ConnectedClient> get clients => List.unmodifiable(_clients);
  bool get isRunning => _httpServer != null;

  DeckServer({this.port = 8443});

  /// Starts the server and begins listening for connections.
  Future<bool> start() async {
    if (_httpServer != null) return true;

    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _log('Server Started', 'Listening on port $port');

      // Start telemetry polling and broadcast
      _telemetryService.start(const Duration(seconds: 2));
      _telemetrySub = _telemetryService.telemetryStream.listen((data) {
        broadcast(DeckPacket.telemetry(
          cpuPercent: data.cpuPercent,
          ramPercent: data.ramPercent,
          activeApp: data.activeApp,
        ));
      });

      _httpServer!.listen(_handleHttpRequest);
      return true;
    } catch (e) {
      _log('Server Error', 'Failed to start on port $port: $e', isError: true);
      return false;
    }
  }

  /// Stops the server and disconnects all clients.
  Future<void> stop() async {
    _telemetrySub?.cancel();
    _telemetryService.stop();

    for (var client in _clients) {
      try {
        client.socket.close(WebSocketStatus.goingAway, 'Server shutting down');
      } catch (_) {}
    }
    _clients.clear();
    _clientsController.add(_clients);

    await _httpServer?.close(force: true);
    _httpServer = null;
    _log('Server Stopped', 'Server on port $port was terminated');
  }

  void _handleHttpRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((socket) {
        _handleClientConnection(socket, request.connectionInfo?.remoteAddress.address ?? '');
      }).catchError((err) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('WebSocket upgrade failed: $err')
          ..close();
      });
    } else {
      // Basic HTTP status check endpoint
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"status":"online","app":"StreamDeckHost","port":$port}')
        ..close();
    }
  }

  void _handleClientConnection(WebSocket socket, String ip) {
    final clientId = DateTime.now().microsecondsSinceEpoch.toString();
    final client = ConnectedClient(id: clientId, socket: socket);
    _clients.add(client);
    _clientsController.add(_clients);

    _log('Client Connected', 'Incoming connection from $ip');

    // Send immediate Handshake ACK
    socket.add(DeckPacket.handshakeAck(
      hostName: Platform.localHostname,
      osVersion: Platform.operatingSystemVersion,
      port: port,
    ).serialize());

    socket.listen(
      (data) => _handleClientMessage(client, data),
      onDone: () => _removeClient(client),
      onError: (err) => _removeClient(client, err.toString()),
    );
  }

  void _handleClientMessage(ConnectedClient client, dynamic raw) {
    if (raw is! String) return;

    final packet = DeckPacket.deserialize(raw);

    switch (packet.type) {
      case DeckPacketType.handshake:
        client.deviceName = packet.payload['deviceName'] as String? ?? 'Device';
        client.platform = packet.payload['platform'] as String? ?? 'Mobile';
        _clientsController.add(_clients);
        _log('Handshake', '${client.deviceName} (${client.platform}) paired');
        break;

      case DeckPacketType.buttonPress:
        final buttonId = packet.payload['buttonId'] as String? ?? '';
        final slotIndex = packet.payload['slotIndex'] as int? ?? 0;
        final actionMap = packet.payload['action'];

        if (actionMap is Map) {
          final action = DeckAction.fromJson(Map<String, dynamic>.from(actionMap));
          _log('Button Pressed', 'Slot $slotIndex ($buttonId): ${action.type.name} [${action.command}]');

          // Execute action on Windows
          WindowsActionExecutor.execute(action).then((success) {
            if (!success) {
              _log('Action Failed', 'Failed to execute ${action.type.name} on Windows', isError: true);
            }
          });
        }
        break;

      case DeckPacketType.buttonRelease:
        // Hook for long press or release actions
        break;

      case DeckPacketType.ping:
        final id = packet.payload['id'] as int? ?? 0;
        client.socket.add(DeckPacket.pong(id).serialize());
        break;

      case DeckPacketType.pong:
        final id = packet.payload['id'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        client.pingMs = (now - id).clamp(0, 9999);
        _clientsController.add(_clients);
        break;

      default:
        break;
    }
  }

  void _removeClient(ConnectedClient client, [String? error]) {
    _clients.removeWhere((c) => c.id == client.id);
    _clientsController.add(_clients);
    _log('Client Disconnected', '${client.deviceName} left${error != null ? ': $error' : ''}');
  }

  /// Sends a packet to all currently connected clients.
  void broadcast(DeckPacket packet) {
    final serialized = packet.serialize();
    for (var client in _clients) {
      try {
        client.socket.add(serialized);
      } catch (_) {}
    }
  }

  void _log(String title, String details, {bool isError = false}) {
    final ev = ServerEvent(title, details, isError: isError);
    if (!_eventsController.isClosed) {
      _eventsController.add(ev);
    }
    print('[DeckServer] $title: $details');
  }

  /// Discovers the local machine's IP address on the active network interface.
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
