import 'dart:ffi';
import 'dart:io';
import '../models/deck_action.dart';

typedef _KeybdEventC = Void Function(Uint8 bVk, Uint8 bScan, Uint32 dwFlags, IntPtr dwExtraInfo);
typedef _KeybdEventDart = void Function(int bVk, int bScan, int dwFlags, int dwExtraInfo);

typedef _MapVirtualKeyC = Uint32 Function(Uint32 uCode, Uint32 uMapType);
typedef _MapVirtualKeyDart = int Function(int uCode, int uMapType);

typedef _SendMessageWC = IntPtr Function(IntPtr hWnd, Uint32 msg, IntPtr wParam, IntPtr lParam);
typedef _SendMessageWDart = int Function(int hWnd, int msg, int wParam, int lParam);

typedef _SendNotifyMessageWC = Int32 Function(IntPtr hWnd, Uint32 msg, IntPtr wParam, IntPtr lParam);
typedef _SendNotifyMessageWDart = int Function(int hWnd, int msg, int wParam, int lParam);

typedef _LockWorkStationC = Int32 Function();
typedef _LockWorkStationDart = int Function();

/// Executes actions natively on the Windows operating system with zero latency,
/// direct virtual key synthesis (no NumLock toggling), and intelligent app discovery.
class WindowsActionExecutor {
  static DynamicLibrary? _user32;
  static _KeybdEventDart? _keybdEvent;
  static _MapVirtualKeyDart? _mapVirtualKey;
  static _LockWorkStationDart? _lockWorkStation;
  static _SendMessageWDart? _sendMessageW;
  static _SendNotifyMessageWDart? _sendNotifyMessageW;
  static bool _initialized = false;

  static const int _keyeventfKeydown = 0x0000;
  static const int _keyeventfExtendedkey = 0x0001;
  static const int _keyeventfKeyup = 0x0002;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    if (Platform.isWindows) {
      try {
        _user32 = DynamicLibrary.open('user32.dll');
        _keybdEvent = _user32!.lookupFunction<_KeybdEventC, _KeybdEventDart>('keybd_event');
        _mapVirtualKey = _user32!.lookupFunction<_MapVirtualKeyC, _MapVirtualKeyDart>('MapVirtualKeyA');
        _lockWorkStation = _user32!.lookupFunction<_LockWorkStationC, _LockWorkStationDart>('LockWorkStation');
        _sendMessageW = _user32!.lookupFunction<_SendMessageWC, _SendMessageWDart>('SendMessageW');
        _sendNotifyMessageW = _user32!.lookupFunction<_SendNotifyMessageWC, _SendNotifyMessageWDart>('SendNotifyMessageW');
      } catch (e) {
        // Fallback gracefully if FFI fails
      }
    }
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
            return await _launchApp('taskmgr.exe');
          }
          return true;

        case DeckActionType.folder:
        case DeckActionType.pageNav:
        case DeckActionType.none:
          return true;
      }
    } catch (e) {
      return false;
    }
  }

  // --- NATIVE KEYSTROKE SIMULATION (NO NUMLOCK ISSUE) ---

  /// Controls Windows Master Volume and Media Playback via dual WM_APPCOMMAND and direct VK codes.
  /// Controls Windows Master Volume, Media Playback, and YouTube Player Controls.
  static Future<bool> _executeMedia(String cmd) async {
    final lower = cmd.toLowerCase().trim();

    // Dedicated YouTube In-Browser Shortcuts (does not affect master OS volume)
    if (lower == 'youtube_play' || lower == 'yt_play' || lower == 'youtube_play_pause' || lower == 'yt_play_pause') {
      return await _executeHotkey('k');
    }
    if (lower == 'youtube_mute' || lower == 'yt_mute') {
      return await _executeHotkey('m');
    }
    if (lower == 'youtube_seek_fwd' || lower == 'yt_seek_fwd' || lower == 'seek_fwd') {
      return await _executeHotkey('l');
    }
    if (lower == 'youtube_seek_back' || lower == 'yt_seek_back' || lower == 'seek_back') {
      return await _executeHotkey('j');
    }
    if (lower == 'youtube_vol_up' || lower == 'yt_vol_up') {
      return await _executeHotkey('up');
    }
    if (lower == 'youtube_vol_down' || lower == 'yt_vol_down') {
      return await _executeHotkey('down');
    }
    if (lower == 'youtube_fullscreen' || lower == 'yt_fullscreen') {
      return await _executeHotkey('f');
    }
    if (lower == 'youtube_theater' || lower == 'yt_theater') {
      return await _executeHotkey('t');
    }
    if (lower == 'youtube_next' || lower == 'yt_next') {
      return await _executeHotkey('shift+n');
    }

    int vk = 0;
    int appCmd = 0;
    switch (lower) {
      case 'volume_up':
      case 'volup':
      case 'vol_up':
        vk = 0xAF; // VK_VOLUME_UP
        appCmd = 10; // APPCOMMAND_VOLUME_UP
        break;
      case 'volume_down':
      case 'voldown':
      case 'vol_down':
        vk = 0xAE; // VK_VOLUME_DOWN
        appCmd = 9; // APPCOMMAND_VOLUME_DOWN
        break;
      case 'volume_mute':
      case 'mute':
      case 'vol_mute':
        vk = 0xAD; // VK_VOLUME_MUTE
        appCmd = 8; // APPCOMMAND_VOLUME_MUTE
        break;
      case 'play':
      case 'pause':
      case 'play_pause':
        vk = 0xB3; // VK_MEDIA_PLAY_PAUSE
        appCmd = 14; // APPCOMMAND_MEDIA_PLAY_PAUSE
        break;
      case 'next':
      case 'next_track':
        vk = 0xB0; // VK_MEDIA_NEXT_TRACK
        appCmd = 11; // APPCOMMAND_MEDIA_NEXTTRACK
        break;
      case 'prev':
      case 'prev_track':
        vk = 0xB1; // VK_MEDIA_PREV_TRACK
        appCmd = 12; // APPCOMMAND_MEDIA_PREVIOUSTRACK
        break;
      case 'stop':
        vk = 0xB2; // VK_MEDIA_STOP
        appCmd = 13; // APPCOMMAND_MEDIA_STOP
        break;
      case 'mic_mute':
      case 'mic_toggle':
        appCmd = 44; // APPCOMMAND_MIC_ON_OFF_TOGGLE
        break;
      default:
        return false;
    }

    // 1. Synthesize virtual key FIRST! This directly changes Windows Master Volume / hardware Mute / Play-Pause
    if (vk > 0) {
      await _sendSingleKey(vk, isExtended: true);
    }

    // 2. Also broadcast WM_APPCOMMAND to all windows as a complementary broadcast
    if (appCmd > 0) {
      if (_sendNotifyMessageW != null) {
        _sendNotifyMessageW!(0xFFFF, 0x0319, 0, appCmd << 16);
      } else if (_sendMessageW != null) {
        _sendMessageW!(0xFFFF, 0x0319, 0, appCmd << 16);
      }
    }

    return true;
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
      await _sendSingleKey(vk);
      return true;
    }
    return false;
  }

  /// Simulates clean, precise keystroke combinations on Windows without NumLock interference.
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
        Process.run('cmd', ['/c', 'start', '', 'ms-screenclip:']);
      } catch (_) {}
      // Also send Win+Shift+S key combo natively
      await _sendSingleKey(0x2C, isExtended: true); // PrintScreen
      return true;
    }

    final parts = lower.split('+').map((s) => s.trim()).toList();
    if (parts.isEmpty) return false;

    final modifiersDown = <int>[];
    int? mainKey;
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
          isMainExtended = resolved.isExtended;
        }
      }
    }

    if (mainKey == null && modifiersDown.isEmpty) return false;

    if (_keybdEvent != null) {
      // 1. Press all modifiers down
      for (final mod in modifiersDown) {
        final ext = (mod == 0x5B) ? _keyeventfExtendedkey : 0;
        final scan = _mapVirtualKey != null ? _mapVirtualKey!(mod, 0) : 0;
        _keybdEvent!(mod, scan, _keyeventfKeydown | ext, 0);
      }

      await Future.delayed(const Duration(milliseconds: 15));

      // 2. Press main key down and up
      if (mainKey != null) {
        final ext = isMainExtended ? _keyeventfExtendedkey : 0;
        final scan = _mapVirtualKey != null ? _mapVirtualKey!(mainKey, 0) : 0;
        _keybdEvent!(mainKey, scan, _keyeventfKeydown | ext, 0);
        await Future.delayed(const Duration(milliseconds: 25));
        _keybdEvent!(mainKey, scan, _keyeventfKeyup | ext, 0);
      }

      await Future.delayed(const Duration(milliseconds: 15));

      // 3. Release all modifiers in reverse order
      for (final mod in modifiersDown.reversed) {
        final ext = (mod == 0x5B) ? _keyeventfExtendedkey : 0;
        final scan = _mapVirtualKey != null ? _mapVirtualKey!(mod, 0) : 0;
        _keybdEvent!(mod, scan, _keyeventfKeyup | ext, 0);
      }

      return true;
    }

    return false;
  }

  static Future<void> _sendSingleKey(int vk, {bool isExtended = false}) async {
    if (_keybdEvent != null) {
      final ext = isExtended ? _keyeventfExtendedkey : 0;
      final scan = _mapVirtualKey != null ? _mapVirtualKey!(vk, 0) : 0;
      _keybdEvent!(vk, scan, _keyeventfKeydown | ext, 0);
      await Future.delayed(const Duration(milliseconds: 25));
      _keybdEvent!(vk, scan, _keyeventfKeyup | ext, 0);
    }
  }

  static _KeyMapping? _resolveVirtualKey(String keyName) {
    final k = keyName.toLowerCase().trim();

    // A-Z
    if (k.length == 1 && k.codeUnitAt(0) >= 97 && k.codeUnitAt(0) <= 122) {
      return _KeyMapping(k.toUpperCase().codeUnitAt(0), false);
    }

    // 0-9
    if (k.length == 1 && k.codeUnitAt(0) >= 48 && k.codeUnitAt(0) <= 57) {
      return _KeyMapping(k.codeUnitAt(0), false);
    }

    // Function keys F1-F24
    if (k.startsWith('f') && k.length > 1) {
      final num = int.tryParse(k.substring(1));
      if (num != null) {
        if (num >= 1 && num <= 12) {
          return _KeyMapping(0x70 + (num - 1), false);
        } else if (num >= 13 && num <= 24) {
          return _KeyMapping(0x7C + (num - 13), false);
        }
      }
    }

    // Special keys
    switch (k) {
      case 'enter':
      case 'return':
        return const _KeyMapping(0x0D, false);
      case 'esc':
      case 'escape':
        return const _KeyMapping(0x1B, false);
      case 'tab':
        return const _KeyMapping(0x09, false);
      case 'space':
        return const _KeyMapping(0x20, false);
      case 'backspace':
        return const _KeyMapping(0x08, false);
      case 'delete':
      case 'del':
        return const _KeyMapping(0x2E, true);
      case 'insert':
        return const _KeyMapping(0x2D, true);
      case 'home':
        return const _KeyMapping(0x24, true);
      case 'end':
        return const _KeyMapping(0x23, true);
      case 'pageup':
      case 'pgup':
        return const _KeyMapping(0x21, true);
      case 'pagedown':
      case 'pgdn':
        return const _KeyMapping(0x22, true);
      case 'up':
        return const _KeyMapping(0x26, true);
      case 'down':
        return const _KeyMapping(0x28, true);
      case 'left':
        return const _KeyMapping(0x25, true);
      case 'right':
        return const _KeyMapping(0x27, true);
      case 'printscreen':
      case 'prtscr':
      case 'snapshot':
        return const _KeyMapping(0x2C, true);
      default:
        return null;
    }
  }

  // --- OBS STUDIO SMART CONTROLLER & AUTODISCOVERY ---

  /// Locates OBS Studio binary on the system.
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

  /// Checks if OBS process is currently active.
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

  /// Controls OBS: automatically finds and launches OBS if not running,
  /// or triggers hotkeys/commands if running.
  static Future<bool> _executeObs(String obsCommand, Map<String, dynamic> params) async {
    final cmd = obsCommand.toLowerCase().trim();
    final running = await isObsRunning();

    if (!running) {
      // Find and launch OBS Studio with proper working directory
      final obsPath = findObsPath();
      if (obsPath != null) {
        final obsFile = File(obsPath);
        final launchArgs = <String>[];

        if (cmd == 'stream_toggle' || cmd == 'start_streaming') {
          launchArgs.add('--startstreaming');
        } else if (cmd == 'record_toggle' || cmd == 'start_recording') {
          launchArgs.add('--startrecording');
        } else if (cmd == 'camera_toggle' || cmd == 'virtualcam_toggle') {
          launchArgs.add('--startvirtualcam');
        } else if (cmd == 'replay_save' || cmd == 'replay_toggle') {
          launchArgs.add('--startreplaybuffer');
        }

        await Process.start(
          obsFile.path,
          launchArgs,
          workingDirectory: obsFile.parent.path,
          mode: ProcessStartMode.detached,
        );
        return true;
      }
    }

    // If OBS is already running or being toggled, trigger configured action/hotkey
    switch (cmd) {
      case 'stream_toggle':
      case 'start_streaming':
        // Standard Stream Deck hotkey for OBS stream toggle
        return _executeHotkey(params['hotkey'] ?? 'ctrl+shift+f13');

      case 'record_toggle':
      case 'start_recording':
        // Standard Stream Deck hotkey for OBS record toggle
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
        final obsPath = findObsPath();
        if (obsPath != null) {
          final obsFile = File(obsPath);
          await Process.start(
            obsFile.path,
            [],
            workingDirectory: obsFile.parent.path,
            mode: ProcessStartMode.detached,
          );
          return true;
        }
        return false;
    }
  }

  // --- SMART APPLICATION LAUNCHER ---

  /// Launches an application with automatic binary discovery on Windows.
  static Future<bool> _launchApp(String appNameOrPath, [List<String>? args]) async {
    final clean = appNameOrPath.toLowerCase().trim();

    // 0. UWP / Built-in Windows Tools (instant foreground launch)
    if (clean == 'calc' || clean == 'calculator') {
      final res = await Process.run('cmd', ['/c', 'start', '', 'calc:']);
      return res.exitCode == 0;
    }

    if (clean == 'taskmgr' || clean == 'taskmgr.exe' || clean == 'task manager') {
      final res = await Process.run('cmd', ['/c', 'start', '', 'taskmgr']);
      return res.exitCode == 0;
    }

    if (clean == 'notepad' || clean == 'notepad.exe') {
      final res = await Process.run('cmd', ['/c', 'start', '', 'notepad']);
      return res.exitCode == 0;
    }

    if (clean == 'powershell' || clean == 'terminal' || clean == 'wt') {
      final res = await Process.run('cmd', ['/c', 'start', '', 'powershell']);
      return res.exitCode == 0;
    }

    // 1. Check OBS Studio
    if (clean.contains('obs')) {
      final obsPath = findObsPath();
      if (obsPath != null) {
        final obsFile = File(obsPath);
        await Process.start(
          obsFile.path,
          args ?? [],
          workingDirectory: obsFile.parent.path,
          mode: ProcessStartMode.detached,
        );
        return true;
      }
      final res = await Process.run('cmd', ['/c', 'start', '', 'obs']);
      if (res.exitCode == 0) return true;
    }

    // 2. Check Discord
    if (clean.contains('discord')) {
      final localApp = Platform.environment['LOCALAPPDATA'];
      if (localApp != null) {
        final discordUpdater = File('$localApp\\Discord\\Update.exe');
        if (discordUpdater.existsSync()) {
          await Process.start(
            discordUpdater.path,
            ['--processStart', 'Discord.exe'],
            mode: ProcessStartMode.detached,
          );
          return true;
        }
      }
      final res = await Process.run('cmd', ['/c', 'start', '', 'discord:']);
      if (res.exitCode == 0) return true;
    }

    // 3. Check Google Chrome
    if (clean.contains('chrome')) {
      final chromePaths = [
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
        if (Platform.environment['LOCALAPPDATA'] != null)
          '${Platform.environment['LOCALAPPDATA']}\\Google\\Chrome\\Application\\chrome.exe',
      ];
      for (final p in chromePaths) {
        if (File(p).existsSync()) {
          await Process.start(p, args ?? [], mode: ProcessStartMode.detached);
          return true;
        }
      }
      final res = await Process.run('cmd', ['/c', 'start', '', 'chrome']);
      if (res.exitCode == 0) return true;
    }

    // 4. Check Spotify
    if (clean.contains('spotify')) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final spotifyExe = File('$appData\\Spotify\\Spotify.exe');
        if (spotifyExe.existsSync()) {
          await Process.start(spotifyExe.path, args ?? [], mode: ProcessStartMode.detached);
          return true;
        }
      }
      // Fallback to Spotify URI protocol
      final res = await Process.run('cmd', ['/c', 'start', '', 'spotify:']);
      return res.exitCode == 0;
    }

    // 5. Check VS Code
    if (clean.contains('code') || clean.contains('vscode')) {
      final localApp = Platform.environment['LOCALAPPDATA'];
      final vsCodePaths = [
        if (localApp != null) '$localApp\\Programs\\Microsoft VS Code\\Code.exe',
        r'C:\Program Files\Microsoft VS Code\Code.exe',
      ];
      for (final p in vsCodePaths) {
        if (File(p).existsSync()) {
          await Process.start(p, args ?? [], mode: ProcessStartMode.detached);
          return true;
        }
      }
      final res = await Process.run('cmd', ['/c', 'start', '', 'code']);
      if (res.exitCode == 0) return true;
    }

    // 6. Generic App / Windows System Tool
    final res = await Process.run('cmd', ['/c', 'start', '', appNameOrPath]);
    return res.exitCode == 0;
  }

  /// Opens a URL in the user's default browser.
  static Future<bool> _openUrl(String url) async {
    var finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final res = await Process.run('cmd', ['/c', 'start', '', finalUrl]);
    return res.exitCode == 0;
  }

  /// Runs a custom script or command line.
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
  final bool isExtended;
  const _KeyMapping(this.key, this.isExtended);
}
