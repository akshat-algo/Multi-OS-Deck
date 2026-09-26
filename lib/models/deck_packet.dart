import 'dart:convert';
import 'deck_action.dart';

enum DeckPacketType {
  handshake,
  handshakeAck,
  buttonPress,
  buttonRelease,
  stateUpdate,
  telemetry,
  profileSync,
  ping,
  pong,
  error,
}

/// Packet structure exchanged between Mobile Client and Windows Host over WebSocket.
class DeckPacket {
  final DeckPacketType type;
  final Map<String, dynamic> payload;
  final int timestamp;

  DeckPacket({
    required this.type,
    this.payload = const {},
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  String serialize() {
    return jsonEncode({
      'type': type.name,
      'payload': payload,
      'timestamp': timestamp,
    });
  }

  factory DeckPacket.deserialize(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final typeStr = map['type'] as String? ?? '';
      final type = DeckPacketType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => DeckPacketType.error,
      );

      return DeckPacket(
        type: type,
        payload: map['payload'] != null
            ? Map<String, dynamic>.from(map['payload'] as Map)
            : const {},
        timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      return DeckPacket(
        type: DeckPacketType.error,
        payload: {'error': e.toString()},
      );
    }
  }

  // Handy factory constructors
  factory DeckPacket.handshake({
    required String deviceName,
    required String platform,
    required String appVersion,
  }) {
    return DeckPacket(
      type: DeckPacketType.handshake,
      payload: {
        'deviceName': deviceName,
        'platform': platform,
        'appVersion': appVersion,
      },
    );
  }

  factory DeckPacket.handshakeAck({
    required String hostName,
    required String osVersion,
    required int port,
  }) {
    return DeckPacket(
      type: DeckPacketType.handshakeAck,
      payload: {
        'hostName': hostName,
        'osVersion': osVersion,
        'port': port,
      },
    );
  }

  factory DeckPacket.buttonPress({
    required String buttonId,
    required int slotIndex,
    required DeckAction action,
  }) {
    return DeckPacket(
      type: DeckPacketType.buttonPress,
      payload: {
        'buttonId': buttonId,
        'slotIndex': slotIndex,
        'action': action.toJson(),
      },
    );
  }

  factory DeckPacket.buttonRelease({
    required String buttonId,
    required int slotIndex,
  }) {
    return DeckPacket(
      type: DeckPacketType.buttonRelease,
      payload: {
        'buttonId': buttonId,
        'slotIndex': slotIndex,
      },
    );
  }

  factory DeckPacket.telemetry({
    required int cpuPercent,
    required int ramPercent,
    String? activeApp,
  }) {
    return DeckPacket(
      type: DeckPacketType.telemetry,
      payload: {
        'cpuPercent': cpuPercent,
        'ramPercent': ramPercent,
        'activeApp': ?activeApp,
      },
    );
  }

  factory DeckPacket.stateUpdate({
    required String buttonId,
    required bool isActive,
    String? title,
    String? iconKey,
  }) {
    return DeckPacket(
      type: DeckPacketType.stateUpdate,
      payload: {
        'buttonId': buttonId,
        'isActive': isActive,
        'title': ?title,
        'iconKey': ?iconKey,
      },
    );
  }

  factory DeckPacket.ping([int? id]) {
    return DeckPacket(
      type: DeckPacketType.ping,
      payload: {'id': id ?? DateTime.now().millisecondsSinceEpoch},
    );
  }

  factory DeckPacket.pong(int id) {
    return DeckPacket(
      type: DeckPacketType.pong,
      payload: {'id': id},
    );
  }
}
