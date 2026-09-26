import 'package:flutter/material.dart';

/// Centralized catalog of icons available for Stream Deck buttons.
class DeckIcons {
  static const Map<String, IconData> all = {
    // Media & Audio
    'volume_up': Icons.volume_up_rounded,
    'volume_down': Icons.volume_down_rounded,
    'volume_mute': Icons.volume_off_rounded,
    'play': Icons.play_arrow_rounded,
    'pause': Icons.pause_rounded,
    'next': Icons.skip_next_rounded,
    'prev': Icons.skip_previous_rounded,
    'mic': Icons.mic_rounded,
    'mic_off': Icons.mic_off_rounded,
    'headset': Icons.headset_rounded,
    'music': Icons.music_note_rounded,

    // Streaming & Recording
    'obs': Icons.videocam_rounded,
    'stream': Icons.sensors_rounded,
    'record': Icons.radio_button_checked_rounded,
    'camera': Icons.camera_alt_rounded,
    'camera_off': Icons.videocam_off_rounded,
    'screen_share': Icons.screen_share_rounded,
    'switch_scene': Icons.movie_filter_rounded,
    'chat': Icons.chat_bubble_outline_rounded,
    'clip': Icons.movie_creation_rounded,

    // Apps & Gaming
    'gamepad': Icons.sports_esports_rounded,
    'discord': Icons.forum_rounded,
    'spotify': Icons.graphic_eq_rounded,
    'chrome': Icons.public_rounded,
    'code': Icons.code_rounded,
    'terminal': Icons.terminal_rounded,
    'steam': Icons.videogame_asset_rounded,
    'youtube': Icons.smart_display_rounded,
    'twitch': Icons.live_tv_rounded,

    // System & Telemetry
    'cpu': Icons.memory_rounded,
    'ram': Icons.analytics_rounded,
    'desktop': Icons.desktop_windows_rounded,
    'taskmgr': Icons.speed_rounded,
    'lock': Icons.lock_rounded,
    'power': Icons.power_settings_new_rounded,
    'restart': Icons.restart_alt_rounded,
    'settings': Icons.settings_rounded,
    'keyboard': Icons.keyboard_rounded,
    'mouse': Icons.mouse_rounded,
    'brightness': Icons.brightness_6_rounded,
    'timer': Icons.timer_rounded,
    'lightbulb': Icons.lightbulb_outline_rounded,

    // Navigation & General
    'folder': Icons.folder_rounded,
    'folder_open': Icons.folder_open_rounded,
    'back': Icons.arrow_back_rounded,
    'home': Icons.home_rounded,
    'link': Icons.link_rounded,
    'star': Icons.star_rounded,
    'bolt': Icons.bolt_rounded,
    'grid': Icons.grid_view_rounded,
    'calculator': Icons.calculate_rounded,
    'snippet': Icons.crop_rounded,
    'copy': Icons.content_copy_rounded,
    'paste': Icons.content_paste_rounded,
    'refresh': Icons.refresh_rounded,
    'fullscreen': Icons.fullscreen_rounded,
  };

  static IconData getIcon(String key) {
    return all[key] ?? Icons.touch_app_rounded;
  }

  static List<String> get categorizedKeys => all.keys.toList();
}
