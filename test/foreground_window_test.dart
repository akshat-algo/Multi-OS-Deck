import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _GetForegroundWindowC = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();

typedef _GetWindowTextWC = Int32 Function(IntPtr hWnd, Pointer<Utf16> lpString, Int32 nMaxCount);
typedef _GetWindowTextWDart = int Function(int hWnd, Pointer<Utf16> lpString, int nMaxCount);

void main() {
  test('Check GetForegroundWindow and GetWindowTextW', () {
    final user32 = DynamicLibrary.open('user32.dll');
    final getFg = user32.lookupFunction<_GetForegroundWindowC, _GetForegroundWindowDart>('GetForegroundWindow');
    final getTxt = user32.lookupFunction<_GetWindowTextWC, _GetWindowTextWDart>('GetWindowTextW');

    final hwnd = getFg();
    print('Foreground hwnd: $hwnd');

    if (hwnd != 0) {
      final buf = calloc<Uint16>(256).cast<Utf16>();
      final len = getTxt(hwnd, buf, 256);
      final title = buf.toDartString();
      calloc.free(buf);
      print('Foreground Title ($len chars): "$title"');
    }
  });
}
