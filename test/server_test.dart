import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_deck/models/deck_action.dart';
import 'package:stream_deck/models/deck_packet.dart';
import 'package:stream_deck/server/deck_server.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('DeckServer boots, accepts WebSocket connection, and executes handshake', () async {
    final server = DeckServer(port: 8448);
    final started = await server.start();
    expect(started, isTrue);

    final clientUri = Uri.parse('ws://127.0.0.1:8448');
    final channel = WebSocketChannel.connect(clientUri);
    await channel.ready;

    final completer = Completer<DeckPacket>();

    channel.stream.listen((message) {
      if (message is String) {
        final packet = DeckPacket.deserialize(message);
        if (!completer.isCompleted) {
          completer.complete(packet);
        }
      }
    });

    // Send Handshake
    channel.sink.add(DeckPacket.handshake(
      deviceName: 'iPhone 16 Pro',
      platform: 'iOS',
      appVersion: '1.0.0',
    ).serialize());

    // Await HandshakeAck from server
    final ackPacket = await completer.future.timeout(const Duration(seconds: 5));
    expect(ackPacket.type, DeckPacketType.handshakeAck);
    expect(ackPacket.payload['port'], 8448);

    // Send a test Button Press
    channel.sink.add(DeckPacket.buttonPress(
      buttonId: 'btn_test',
      slotIndex: 0,
      action: DeckAction.media('volume_up'),
    ).serialize());

    // Allow processing
    await Future.delayed(const Duration(milliseconds: 300));

    channel.sink.close();
    await server.stop();
  });
}
