import 'dart:ffi';
import 'dart:io';
import '../models/deck_action.dart';

// Win32 C Typedefs
typedef _OpenWindowStationWC = IntPtr Function(Pointer<Uint16> lpszWinSta, Int32 fInherit, Uint32 dwDesiredAccess);
typedef _OpenWindowStationWDart = int Function(Pointer<Uint16> lpszWinSta, int fInherit, int dwDesiredAccess);

typedef _SetProcessWindowStationC = Int32 Function(IntPtr hWinSta);
typedef _SetProcessWindowStationDart = int Function(int hWinSta);

typedef _OpenDesktopWC = IntPtr Function(Pointer<Uint16> lpszDesktop, Uint32 dwFlags, Int32 fInherit, Uint32 dwDesiredAccess);
typedef _OpenDesktopWDart = int Function(Pointer<Uint16> lpszDesktop, int dwFlags, int fInherit, int dwDesiredAccess);

typedef _SetThreadDesktopC = Int32 Function(IntPtr hDesktop);
typedef _SetThreadDesktopDart = int Function(int hDesktop);

typedef _GetForegroundWindowC = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();

typedef _GetWindowTextWC = Int32 Function(IntPtr hWnd, Pointer<Uint16> lpString, Int32 nMaxCount);
typedef _GetWindowTextWDart = int Function(int hWnd, Pointer<Uint16> lpString, int nMaxCount);

typedef _GetClassNameWC = Int32 Function(IntPtr hWnd, Pointer<Uint16> lpClassName, Int32 nMaxCount);
typedef _GetClassNameWDart = int Function(int hWnd, Pointer<Uint16> lpClassName, int nMaxCount);

typedef _EnumWindowsC = Int32 Function(Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>> lpEnumFunc, IntPtr lParam);
typedef _EnumWindowsDart = int Function(Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>> lpEnumFunc, int lParam);

typedef _IsWindowVisibleC = Int32 Function(IntPtr hWnd);
typedef _IsWindowVisibleDart = int Function(int hWnd);

typedef _SetForegroundWindowC = Int32 Function(IntPtr hWnd);
typedef _SetForegroundWindowDart = int Function(int hWnd);

typedef _ShowWindowC = Int32 Function(IntPtr hWnd, Int32 nCmdShow);
typedef _ShowWindowDart = int Function(int hWnd, int nCmdShow);

typedef _AttachThreadInputC = Int32 Function(Uint32 idAttach, Uint32 idAttachTo, Int32 fAttach);
typedef _AttachThreadInputDart = int Function(int idAttach, int idAttachTo, int fAttach);

typedef _GetWindowThreadProcessIdC = Uint32 Function(IntPtr hWnd, Pointer<Uint32> lpdwProcessId);
typedef _GetWindowThreadProcessIdDart = int Function(int hWnd, Pointer<Uint32> lpdwProcessId);

typedef _GetCurrentThreadIdC = Uint32 Function();
typedef _GetCurrentThreadIdDart = int Function();

typedef _KeybdEventC = Void Function(Uint8 bVk, Uint8 bScan, Uint32 dwFlags, IntPtr dwExtraInfo);
typedef _KeybdEventDart = void Function(int bVk, int bScan, int dwFlags, int dwExtraInfo);

typedef _MapVirtualKeyC = Uint32 Function(Uint32 uCode, Uint32 uMapType);
typedef _MapVirtualKeyDart = int Function(int uCode, int uMapType);

typedef _LockWorkStationC = Int32 Function();
typedef _LockWorkStationDart = int Function();

typedef _MallocC = Pointer Function(IntPtr size);
typedef _MallocDart = Pointer Function(int size);

typedef _FreeC = Void Function(Pointer ptr);
typedef _FreeDart = void Function(Pointer ptr);

/// Executes actions natively on the Windows operating system with zero latency,
/// dual hardware multimedia keys + intelligent active browser / YouTube injection.
class WindowsActionExecutor {
  static DynamicLibrary? _user32;
  static DynamicLibrary? _kernel32;
  static DynamicLibrary? _msvcrt;

  static _OpenWindowStationWDart? _openWindowStation;
  static _SetProcessWindowStationDart? _setProcessWindowStation;
  static _OpenDesktopWDart? _openDesktop;
  static _SetThreadDesktopDart? _setThreadDesktop;

  static _GetForegroundWindowDart? _getForegroundWindow;
  static _GetWindowTextWDart? _getWindowTextW;
  static _GetClassNameWDart? _getClassNameW;
  static _EnumWindowsDart? _enumWindows;
  static _IsWindowVisibleDart? _isWindowVisible;
  static _SetForegroundWindowDart? _setForegroundWindow;
  static _ShowWindowDart? _showWindow;
  static _AttachThreadInputDart? _attachThreadInput;
  static _GetWindowThreadProcessIdDart? _getWindowThreadProcessId;
  static _GetCurrentThreadIdDart? _getCurrentThreadId;

  static _KeybdEventDart? _keybdEvent;
  static _MapVirtualKeyDart? _mapVirtualKey;
  static _LockWorkStationDart? _lockWorkStation;

  static _MallocDart? _malloc;
  static _FreeDart? _free;

  static bool _initialized = false;

  static const int _keyeventfKeydown = 0x0000;
  static const int _keyeventfExtendedkey = 0x0001;
  static const int _keyeventfKeyup = 0x0002;

  // Standard OEM scan codes for extended multimedia keys
  static const int _scanMute = 0x20;
  static const int _scanVolDown = 0x2E;
  static const int _scanVolUp = 0x30;
  static const int _scanPlayPause = 0x22;
  static const int _scanNextTrack = 0x19;
  static const int _scanPrevTrack = 0x10;
  static const int _scanStop = 0x24;

  static ({int hwnd, String title, String className, bool isBrowser, bool isYouTube})? _cachedWindow;
  static int _lastWindowCheckTime = 0;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    if (Platform.isWindows) {
      try {
        _user32 = DynamicLibrary.open('user32.dll');
        _kernel32 = DynamicLibrary.open('kernel32.dll');
        _msvcrt = DynamicLibrary.open('msvcrt.dll');

        _malloc = _msvcrt!.lookupFunction<_MallocC, _MallocDart>('malloc');
        _free = _msvcrt!.lookupFunction<_FreeC, _FreeDart>('free');

        _openWindowStation = _user32!.lookupFunction<_OpenWindowStationWC, _OpenWindowStationWDart>('OpenWindowStationW');
        _setProcessWindowStation = _user32!.lookupFunction<_SetProcessWindowStationC, _SetProcessWindowStationDart>('SetProcessWindowStation');
        _openDesktop = _user32!.lookupFunction<_OpenDesktopWC, _OpenDesktopWDart>('OpenDesktopW');
        _setThreadDesktop = _user32!.lookupFunction<_SetThreadDesktopC, _SetThreadDesktopDart>('SetThreadDesktop');

        _getForegroundWindow = _user32!.lookupFunction<_GetForegroundWindowC, _GetForegroundWindowDart>('GetForegroundWindow');
        _getWindowTextW = _user32!.lookupFunction<_GetWindowTextWC, _GetWindowTextWDart>('GetWindowTextW');
        _getClassNameW = _user32!.lookupFunction<_GetClassNameWC, _GetClassNameWDart>('GetClassNameW');
        _enumWindows = _user32!.lookupFunction<_EnumWindowsC, _EnumWindowsDart>('EnumWindows');
        _isWindowVisible = _user32!.lookupFunction<_IsWindowVisibleC, _IsWindowVisibleDart>('IsWindowVisible');
        _setForegroundWindow = _user32!.lookupFunction<_SetForegroundWindowC, _SetForegroundWindowDart>('SetForegroundWindow');
        _showWindow = _user32!.lookupFunction<_ShowWindowC, _ShowWindowDart>('ShowWindow');
        _attachThreadInput = _user32!.lookupFunction<_AttachThreadInputC, _AttachThreadInputDart>('AttachThreadInput');
        _getWindowThreadProcessId = _user32!.lookupFunction<_GetWindowThreadProcessIdC, _GetWindowThreadProcessIdDart>('GetWindowThreadProcessId');
        _getCurrentThreadId = _kernel32!.lookupFunction<_GetCurrentThreadIdC, _GetCurrentThreadIdDart>('GetCurrentThreadId');

        _keybdEvent = _user32!.lookupFunction<_KeybdEventC, _KeybdEventDart>('keybd_event');
        _mapVirtualKey = _user32!.lookupFunction<_MapVirtualKeyC, _MapVirtualKeyDart>('MapVirtualKeyA');
        _lockWorkStation = _user32!.lookupFunction<_LockWorkStationC, _LockWorkStationDart>('LockWorkStation');

        // Automatically attach process and calling thread to interactive desktop station WinSta0\Default
        _attachToInteractiveDesktop();
      } catch (e) {
        print('[ACTION] Warning: Native Win32 FFI initialization note: $e');
      }
    }
  }

  /// Attaches the server process & thread to the interactive Windows station and desktop.
  static void _attachToInteractiveDesktop() {
    if (_malloc == null || _free == null || _openWindowStation == null) return;
    try {
      final winstaName = _toUtf16('WinSta0');
      final desktopName = _toUtf16('Default');

      final hWinSta = _openWindowStation!(winstaName, 0, 0x02000000); // MAXIMUM_ALLOWED
      if (hWinSta != 0 && _setProcessWindowStation != null) {
        _setProcessWindowStation!(hWinSta);
      }

      final hDesktop = _openDesktop!(desktopName, 0, 0, 0x02000000); // MAXIMUM_ALLOWED
      if (hDesktop != 0 && _setThreadDesktop != null) {
        _setThreadDesktop!(hDesktop);
      }

      _free!(winstaName.cast());
      _free!(desktopName.cast());
    } catch (_) {}
  }

  static Pointer<Uint16> _toUtf16(String str) {
    final units = str.codeUnits;
    final ptr = _malloc!((units.length + 1) * 2).cast<Uint16>();
    for (var i = 0; i < units.length; i++) {
      ptr[i] = units[i];
    }
    ptr[units.length] = 0;
    return ptr;
  }

  /// Retrieves details of the current foreground active window.
  static ({int hwnd, String title, String className, bool isBrowser, bool isYouTube}) getActiveWindow() {
    _ensureInitialized();
    if (_getForegroundWindow == null || _malloc == null || _free == null) {
      return (hwnd: 0, title: '', className: '', isBrowser: false, isYouTube: false);
    }

    final hwnd = _getForegroundWindow!();
    if (hwnd == 0) {
      return (hwnd: 0, title: '', className: '', isBrowser: false, isYouTube: false);
    }

    final bufTitle = _malloc!(1024).cast<Uint16>();
    final bufClass = _malloc!(1024).cast<Uint16>();

    final lenTitle = _getWindowTextW?.call(hwnd, bufTitle, 512) ?? 0;
    final lenClass = _getClassNameW?.call(hwnd, bufClass, 512) ?? 0;

    final title = lenTitle > 0 ? String.fromCharCodes(Iterable.generate(lenTitle, (i) => bufTitle[i])) : '';
    final className = lenClass > 0 ? String.fromCharCodes(Iterable.generate(lenClass, (i) => bufClass[i])) : '';

    _free!(bufTitle.cast());
    _free!(bufClass.cast());

    final lowerTitle = title.toLowerCase();
    final lowerClass = className.toLowerCase();

    final isBrowser = lowerClass.contains('chrome_widgetwin') ||
        lowerClass.contains('mozillaclass') ||
        lowerClass.contains('applicationframewindow') ||
        lowerTitle.contains('chrome') ||
        lowerTitle.contains('edge') ||
        lowerTitle.contains('brave') ||
        lowerTitle.contains('firefox') ||
        lowerTitle.contains('opera');

    final isYouTube = lowerTitle.contains('youtube');

    return (
      hwnd: hwnd,
      title: title,
      className: className,
      isBrowser: isBrowser,
      isYouTube: isYouTube,
    );
  }

  /// Throttled lookup of active window for ultra-fast repeated volume triggers.
  static ({int hwnd, String title, String className, bool isBrowser, bool isYouTube}) getActiveWindowCached({int ttlMs = 400}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedWindow != null && (now - _lastWindowCheckTime) < ttlMs) {
      return _cachedWindow!;
    }
    _cachedWindow = getActiveWindow();
    _lastWindowCheckTime = now;
    return _cachedWindow!;
  }

  /// Locates an open browser window playing or displaying YouTube.
  static int? findYouTubeWindow() {
    _ensureInitialized();
    if (_enumWindows == null || _malloc == null || _free == null) return null;

    int? foundHwnd;
    final bufTitle = _malloc!(1024).cast<Uint16>();

    int enumProc(int hwnd, int lparam) {
      if (_isWindowVisible?.call(hwnd) != 0) {
        final len = _getWindowTextW?.call(hwnd, bufTitle, 512) ?? 0;
        if (len > 0) {
          final title = String.fromCharCodes(Iterable.generate(len, (i) => bufTitle[i]));
          if (title.toLowerCase().contains('youtube')) {
            foundHwnd = hwnd;
            return 0; // stop enumeration
          }
        }
      }
      return 1;
    }

    final nativeCallable = NativeCallable<Int32 Function(IntPtr, IntPtr)>.isolateLocal(enumProc, exceptionalReturn: 0);
    _enumWindows!(nativeCallable.nativeFunction, 0);
    nativeCallable.close();

    _free!(bufTitle.cast());
    return foundHwnd;
  }

  /// Focuses a target window to receive foreground keystrokes.
  static bool focusWindow(int hwnd) {
    if (hwnd == 0 || _setForegroundWindow == null) return false;

    final currentHwnd = _getForegroundWindow?.call() ?? 0;
    if (currentHwnd == hwnd) return true;

    final currentThreadId = _getCurrentThreadId?.call() ?? 0;
    final fgThreadId = _getWindowThreadProcessId != null ? _getWindowThreadProcessId!(currentHwnd, nullptr) : 0;

    if (fgThreadId != 0 && fgThreadId != currentThreadId && _attachThreadInput != null) {
      _attachThreadInput!(currentThreadId, fgThreadId, 1);
    }

    _showWindow?.call(hwnd, 9); // SW_RESTORE
    final ok = _setForegroundWindow!(hwnd);

    if (fgThreadId != 0 && fgThreadId != currentThreadId && _attachThreadInput != null) {
      _attachThreadInput!(currentThreadId, fgThreadId, 0);
    }

    return ok != 0;
  }

  /// Main dispatch entry point for any DeckAction.
  static Future<bool> execute(DeckAction action) async {
    _ensureInitialized();

    if (!Platform.isWindows) {
      return true;
    }

    try {
      switch (action.type) {
        case DeckActionType.media:
          return await _executeMedia(action.command);

        case DeckActionType.hotkey:
          return await _executeHotkey(action.command);

        case DeckActionType.window:
          return await _executeWindowCommand(action.command);

        case DeckActionType.browser:
          return await _executeBrowserCommand(action.command);

        case DeckActionType.streamDeckKey:
          return await _executeStreamDeckKey(action.command);

        case DeckActionType.obs:
          return await _executeObs(action.command, action.params);

        case DeckActionType.launchApp:
          final args = action.params['args'] as List?;
          return await _launchApp(
            action.command,
            args?.map((e) => e.toString()).toList(),
          );

        case DeckActionType.openUrl:
          return await _openUrl(action.command);

        case DeckActionType.script:
          final isPs = action.params['isPowershell'] as bool? ?? true;
          return await _runScript(action.command, isPowershell: isPs);

        case DeckActionType.systemMonitor:
          if (action.command == 'taskmgr' || action.command.isEmpty) {
            return await _launchApp('taskmgr');
          }
          return true;

        case DeckActionType.folder:
        case DeckActionType.pageNav:
        case DeckActionType.none:
          return true;
      }
    } catch (e) {
      print('[ACTION] Execution exception: $e');
      return false;
    }
  }

  // --- NATIVE KEYSTROKE SIMULATION & YOUTUBE / MEDIA CONTROLS ---

  /// Controls Windows Master Volume, Global Media Playback, and YouTube Player Controls.
  static Future<bool> _executeMedia(String cmd) async {
    final lower = cmd.toLowerCase().trim();

    // 1. Rapid Non-Blocking Volume Up / Volume Down (Immediate Synchronous Dispatch using dedicated Media Virtual-Keys)
    if (lower == 'volume_up' || lower == 'volup' || lower == 'vol_up') {
      _sendSingleKeySync(0xAF, scanCode: _scanVolUp, isExtended: true); // VK_VOLUME_UP (0xAF)
      return true;
    }

    if (lower == 'volume_down' || lower == 'voldown' || lower == 'vol_down') {
      _sendSingleKeySync(0xAE, scanCode: _scanVolDown, isExtended: true); // VK_VOLUME_DOWN (0xAE)
      return true;
    }

    final active = getActiveWindow();
    print('[ACTION] Processing media command: "$cmd" (Foreground: "${active.title}", IsYouTube: ${active.isYouTube}, IsBrowser: ${active.isBrowser})');

    // 2. Global Media Actions (Emitting dedicated Windows Media Virtual-Key codes)
    switch (lower) {
      case 'volume_mute':
      case 'mute':
      case 'vol_mute':
        _sendSingleKeySync(0xAD, scanCode: _scanMute, isExtended: true); // VK_VOLUME_MUTE (0xAD)
        return true;

      case 'play':
      case 'pause':
      case 'play_pause':
        // Global Hardware Multimedia Play/Pause key (VK_MEDIA_PLAY_PAUSE 0xB3)
        // Dispatched with immediate key-down and key-up with zero delay/secondary keys
        _sendSingleKeySync(0xB3, scanCode: _scanPlayPause, isExtended: true);
        return true;

      case 'next':
      case 'next_track':
        _sendSingleKeySync(0xB0, scanCode: _scanNextTrack, isExtended: true); // VK_MEDIA_NEXT_TRACK (0xB0)
        return true;

      case 'prev':
      case 'prev_track':
        _sendSingleKeySync(0xB1, scanCode: _scanPrevTrack, isExtended: true); // VK_MEDIA_PREV_TRACK (0xB1)
        return true;

      case 'stop':
        _sendSingleKeySync(0xB2, scanCode: _scanStop, isExtended: true); // VK_MEDIA_STOP (0xB2)
        return true;

      case 'mic_mute':
      case 'mic_toggle':
        return await _executeHotkey('ctrl+shift+m');
    }

    // 3. Dedicated YouTube Controls (if specifically configured as youtube_* actions)
    if (lower == 'youtube_play' || lower == 'yt_play' || lower == 'youtube_play_pause' || lower == 'yt_play_pause') {
      return await _sendYouTubeKey('k');
    }
    if (lower == 'youtube_mute' || lower == 'yt_mute') {
      return await _sendYouTubeKey('m');
    }
    if (lower == 'youtube_seek_fwd' || lower == 'yt_seek_fwd' || lower == 'seek_fwd') {
      return await _sendYouTubeKey('l');
    }
    if (lower == 'youtube_seek_back' || lower == 'yt_seek_back' || lower == 'seek_back') {
      return await _sendYouTubeKey('j');
    }
    if (lower == 'youtube_vol_up' || lower == 'yt_vol_up') {
      return await _sendYouTubeKey('up');
    }
    if (lower == 'youtube_vol_down' || lower == 'yt_vol_down') {
      return await _sendYouTubeKey('down');
    }
    if (lower == 'youtube_fullscreen' || lower == 'yt_fullscreen') {
      return await _sendYouTubeKey('f');
    }
    if (lower == 'youtube_theater' || lower == 'yt_theater') {
      return await _sendYouTubeKey('t');
    }
    if (lower == 'youtube_next' || lower == 'yt_next') {
      return await _sendYouTubeKey('shift+n');
    }

    return false;
  }

  /// Sends a key combination directly to YouTube, focusing the YouTube window if necessary.
  static Future<bool> _sendYouTubeKey(String keyCombo) async {
    final active = getActiveWindow();
    if (active.isYouTube) {
      return await _executeHotkey(keyCombo);
    }

    final ytHwnd = findYouTubeWindow();
    if (ytHwnd != null) {
      focusWindow(ytHwnd);
      await Future.delayed(const Duration(milliseconds: 40));
      return await _executeHotkey(keyCombo);
    }

    // Fallback: send hotkey to current foreground window
    return await _executeHotkey(keyCombo);
  }

  /// Executes window management actions directly.
  static Future<bool> _executeWindowCommand(String cmd) async {
    switch (cmd.toLowerCase().trim()) {
      case 'show_desktop':
      case 'desktop':
        return await _executeHotkey('win+d');
      case 'minimize':
      case 'minimize_window':
        return await _executeHotkey('win+down');
      case 'maximize':
      case 'maximize_window':
        return await _executeHotkey('win+up');
      case 'snap_left':
        return await _executeHotkey('win+left');
      case 'snap_right':
        return await _executeHotkey('win+right');
      case 'close_window':
      case 'close_app':
        return await _executeHotkey('alt+f4');
      case 'switch_window':
      case 'alt_tab':
        return await _executeHotkey('alt+tab');
      case 'next_desktop':
        return await _executeHotkey('ctrl+win+right');
      case 'prev_desktop':
        return await _executeHotkey('ctrl+win+left');
      default:
        return false;
    }
  }

  /// Executes browser shortcuts directly.
  static Future<bool> _executeBrowserCommand(String cmd) async {
    switch (cmd.toLowerCase().trim()) {
      case 'new_tab':
        return await _executeHotkey('ctrl+t');
      case 'close_tab':
        return await _executeHotkey('ctrl+w');
      case 'reopen_tab':
        return await _executeHotkey('ctrl+shift+t');
      case 'refresh':
        return await _executeHotkey('f5');
      case 'hard_refresh':
        return await _executeHotkey('ctrl+f5');
      case 'devtools':
      case 'inspect':
        return await _executeHotkey('f12');
      case 'next_tab':
        return await _executeHotkey('ctrl+tab');
      case 'prev_tab':
        return await _executeHotkey('ctrl+shift+tab');
      case 'bookmark':
        return await _executeHotkey('ctrl+d');
      default:
        return false;
    }
  }

  /// Sends Stream Deck dedicated virtual keys F13–F24 (0x7C–0x87).
  static Future<bool> _executeStreamDeckKey(String fKey) async {
    final clean = fKey.toLowerCase().replaceAll('f', '').trim();
    final num = int.tryParse(clean);
    if (num != null && num >= 13 && num <= 24) {
      final vk = 0x7C + (num - 13);
      final scan = 0x64 + (num - 13);
      await _sendSingleKey(vk, scanCode: scan);
      return true;
    }
    return false;
  }

  /// Simulates clean, precise keystroke combinations on Windows.
  static Future<bool> _executeHotkey(String keys) async {
    final lower = keys.trim().toLowerCase();

    // Dedicated Windows lock
    if (lower == 'lock' || lower == 'win+l') {
      if (_lockWorkStation != null) {
        _lockWorkStation!();
        return true;
      }
      Process.run('rundll32.exe', ['user32.dll,LockWorkStation']);
      return true;
    }

    // Dedicated Snipping Tool & Screenshot
    if (lower == 'snip' || lower == 'win+shift+s' || lower == 'screenshot') {
      try {
        Process.run('explorer.exe', ['ms-screenclip:']);
      } catch (_) {}

      if (_keybdEvent != null) {
        try {
          _keybdEvent!(0x5B, 0, _keyeventfExtendedkey, 0); // Win down
          _keybdEvent!(0x10, 0, 0, 0); // Shift down
          _keybdEvent!(0x53, 0x1F, 0, 0); // 'S' down
          _keybdEvent!(0x53, 0x1F, _keyeventfKeyup, 0); // 'S' up
        } finally {
          _keybdEvent!(0x10, 0, _keyeventfKeyup, 0); // Shift up
          _keybdEvent!(0x5B, 0, _keyeventfExtendedkey | _keyeventfKeyup, 0); // Win up
        }
      }

      _sendSingleKeySync(0x2C, isExtended: true);
      return true;
    }

    final parts = lower.split('+').map((s) => s.trim()).toList();
    if (parts.isEmpty) return false;

    final modifiersDown = <int>[];
    int? mainKey;
    int mainScan = 0;
    bool isMainExtended = false;

    for (final part in parts) {
      if (part == 'ctrl' || part == 'control') {
        modifiersDown.add(0x11); // VK_CONTROL
      } else if (part == 'shift') {
        modifiersDown.add(0x10); // VK_SHIFT
      } else if (part == 'alt' || part == 'menu') {
        modifiersDown.add(0x12); // VK_MENU
      } else if (part == 'win' || part == 'windows' || part == 'cmd') {
        modifiersDown.add(0x5B); // VK_LWIN
      } else {
        final resolved = _resolveVirtualKey(part);
        if (resolved != null) {
          mainKey = resolved.key;
          mainScan = resolved.scanCode;
          isMainExtended = resolved.isExtended;
        }
      }
    }

    if (mainKey == null && modifiersDown.isEmpty) return false;

    if (_keybdEvent != null) {
      try {
        // 1. Press all modifiers down
        for (final mod in modifiersDown) {
          final ext = (mod == 0x5B) ? _keyeventfExtendedkey : 0;
          final scan = _mapVirtualKey != null ? _mapVirtualKey!(mod, 0) : 0;
          _keybdEvent!(mod, scan, _keyeventfKeydown | ext, 0);
        }

        // 2. Press main key down and immediately up (release)
        if (mainKey != null) {
          final ext = isMainExtended ? _keyeventfExtendedkey : 0;
          final scan = mainScan != 0 ? mainScan : (_mapVirtualKey != null ? _mapVirtualKey!(mainKey, 0) : 0);
          _keybdEvent!(mainKey, scan, _keyeventfKeydown | ext, 0);
          _keybdEvent!(mainKey, scan, _keyeventfKeyup | ext, 0);
        }
      } finally {
        // 3. Release all modifiers in reverse order immediately
        for (final mod in modifiersDown.reversed) {
          final ext = (mod == 0x5B) ? _keyeventfExtendedkey : 0;
          final scan = _mapVirtualKey != null ? _mapVirtualKey!(mod, 0) : 0;
          _keybdEvent!(mod, scan, _keyeventfKeyup | ext, 0);
        }
      }

      return true;
    }

    return false;
  }

  /// Synchronous, non-blocking single key dispatch for rapid taps and hold-to-repeat.
  /// Every simulated key-down event is immediately followed by a corresponding key-up event.
  static void _sendSingleKeySync(int vk, {int scanCode = 0, bool isExtended = false}) {
    if (_keybdEvent != null) {
      final ext = isExtended ? _keyeventfExtendedkey : 0;
      final scan = scanCode != 0 ? scanCode : (_mapVirtualKey != null ? _mapVirtualKey!(vk, 0) : 0);
      _keybdEvent!(vk, scan, _keyeventfKeydown | ext, 0);
      _keybdEvent!(vk, scan, _keyeventfKeyup | ext, 0);
    }
  }

  static Future<void> _sendSingleKey(int vk, {int scanCode = 0, bool isExtended = false}) async {
    _sendSingleKeySync(vk, scanCode: scanCode, isExtended: isExtended);
  }

  static _KeyMapping? _resolveVirtualKey(String keyName) {
    final k = keyName.toLowerCase().trim();

    // A-Z
    if (k.length == 1 && k.codeUnitAt(0) >= 97 && k.codeUnitAt(0) <= 122) {
      final code = k.toUpperCase().codeUnitAt(0);
      return _KeyMapping(code, 0, false);
    }

    // 0-9
    if (k.length == 1 && k.codeUnitAt(0) >= 48 && k.codeUnitAt(0) <= 57) {
      return _KeyMapping(k.codeUnitAt(0), 0, false);
    }

    // Function keys F1-F24 (mapped to exact Win32 virtual keys)
    if (k.startsWith('f') && k.length > 1) {
      final num = int.tryParse(k.substring(1));
      if (num != null) {
        if (num >= 1 && num <= 12) {
          return _KeyMapping(0x70 + (num - 1), 0x3B + (num - 1), false);
        } else if (num >= 13 && num <= 24) {
          // Win32 VK_F13 (0x7C) to VK_F24 (0x87)
          return _KeyMapping(0x7C + (num - 13), 0x64 + (num - 13), false);
        }
      }
    }

    // Special keys
    switch (k) {
      case 'enter':
      case 'return':
        return const _KeyMapping(0x0D, 0x1C, false);
      case 'esc':
      case 'escape':
        return const _KeyMapping(0x1B, 0x01, false);
      case 'tab':
        return const _KeyMapping(0x09, 0x0F, false);
      case 'space':
        return const _KeyMapping(0x20, 0x39, false);
      case 'backspace':
        return const _KeyMapping(0x08, 0x0E, false);
      case 'delete':
      case 'del':
        return const _KeyMapping(0x2E, 0x53, true);
      case 'insert':
        return const _KeyMapping(0x2D, 0x52, true);
      case 'home':
        return const _KeyMapping(0x24, 0x47, true);
      case 'end':
        return const _KeyMapping(0x23, 0x4F, true);
      case 'pageup':
      case 'pgup':
        return const _KeyMapping(0x21, 0x49, true);
      case 'pagedown':
      case 'pgdn':
        return const _KeyMapping(0x22, 0x51, true);
      case 'up':
        return const _KeyMapping(0x26, 0x48, true);
      case 'down':
        return const _KeyMapping(0x28, 0x50, true);
      case 'left':
        return const _KeyMapping(0x25, 0x4B, true);
      case 'right':
        return const _KeyMapping(0x27, 0x4D, true);
      case 'printscreen':
      case 'prtscr':
      case 'snapshot':
        return const _KeyMapping(0x2C, 0x37, true);
      default:
        return null;
    }
  }

  // --- OBS STUDIO SMART CONTROLLER & AUTODISCOVERY ---

  static String? findObsPath() {
    final candidatePaths = [
      r'C:\Program Files\obs-studio\bin\64bit\obs64.exe',
      r'C:\Program Files (x86)\obs-studio\bin\64bit\obs64.exe',
      r'C:\Program Files (x86)\obs-studio\bin\32bit\obs32.exe',
      if (Platform.environment['LOCALAPPDATA'] != null)
        '${Platform.environment['LOCALAPPDATA']}\\Programs\\obs-studio\\bin\\64bit\\obs64.exe',
      if (Platform.environment['PROGRAMFILES'] != null)
        '${Platform.environment['PROGRAMFILES']}\\obs-studio\\bin\\64bit\\obs64.exe',
    ];

    for (final path in candidatePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  static Future<bool> isObsRunning() async {
    try {
      final res = await Process.run('tasklist', ['/FI', 'IMAGENAME eq obs64.exe', '/NH']);
      if (res.stdout.toString().toLowerCase().contains('obs64.exe')) return true;

      final res32 = await Process.run('tasklist', ['/FI', 'IMAGENAME eq obs32.exe', '/NH']);
      return res32.stdout.toString().toLowerCase().contains('obs32.exe');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _executeObs(String obsCommand, Map<String, dynamic> params) async {
    final cmd = obsCommand.toLowerCase().trim();
    print('[OBS] Executing OBS action: "$cmd"');

    final running = await isObsRunning();

    if (!running) {
      print('[OBS] Warning: OBS Studio is not currently running.');
      if (cmd == 'launch_obs') {
        final obsPath = findObsPath();
        if (obsPath != null) {
          final obsFile = File(obsPath);
          try {
            await Process.run('cmd', ['/c', 'start', '', obsFile.path], workingDirectory: obsFile.parent.path);
            print('[OBS] OBS Studio launched successfully.');
            return true;
          } catch (e) {
            print('[OBS] Error launching OBS Studio: $e');
            return false;
          }
        } else {
          try {
            await Process.run('cmd', ['/c', 'start', 'obs']);
            return true;
          } catch (_) {}
        }
      }
      print('[OBS] Warning: OBS Studio is not open; action "$cmd" was skipped gracefully.');
      return true;
    }

    switch (cmd) {
      case 'stream_toggle':
      case 'start_streaming':
        return _executeHotkey(params['hotkey'] ?? 'ctrl+shift+f13');
      case 'record_toggle':
      case 'start_recording':
        return _executeHotkey(params['hotkey'] ?? 'ctrl+shift+f14');
      case 'camera_toggle':
      case 'virtualcam_toggle':
        return _executeHotkey(params['hotkey'] ?? 'ctrl+shift+f15');
      case 'replay_save':
        return _executeHotkey(params['hotkey'] ?? 'ctrl+shift+f16');
      case 'scene_gaming':
        return _executeHotkey(params['hotkey'] ?? 'ctrl+shift+1');
      case 'scene_chatting':
        return _executeHotkey(params['hotkey'] ?? 'ctrl+shift+2');
      case 'scene_brb':
        return _executeHotkey(params['hotkey'] ?? 'ctrl+shift+3');
      case 'launch_obs':
      default:
        return true;
    }
  }

  // --- SMART APPLICATION LAUNCHER VIA WINDOWS SHELL ---

  static Future<bool> _launchApp(String appNameOrPath, [List<String>? args]) async {
    final clean = appNameOrPath.toLowerCase().trim();
    print('[LAUNCH] Attempting to open: $appNameOrPath');

    try {
      // 1. Task Manager
      if (clean == 'taskmgr' || clean == 'taskmgr.exe' || clean == 'task manager') {
        try {
          final res = await Process.run('cmd', ['/c', 'start', 'taskmgr']);
          if (res.exitCode == 0) return true;
        } catch (e) {
          print('[LAUNCH] Taskmgr cmd error: $e');
        }
        final res2 = await Process.run('powershell', ['-NoProfile', '-Command', 'Start-Process taskmgr']);
        return res2.exitCode == 0;
      }

      // 2. Calculator
      if (clean == 'calc' || clean == 'calculator') {
        try {
          final res = await Process.run('cmd', ['/c', 'start', 'calc:']);
          if (res.exitCode == 0) return true;
        } catch (_) {}
        final res2 = await Process.run('cmd', ['/c', 'start', 'calc']);
        return res2.exitCode == 0;
      }

      // 3. Google Chrome
      if (clean.contains('chrome')) {
        final localApp = Platform.environment['LOCALAPPDATA'];
        final chromePaths = [
          r'C:\Program Files\Google\Chrome\Application\chrome.exe',
          r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
          if (localApp != null) '$localApp\\Google\\Chrome\\Application\\chrome.exe',
        ];
        for (final p in chromePaths) {
          if (File(p).existsSync()) {
            final res = await Process.run('cmd', ['/c', 'start', '', p]);
            if (res.exitCode == 0) return true;
          }
        }
        final res = await Process.run('cmd', ['/c', 'start', 'chrome']);
        return res.exitCode == 0;
      }

      // 4. VS Code
      if (clean == 'code' || clean == 'vscode' || clean.contains('vs code')) {
        final localApp = Platform.environment['LOCALAPPDATA'];
        final codePaths = [
          if (localApp != null) '$localApp\\Programs\\Microsoft VS Code\\Code.exe',
          r'C:\Program Files\Microsoft VS Code\Code.exe',
        ];
        for (final p in codePaths) {
          if (File(p).existsSync()) {
            final res = await Process.run('cmd', ['/c', 'start', '', p]);
            if (res.exitCode == 0) return true;
          }
        }
        final res = await Process.run('cmd', ['/c', 'start', 'code']);
        return res.exitCode == 0;
      }

      // 5. Terminal / PowerShell
      if (clean == 'terminal' || clean == 'wt' || clean == 'powershell') {
        try {
          final res = await Process.run('cmd', ['/c', 'start', 'wt']);
          if (res.exitCode == 0) return true;
        } catch (_) {}
        final res2 = await Process.run('cmd', ['/c', 'start', 'powershell']);
        return res2.exitCode == 0;
      }

      // 6. Notepad
      if (clean == 'notepad' || clean == 'notepad.exe') {
        final res = await Process.run('cmd', ['/c', 'start', 'notepad']);
        return res.exitCode == 0;
      }

      // 7. Spotify
      if (clean.contains('spotify')) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          final spotifyExe = File('$appData\\Spotify\\Spotify.exe');
          if (spotifyExe.existsSync()) {
            final res = await Process.run('cmd', ['/c', 'start', '', spotifyExe.path]);
            if (res.exitCode == 0) return true;
          }
        }
        final res = await Process.run('cmd', ['/c', 'start', '', 'spotify:']);
        return res.exitCode == 0;
      }

      // 8. Generic Windows Shell start
      final res = await Process.run('cmd', ['/c', 'start', '', appNameOrPath]);
      return res.exitCode == 0;
    } catch (e) {
      print('[LAUNCH] Error opening $appNameOrPath: $e');
      return false;
    }
  }

  static Future<bool> _openUrl(String url) async {
    var finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final res = await Process.run('cmd', ['/c', 'start', '', finalUrl]);
    return res.exitCode == 0;
  }

  static Future<bool> _runScript(String script, {bool isPowershell = true}) async {
    if (isPowershell) {
      final res = await Process.run('powershell', ['-NoProfile', '-Command', script]);
      return res.exitCode == 0;
    } else {
      final res = await Process.run('cmd', ['/c', script]);
      return res.exitCode == 0;
    }
  }
}

class _KeyMapping {
  final int key;
  final int scanCode;
  final bool isExtended;
  const _KeyMapping(this.key, this.scanCode, this.isExtended);
}
