import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';

typedef _MapVirtualKeyC = Uint32 Function(Uint32 uCode, Uint32 uMapType);
typedef _MapVirtualKeyDart = int Function(int uCode, int uMapType);

void main() {
  test('Check scan codes', () {
    final user32 = DynamicLibrary.open('user32.dll');
    final mapVk = user32.lookupFunction<_MapVirtualKeyC, _MapVirtualKeyDart>('MapVirtualKeyA');
    print('VK_LWIN (0x5B) scan: ${mapVk(0x5B, 0)}');
    print('VK_D (0x44) scan: ${mapVk(0x44, 0)}');
    print('VK_CONTROL (0x11) scan: ${mapVk(0x11, 0)}');
    print('VK_SHIFT (0x10) scan: ${mapVk(0x10, 0)}');
    print('VK_MENU/ALT (0x12) scan: ${mapVk(0x12, 0)}');
  });
}
