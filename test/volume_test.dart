import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';

typedef _KeybdEventC = Void Function(Uint8 bVk, Uint8 bScan, Uint32 dwFlags, IntPtr dwExtraInfo);
typedef _KeybdEventDart = void Function(int bVk, int bScan, int dwFlags, int dwExtraInfo);

void main() {
  test('Test if keybd_event VK_VOLUME_UP changes volume', () async {
    final user32 = DynamicLibrary.open('user32.dll');
    final keybdEvent = user32.lookupFunction<_KeybdEventC, _KeybdEventDart>('keybd_event');

    print('Calling keybd_event for VK_VOLUME_UP (0xAF)');
    // Try both without scan and with scan
    keybdEvent(0xAF, 0, 0x0001, 0); // Extended keydown
    await Future.delayed(const Duration(milliseconds: 30));
    keybdEvent(0xAF, 0, 0x0002 | 0x0001, 0); // Extended keyup

    print('Finished sending VK_VOLUME_UP');
  });
}
