import 'package:flutter_test/flutter_test.dart';
import 'package:stream_deck/models/deck_action.dart';
import 'package:stream_deck/models/deck_button.dart';
import 'package:stream_deck/models/deck_packet.dart';
import 'package:stream_deck/models/deck_page.dart';

void main() {
  test('DeckAction serializes and deserializes correctly', () {
    final action = DeckAction.media('volume_up');
    final json = action.toJson();
    final reconstructed = DeckAction.fromJson(json);

    expect(reconstructed.type, DeckActionType.media);
    expect(reconstructed.command, 'volume_up');
  });

  test('DeckButton serializes and deserializes correctly', () {
    const button = DeckButton(
      id: 'btn_test',
      title: 'MIC MUTE',
      iconKey: 'mic',
      isToggle: true,
      action: DeckAction(type: DeckActionType.hotkey, command: 'ctrl+shift+m'),
    );

    final json = button.toJson();
    final reconstructed = DeckButton.fromJson(json);

    expect(reconstructed.id, 'btn_test');
    expect(reconstructed.title, 'MIC MUTE');
    expect(reconstructed.isToggle, true);
    expect(reconstructed.action.command, 'ctrl+shift+m');
  });

  test('DeckPacket serializes and deserializes correctly', () {
    final packet = DeckPacket.buttonPress(
      buttonId: 'btn_vol',
      slotIndex: 5,
      action: DeckAction.media('volume_up'),
    );

    final raw = packet.serialize();
    final reconstructed = DeckPacket.deserialize(raw);

    expect(reconstructed.type, DeckPacketType.buttonPress);
    expect(reconstructed.payload['buttonId'], 'btn_vol');
    expect(reconstructed.payload['slotIndex'], 5);
  });

  test('DeckProfile creates default pages and slots', () {
    final page = DeckPage(
      id: 'p1',
      name: 'Main',
      rows: 3,
      columns: 5,
      buttons: {
        0: const DeckButton(
          id: 'b0',
          title: 'TEST',
          iconKey: 'star',
          action: DeckAction.empty(),
        ),
      },
    );

    final profile = DeckProfile(
      id: 'prof1',
      name: 'Gaming',
      pages: [page],
    );

    expect(profile.activePage.totalSlots, 15);
    expect(profile.activePage.buttons[0]?.title, 'TEST');
  });
}
