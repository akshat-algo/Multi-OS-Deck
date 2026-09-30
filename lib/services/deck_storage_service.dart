import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck_action.dart';
import '../models/deck_button.dart';
import '../models/deck_page.dart';

/// Handles persistence of Stream Deck profiles, custom layouts, and server history.
class DeckStorageService extends ChangeNotifier {
  static const String _keyProfiles = 'stream_deck_profiles';
  static const String _keyActiveProfile = 'stream_deck_active_profile';
  static const String _keyRecentIps = 'stream_deck_recent_ips';
  static const String _keyLastConnectedIp = 'stream_deck_last_ip';
  static const String _keyTargetHostName = 'stream_deck_target_hostname';

  List<DeckProfile> _profiles = [];
  int _activeProfileIndex = 0;
  List<String> _recentIps = [];
  String _lastConnectedIp = '';
  String _targetHostName = '';

  List<DeckProfile> get profiles => List.unmodifiable(_profiles);
  DeckProfile get activeProfile =>
      _profiles.isNotEmpty ? _profiles[_activeProfileIndex] : _createDefaultControlsProfile();
  List<String> get recentIps => List.unmodifiable(_recentIps);
  String get lastConnectedIp => _lastConnectedIp;
  String get targetHostName => _targetHostName;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load recent IPs & Target HostName
    _recentIps = prefs.getStringList(_keyRecentIps) ?? [];
    _lastConnectedIp = prefs.getString(_keyLastConnectedIp) ?? '';
    _targetHostName = prefs.getString(_keyTargetHostName) ?? '';

    // Load Profiles
    final rawProfiles = prefs.getString(_keyProfiles);
    if (rawProfiles != null && rawProfiles.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProfiles) as List;
        _profiles = decoded
            .map((p) => DeckProfile.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
      } catch (e) {
        debugPrint('[Storage] Error loading saved profiles: $e');
      }
    }

    if (_profiles.isEmpty) {
      _profiles = [
        _createDefaultControlsProfile(),
        _createDefaultStreamingProfile(),
        _createDefaultProductivityProfile(),
        _createDefaultSystemProfile(),
        _createDefaultMacroProfile(),
      ];
      await _saveProfiles();
    }

    final activeIndex = prefs.getInt(_keyActiveProfile) ?? 0;
    _activeProfileIndex = activeIndex.clamp(0, _profiles.length - 1);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _profiles = [
      _createDefaultControlsProfile(),
      _createDefaultStreamingProfile(),
      _createDefaultProductivityProfile(),
      _createDefaultSystemProfile(),
      _createDefaultMacroProfile(),
    ];
    _activeProfileIndex = 0;
    await _saveProfiles();
    await _persistActiveProfileIndex();
    notifyListeners();
  }

  Future<void> saveLastConnectedIp(String ip) async {
    if (ip.isEmpty) return;
    _lastConnectedIp = ip;
    if (!_recentIps.contains(ip)) {
      _recentIps.insert(0, ip);
      if (_recentIps.length > 5) _recentIps = _recentIps.sublist(0, 5);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastConnectedIp, ip);
    await prefs.setStringList(_keyRecentIps, _recentIps);
    notifyListeners();
  }

  Future<void> saveTargetHostName(String name) async {
    _targetHostName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTargetHostName, _targetHostName);
    notifyListeners();
  }

  void switchProfile(int index) {
    if (index >= 0 && index < _profiles.length) {
      _activeProfileIndex = index;
      _persistActiveProfileIndex();
      notifyListeners();
    }
  }

  void switchPage(int pageIndex) {
    final cur = activeProfile;
    if (pageIndex >= 0 && pageIndex < cur.pages.length) {
      _profiles[_activeProfileIndex] = cur.copyWith(activePageIndex: pageIndex);
      _saveProfiles();
      notifyListeners();
    }
  }

  void addProfile(String name) {
    final newProfile = DeckProfile(
      id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      pages: [
        const DeckPage(
          id: 'page_1',
          name: 'Main Page',
          rows: 3,
          columns: 5,
          buttons: {},
        ),
      ],
    );
    _profiles.add(newProfile);
    _activeProfileIndex = _profiles.length - 1;
    _saveProfiles();
    _persistActiveProfileIndex();
    notifyListeners();
  }

  void deleteProfile(int index) {
    if (_profiles.length <= 1) return;
    _profiles.removeAt(index);
    if (_activeProfileIndex >= _profiles.length) {
      _activeProfileIndex = _profiles.length - 1;
    }
    _saveProfiles();
    _persistActiveProfileIndex();
    notifyListeners();
  }

  void updateButton(int pageIndex, int slotIndex, DeckButton button) {
    final curProfile = activeProfile;
    if (pageIndex < 0 || pageIndex >= curProfile.pages.length) return;

    final targetPage = curProfile.pages[pageIndex];
    final updatedButtons = Map<int, DeckButton>.from(targetPage.buttons);
    updatedButtons[slotIndex] = button;

    final updatedPages = List<DeckPage>.from(curProfile.pages);
    updatedPages[pageIndex] = targetPage.copyWith(buttons: updatedButtons);

    _profiles[_activeProfileIndex] = curProfile.copyWith(pages: updatedPages);
    _saveProfiles();
    notifyListeners();
  }

  void deleteButton(int pageIndex, int slotIndex) {
    final curProfile = activeProfile;
    if (pageIndex < 0 || pageIndex >= curProfile.pages.length) return;

    final targetPage = curProfile.pages[pageIndex];
    final updatedButtons = Map<int, DeckButton>.from(targetPage.buttons)..remove(slotIndex);

    final updatedPages = List<DeckPage>.from(curProfile.pages);
    updatedPages[pageIndex] = targetPage.copyWith(buttons: updatedButtons);

    _profiles[_activeProfileIndex] = curProfile.copyWith(pages: updatedPages);
    _saveProfiles();
    notifyListeners();
  }

  void toggleButtonState(int pageIndex, int slotIndex) {
    final curProfile = activeProfile;
    if (pageIndex < 0 || pageIndex >= curProfile.pages.length) return;

    final targetPage = curProfile.pages[pageIndex];
    final btn = targetPage.buttons[slotIndex];
    if (btn != null && btn.isToggle) {
      final updated = btn.copyWith(isActive: !btn.isActive);
      updateButton(pageIndex, slotIndex, updated);
    }
  }

  Future<void> _persistActiveProfileIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyActiveProfile, _activeProfileIndex);
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_keyProfiles, jsonStr);
  }

  // --- Factory Default Profiles ---

  static DeckProfile _createDefaultControlsProfile() {
    final buttons = <int, DeckButton>{
      0: const DeckButton(
        id: 'btn_mic',
        title: 'MIC MUTE',
        subtitle: 'Toggle',
        iconKey: 'mic',
        backgroundColorHex: '#161922',
        activeColorHex: '#10B981',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.hotkey, command: 'ctrl+shift+m'),
        isToggle: true,
      ),
      1: const DeckButton(
        id: 'btn_discord',
        title: 'DEAFEN',
        subtitle: 'Discord',
        iconKey: 'discord',
        backgroundColorHex: '#161922',
        activeColorHex: '#8B5CF6',
        glowColorHex: '#8B5CF6',
        action: DeckAction(type: DeckActionType.hotkey, command: 'ctrl+shift+d'),
        isToggle: true,
      ),
      2: const DeckButton(
        id: 'btn_playpause',
        title: 'PLAY/PAUSE',
        subtitle: 'Media',
        iconKey: 'play',
        backgroundColorHex: '#161922',
        activeColorHex: '#10B981',
        glowColorHex: '#10B981',
        action: DeckAction(type: DeckActionType.media, command: 'play_pause'),
      ),
      3: const DeckButton(
        id: 'btn_next',
        title: 'NEXT',
        subtitle: 'Track',
        iconKey: 'next',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.media, command: 'next'),
      ),
      4: const DeckButton(
        id: 'btn_snip',
        title: 'SNIP',
        subtitle: 'Screenshot',
        iconKey: 'snippet',
        backgroundColorHex: '#161922',
        activeColorHex: '#FB923C',
        glowColorHex: '#FB923C',
        action: DeckAction(type: DeckActionType.hotkey, command: 'win+shift+s'),
      ),
      5: const DeckButton(
        id: 'btn_volup',
        title: 'VOL +',
        subtitle: 'Audio',
        iconKey: 'volume_up',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.media, command: 'volume_up'),
        isRepeatable: true,
      ),
      6: const DeckButton(
        id: 'btn_voldown',
        title: 'VOL -',
        subtitle: 'Audio',
        iconKey: 'volume_down',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.media, command: 'volume_down'),
        isRepeatable: true,
      ),
      7: const DeckButton(
        id: 'btn_mute',
        title: 'MUTE',
        subtitle: 'Master',
        iconKey: 'volume_mute',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.media, command: 'volume_mute'),
      ),
      8: const DeckButton(
        id: 'btn_spotify',
        title: 'SPOTIFY',
        subtitle: 'Music',
        iconKey: 'spotify',
        backgroundColorHex: '#161922',
        activeColorHex: '#10B981',
        glowColorHex: '#10B981',
        action: DeckAction(type: DeckActionType.launchApp, command: 'spotify'),
      ),
      9: const DeckButton(
        id: 'btn_desktop',
        title: 'DESKTOP',
        subtitle: 'Win+D',
        iconKey: 'desktop',
        backgroundColorHex: '#161922',
        activeColorHex: '#3B82F6',
        glowColorHex: '#3B82F6',
        action: DeckAction(type: DeckActionType.window, command: 'show_desktop'),
      ),
      10: const DeckButton(
        id: 'btn_cpu',
        title: 'CPU',
        subtitle: 'Load',
        iconKey: 'cpu',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.systemMonitor, command: 'taskmgr'),
        telemetryType: 'cpu',
      ),
      11: const DeckButton(
        id: 'btn_ram',
        title: 'RAM',
        subtitle: 'Usage',
        iconKey: 'ram',
        backgroundColorHex: '#161922',
        activeColorHex: '#A855F7',
        glowColorHex: '#A855F7',
        action: DeckAction(type: DeckActionType.systemMonitor, command: 'taskmgr'),
        telemetryType: 'ram',
      ),
      12: const DeckButton(
        id: 'btn_chrome',
        title: 'CHROME',
        subtitle: 'Browser',
        iconKey: 'chrome',
        backgroundColorHex: '#161922',
        activeColorHex: '#FB923C',
        glowColorHex: '#FB923C',
        action: DeckAction(type: DeckActionType.launchApp, command: 'chrome'),
      ),
      13: const DeckButton(
        id: 'btn_close',
        title: 'CLOSE APP',
        subtitle: 'Alt+F4',
        iconKey: 'back',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.window, command: 'close_window'),
      ),
      14: const DeckButton(
        id: 'btn_lock',
        title: 'LOCK PC',
        subtitle: 'Win+L',
        iconKey: 'lock',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.hotkey, command: 'lock'),
      ),
    };

    return DeckProfile(
      id: 'profile_controls',
      name: '⚡ Quick Controls',
      pages: [
        DeckPage(
          id: 'page_main',
          name: 'Main Deck',
          rows: 3,
          columns: 5,
          buttons: buttons,
        ),
      ],
    );
  }

  static DeckProfile _createDefaultStreamingProfile() {
    final buttons = <int, DeckButton>{
      0: const DeckButton(
        id: 'btn_stream',
        title: 'STREAM',
        subtitle: 'OBS Live',
        iconKey: 'stream',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.obs, command: 'stream_toggle'),
        isToggle: true,
      ),
      1: const DeckButton(
        id: 'btn_record',
        title: 'RECORD',
        subtitle: 'Capture',
        iconKey: 'record',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.obs, command: 'record_toggle'),
        isToggle: true,
      ),
      2: const DeckButton(
        id: 'btn_camera',
        title: 'CAMERA',
        subtitle: 'Virtual',
        iconKey: 'camera',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.obs, command: 'camera_toggle'),
        isToggle: true,
      ),
      3: const DeckButton(
        id: 'btn_clip',
        title: 'CLIP THAT',
        subtitle: 'Replay Buffer',
        iconKey: 'clip',
        backgroundColorHex: '#161922',
        activeColorHex: '#FB923C',
        glowColorHex: '#FB923C',
        action: DeckAction(type: DeckActionType.obs, command: 'replay_save'),
      ),
      4: const DeckButton(
        id: 'btn_launch_obs',
        title: 'LAUNCH OBS',
        subtitle: 'Studio App',
        iconKey: 'obs',
        backgroundColorHex: '#161922',
        activeColorHex: '#8B5CF6',
        glowColorHex: '#8B5CF6',
        action: DeckAction(type: DeckActionType.obs, command: 'launch_obs'),
      ),
      5: const DeckButton(
        id: 'btn_scene_game',
        title: 'GAME SCENE',
        subtitle: 'OBS 1',
        iconKey: 'gamepad',
        backgroundColorHex: '#161922',
        activeColorHex: '#8B5CF6',
        glowColorHex: '#8B5CF6',
        action: DeckAction(type: DeckActionType.obs, command: 'scene_gaming'),
      ),
      6: const DeckButton(
        id: 'btn_scene_chat',
        title: 'CHATTING',
        subtitle: 'OBS 2',
        iconKey: 'chat',
        backgroundColorHex: '#161922',
        activeColorHex: '#FBBF24',
        glowColorHex: '#FBBF24',
        action: DeckAction(type: DeckActionType.obs, command: 'scene_chatting'),
      ),
      7: const DeckButton(
        id: 'btn_scene_brb',
        title: 'BRB SCENE',
        subtitle: 'OBS 3',
        iconKey: 'timer',
        backgroundColorHex: '#161922',
        activeColorHex: '#3B82F6',
        glowColorHex: '#3B82F6',
        action: DeckAction(type: DeckActionType.obs, command: 'scene_brb'),
      ),
      8: const DeckButton(
        id: 'btn_screen',
        title: 'SCREEN',
        subtitle: 'Share',
        iconKey: 'screen_share',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.hotkey, command: 'ctrl+shift+s'),
      ),
      9: const DeckButton(
        id: 'btn_mic',
        title: 'MIC MUTE',
        subtitle: 'Toggle',
        iconKey: 'mic',
        backgroundColorHex: '#161922',
        activeColorHex: '#10B981',
        glowColorHex: '#10B981',
        action: DeckAction(type: DeckActionType.hotkey, command: 'ctrl+shift+m'),
        isToggle: true,
      ),
      10: const DeckButton(
        id: 'btn_deafen',
        title: 'DEAFEN',
        subtitle: 'Discord',
        iconKey: 'discord',
        backgroundColorHex: '#161922',
        activeColorHex: '#8B5CF6',
        glowColorHex: '#8B5CF6',
        action: DeckAction(type: DeckActionType.hotkey, command: 'ctrl+shift+d'),
        isToggle: true,
      ),
      11: const DeckButton(
        id: 'btn_volup',
        title: 'VOL +',
        subtitle: 'Audio',
        iconKey: 'volume_up',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.media, command: 'volume_up'),
        isRepeatable: true,
      ),
      12: const DeckButton(
        id: 'btn_voldown',
        title: 'VOL -',
        subtitle: 'Audio',
        iconKey: 'volume_down',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.media, command: 'volume_down'),
        isRepeatable: true,
      ),
      13: const DeckButton(
        id: 'btn_mute',
        title: 'MUTE',
        subtitle: 'Master',
        iconKey: 'volume_mute',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.media, command: 'volume_mute'),
      ),
      14: const DeckButton(
        id: 'btn_desktop',
        title: 'DESKTOP',
        subtitle: 'Win+D',
        iconKey: 'desktop',
        backgroundColorHex: '#161922',
        activeColorHex: '#3B82F6',
        glowColorHex: '#3B82F6',
        action: DeckAction(type: DeckActionType.window, command: 'show_desktop'),
      ),
    };

    return DeckProfile(
      id: 'profile_stream',
      name: '🎥 OBS & Streaming',
      pages: [
        DeckPage(
          id: 'page_stream_main',
          name: 'OBS Control',
          rows: 3,
          columns: 5,
          buttons: buttons,
        ),
      ],
    );
  }

  static DeckProfile _createDefaultProductivityProfile() {
    final buttons = <int, DeckButton>{
      0: const DeckButton(
        id: 'btn_vscode',
        title: 'VS CODE',
        subtitle: 'Editor',
        iconKey: 'code',
        backgroundColorHex: '#161922',
        activeColorHex: '#3B82F6',
        glowColorHex: '#3B82F6',
        action: DeckAction(type: DeckActionType.launchApp, command: 'code'),
      ),
      1: const DeckButton(
        id: 'btn_term',
        title: 'TERMINAL',
        subtitle: 'PowerShell',
        iconKey: 'terminal',
        backgroundColorHex: '#161922',
        activeColorHex: '#10B981',
        glowColorHex: '#10B981',
        action: DeckAction(type: DeckActionType.launchApp, command: 'powershell'),
      ),
      2: const DeckButton(
        id: 'btn_chrome',
        title: 'CHROME',
        subtitle: 'Browser',
        iconKey: 'chrome',
        backgroundColorHex: '#161922',
        activeColorHex: '#FB923C',
        glowColorHex: '#FB923C',
        action: DeckAction(type: DeckActionType.launchApp, command: 'chrome'),
      ),
      3: const DeckButton(
        id: 'btn_copy',
        title: 'COPY',
        subtitle: 'Ctrl+C',
        iconKey: 'copy',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.hotkey, command: 'ctrl+c'),
      ),
      4: const DeckButton(
        id: 'btn_paste',
        title: 'PASTE',
        subtitle: 'Ctrl+V',
        iconKey: 'paste',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.hotkey, command: 'ctrl+v'),
      ),
      5: const DeckButton(
        id: 'btn_snip',
        title: 'SNIP',
        subtitle: 'Screen Tool',
        iconKey: 'snippet',
        backgroundColorHex: '#161922',
        activeColorHex: '#FB923C',
        glowColorHex: '#FB923C',
        action: DeckAction(type: DeckActionType.hotkey, command: 'win+shift+s'),
      ),
      6: const DeckButton(
        id: 'btn_calc',
        title: 'CALC',
        subtitle: 'Tools',
        iconKey: 'calculator',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.launchApp, command: 'calc'),
      ),
      7: const DeckButton(
        id: 'btn_taskmgr',
        title: 'TASK MGR',
        subtitle: 'System',
        iconKey: 'taskmgr',
        backgroundColorHex: '#161922',
        activeColorHex: '#8B5CF6',
        glowColorHex: '#8B5CF6',
        action: DeckAction(type: DeckActionType.launchApp, command: 'taskmgr'),
      ),
      8: const DeckButton(
        id: 'btn_newtab',
        title: 'NEW TAB',
        subtitle: 'Ctrl+T',
        iconKey: 'chrome',
        backgroundColorHex: '#161922',
        activeColorHex: '#FB923C',
        glowColorHex: '#FB923C',
        action: DeckAction(type: DeckActionType.browser, command: 'new_tab'),
      ),
      9: const DeckButton(
        id: 'btn_closetab',
        title: 'CLOSE TAB',
        subtitle: 'Ctrl+W',
        iconKey: 'back',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.browser, command: 'close_tab'),
      ),
      10: const DeckButton(
        id: 'btn_refresh',
        title: 'REFRESH',
        subtitle: 'F5',
        iconKey: 'refresh',
        backgroundColorHex: '#161922',
        activeColorHex: '#10B981',
        glowColorHex: '#10B981',
        action: DeckAction(type: DeckActionType.browser, command: 'refresh'),
      ),
      11: const DeckButton(
        id: 'btn_snapl',
        title: 'SNAP L',
        subtitle: 'Win+Left',
        iconKey: 'snippet',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.window, command: 'snap_left'),
      ),
      12: const DeckButton(
        id: 'btn_snapr',
        title: 'SNAP R',
        subtitle: 'Win+Right',
        iconKey: 'snippet',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.window, command: 'snap_right'),
      ),
      13: const DeckButton(
        id: 'btn_desktop',
        title: 'DESKTOP',
        subtitle: 'Win+D',
        iconKey: 'desktop',
        backgroundColorHex: '#161922',
        activeColorHex: '#3B82F6',
        glowColorHex: '#3B82F6',
        action: DeckAction(type: DeckActionType.window, command: 'show_desktop'),
      ),
      14: const DeckButton(
        id: 'btn_lock',
        title: 'LOCK PC',
        subtitle: 'Win+L',
        iconKey: 'lock',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.hotkey, command: 'lock'),
      ),
    };

    return DeckProfile(
      id: 'profile_prod',
      name: '💻 Dev & Productivity',
      pages: [
        DeckPage(
          id: 'page_prod',
          name: 'Quick Access',
          rows: 3,
          columns: 5,
          buttons: buttons,
        ),
      ],
    );
  }

  static DeckProfile _createDefaultSystemProfile() {
    final buttons = <int, DeckButton>{
      0: const DeckButton(
        id: 'btn_cpu',
        title: 'CPU LOAD',
        subtitle: 'Live %',
        iconKey: 'cpu',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction(type: DeckActionType.systemMonitor, command: 'taskmgr'),
        telemetryType: 'cpu',
      ),
      1: const DeckButton(
        id: 'btn_ram',
        title: 'RAM USAGE',
        subtitle: 'Live %',
        iconKey: 'ram',
        backgroundColorHex: '#161922',
        activeColorHex: '#8B5CF6',
        glowColorHex: '#8B5CF6',
        action: DeckAction(type: DeckActionType.systemMonitor, command: 'taskmgr'),
        telemetryType: 'ram',
      ),
      2: const DeckButton(
        id: 'btn_taskmgr',
        title: 'TASK MGR',
        subtitle: 'Manager',
        iconKey: 'taskmgr',
        backgroundColorHex: '#161922',
        activeColorHex: '#10B981',
        glowColorHex: '#10B981',
        action: DeckAction(type: DeckActionType.launchApp, command: 'taskmgr'),
      ),
      3: const DeckButton(
        id: 'btn_close',
        title: 'CLOSE APP',
        subtitle: 'Alt+F4',
        iconKey: 'back',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.window, command: 'close_window'),
      ),
      4: const DeckButton(
        id: 'btn_lock',
        title: 'LOCK PC',
        subtitle: 'Win+L',
        iconKey: 'lock',
        backgroundColorHex: '#161922',
        activeColorHex: '#F43F5E',
        glowColorHex: '#F43F5E',
        action: DeckAction(type: DeckActionType.hotkey, command: 'lock'),
      ),
    };

    return DeckProfile(
      id: 'profile_sys',
      name: '📊 System Health',
      pages: [
        DeckPage(
          id: 'page_sys',
          name: 'Hardware Stats',
          rows: 3,
          columns: 5,
          buttons: buttons,
        ),
      ],
    );
  }

  static DeckProfile _createDefaultMacroProfile() {
    final buttons = <int, DeckButton>{};
    for (int i = 0; i < 12; i++) {
      final keyNum = i + 13;
      buttons[i] = DeckButton(
        id: 'btn_f$keyNum',
        title: 'F$keyNum',
        subtitle: 'Stream Macro',
        iconKey: 'bolt',
        backgroundColorHex: '#161922',
        activeColorHex: '#00F0FF',
        glowColorHex: '#00F0FF',
        action: DeckAction.streamDeckKey('F$keyNum'),
      );
    }

    return DeckProfile(
      id: 'profile_macro',
      name: '⚡ Stream Deck Macros (F13–F24)',
      pages: [
        DeckPage(
          id: 'page_macro',
          name: 'F13-F24 Keys',
          rows: 3,
          columns: 4,
          buttons: buttons,
        ),
      ],
    );
  }
}
