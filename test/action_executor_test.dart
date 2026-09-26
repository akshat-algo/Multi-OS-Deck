import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_deck/models/deck_action.dart';
import 'package:stream_deck/server/windows_action_executor.dart';

void main() {
  test('WindowsActionExecutor finds OBS Studio if installed', () {
    if (!Platform.isWindows) return;
    final obs = WindowsActionExecutor.findObsPath();
    expect(obs, isNotNull);
    expect(File(obs!).existsSync(), isTrue);
  });

  test('WindowsActionExecutor executes media commands natively', () async {
    final resMute = await WindowsActionExecutor.execute(DeckAction.media('volume_mute'));
    expect(resMute, isTrue);

    // Toggle back so volume is restored
    final resMuteBack = await WindowsActionExecutor.execute(DeckAction.media('volume_mute'));
    expect(resMuteBack, isTrue);
  });

  test('WindowsActionExecutor executes window and browser commands', () async {
    final resWindow = await WindowsActionExecutor.execute(DeckAction.window('show_desktop'));
    expect(resWindow, isTrue);

    final resBrowser = await WindowsActionExecutor.execute(DeckAction.browser('refresh'));
    expect(resBrowser, isTrue);
  });

  test('WindowsActionExecutor executes F13-F24 stream deck keys', () async {
    for (int i = 13; i <= 24; i++) {
      final res = await WindowsActionExecutor.execute(DeckAction.streamDeckKey('F$i'));
      expect(res, isTrue);
    }
  });

  test('WindowsActionExecutor executes hotkeys without NumLock error', () async {
    final res = await WindowsActionExecutor.execute(DeckAction.hotkey('ctrl+shift+m'));
    expect(res, isTrue);
  });
}
