import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';

typedef _SendMessageWC = IntPtr Function(IntPtr hWnd, Uint32 msg, IntPtr wParam, IntPtr lParam);
typedef _SendMessageWDart = int Function(int hWnd, int msg, int wParam, int lParam);

void main() {
  test('Test WM_APPCOMMAND volume control', () {
    final user32 = DynamicLibrary.open('user32.dll');
    final sendMsg = user32.lookupFunction<_SendMessageWC, _SendMessageWDart>('SendMessageW');

    const int wmAppCommand = 0x0319;
    const int hwndBroadcast = 0xFFFF;
    const int appcommandVolumeUp = 10;
    const int appcommandVolumeDown = 9;

    print('Sending WM_APPCOMMAND Volume Up');
    final resUp = sendMsg(hwndBroadcast, wmAppCommand, 0, appcommandVolumeUp << 16);
    print('Result Up: $resUp');

    final resDown = sendMsg(hwndBroadcast, wmAppCommand, 0, appcommandVolumeDown << 16);
    print('Result Down: $resDown');
  });
}
