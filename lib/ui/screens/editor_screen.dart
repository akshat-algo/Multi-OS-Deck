import 'package:flutter/material.dart';
import '../../models/deck_action.dart';
import '../../models/deck_button.dart';
import '../theme/deck_icons.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_button_widget.dart';

/// Modern thumb-friendly bottom sheet for customizing a Stream Deck button.
class ButtonEditorSheet extends StatefulWidget {
  final DeckButton? initialButton;
  final int slotIndex;
  final Function(DeckButton) onSave;
  final VoidCallback? onDelete;

  const ButtonEditorSheet({
    super.key,
    this.initialButton,
    required this.slotIndex,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ButtonEditorSheet> createState() => _ButtonEditorSheetState();
}

class _ButtonEditorSheetState extends State<ButtonEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _commandController;

  late String _selectedIcon;
  late DeckActionType _selectedActionType;
  late String _selectedGlowColor;
  late String _selectedActiveColor;
  late bool _isToggle;
  String? _selectedTelemetryType;

  final List<String> _colorPalette = [
    '#00F0FF', // Cyan
    '#10B981', // Emerald
    '#F43F5E', // Crimson
    '#FB923C', // Orange
    '#8B5CF6', // Violet
    '#FBBF24', // Amber Gold
    '#3B82F6', // Electric Blue
    '#FFFFFF', // Pure White
  ];

  @override
  void initState() {
    super.initState();
    final btn = widget.initialButton;

    _titleController = TextEditingController(text: btn?.title ?? 'KEY ${widget.slotIndex + 1}');
    _subtitleController = TextEditingController(text: btn?.subtitle ?? '');
    _commandController = TextEditingController(text: btn?.action.command ?? '');

    _selectedIcon = btn?.iconKey ?? 'bolt';
    _selectedActionType = btn?.action.type ?? DeckActionType.hotkey;
    _selectedGlowColor = btn?.glowColorHex ?? '#00F0FF';
    _selectedActiveColor = btn?.activeColorHex ?? '#10B981';
    _isToggle = btn?.isToggle ?? false;
    _selectedTelemetryType = btn?.telemetryType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  DeckButton _buildPreviewButton() {
    return DeckButton(
      id: widget.initialButton?.id ?? 'btn_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.isEmpty ? 'KEY' : _titleController.text,
      subtitle: _subtitleController.text.isEmpty ? null : _subtitleController.text,
      iconKey: _selectedIcon,
      glowColorHex: _selectedGlowColor,
      activeColorHex: _selectedActiveColor,
      backgroundColorHex: '#161922',
      isToggle: _isToggle,
      isActive: false,
      telemetryType: _selectedTelemetryType,
      telemetryValue: _selectedTelemetryType != null ? '42%' : null,
      action: DeckAction(
        type: _selectedActionType,
        command: _commandController.text,
      ),
    );
  }

  void _applyQuickPreset({
    required String title,
    String? subtitle,
    required String icon,
    required String command,
    String? colorHex,
    bool isToggle = false,
  }) {
    setState(() {
      _titleController.text = title;
      if (subtitle != null) _subtitleController.text = subtitle;
      _selectedIcon = icon;
      _commandController.text = command;
      if (colorHex != null) {
        _selectedGlowColor = colorHex;
        _selectedActiveColor = colorHex;
      }
      _isToggle = isToggle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreviewButton();
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: DeckTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: DeckTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with Live Preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: DeckButtonWidget(
                    slotIndex: widget.slotIndex,
                    button: preview,
                    telemetryValue: 42,
                    isEditMode: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customize Key ${widget.slotIndex + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: DeckTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Configure action, hotkeys & appearance',
                        style: TextStyle(
                          fontSize: 12,
                          color: DeckTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20, color: DeckTheme.textSecondary),
                ),
              ],
            ),
          ),

          const Divider(color: DeckTheme.border, height: 1),

          // Scrollable Settings
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label & Subtitle Fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 13),
                          decoration: _inputDeco('Title Label', 'e.g. MUTE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _subtitleController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 13),
                          decoration: _inputDeco('Subtitle (optional)', 'e.g. Discord'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Icon Picker
                  const Text(
                    'Icon',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DeckTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: DeckTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DeckTheme.border),
                    ),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemCount: DeckIcons.categorizedKeys.length,
                      itemBuilder: (context, i) {
                        final key = DeckIcons.categorizedKeys[i];
                        final isSelected = key == _selectedIcon;
                        return InkWell(
                          onTap: () => setState(() => _selectedIcon = key),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? DeckTheme.cyan.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: DeckTheme.cyan, width: 1.2)
                                  : null,
                            ),
                            child: Icon(
                              DeckIcons.getIcon(key),
                              color: isSelected
                                  ? DeckTheme.cyan
                                  : DeckTheme.textSecondary,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Category Selector
                  const Text(
                    'Action Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DeckTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<DeckActionType>(
                    initialValue: _selectedActionType,
                    dropdownColor: DeckTheme.card,
                    decoration: _inputDeco('Select Category', ''),
                    items: const [
                      DropdownMenuItem(
                        value: DeckActionType.media,
                        child: Text('🎵 Media & Audio Control'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.obs,
                        child: Text('🎥 OBS Studio (Smart Launch)'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.window,
                        child: Text('🪟 Windows & Screen Control'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.browser,
                        child: Text('🌐 Browser Navigation'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.streamDeckKey,
                        child: Text('⚡ Stream Deck Macro Key (F13–F24)'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.hotkey,
                        child: Text('⌨️ Hotkey Shortcut (No NumLock)'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.launchApp,
                        child: Text('🚀 Launch Windows App'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.systemMonitor,
                        child: Text('📊 Live System Metric'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.openUrl,
                        child: Text('🌐 Open Web URL'),
                      ),
                      DropdownMenuItem(
                        value: DeckActionType.script,
                        child: Text('💻 Custom PowerShell Script'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedActionType = val;
                          if (val == DeckActionType.systemMonitor) {
                            _selectedTelemetryType = 'cpu';
                          } else {
                            _selectedTelemetryType = null;
                          }
                          // Set standard default command for each category
                          if (val == DeckActionType.media) _commandController.text = 'play_pause';
                          if (val == DeckActionType.obs) _commandController.text = 'stream_toggle';
                          if (val == DeckActionType.window) _commandController.text = 'show_desktop';
                          if (val == DeckActionType.browser) _commandController.text = 'new_tab';
                          if (val == DeckActionType.streamDeckKey) _commandController.text = 'F13';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Command / Preset options based on action type
                  _buildActionDetailsField(),

                  const SizedBox(height: 18),

                  // Accent Color Picker
                  const Text(
                    'Backlight Glow',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DeckTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _colorPalette.map((hex) {
                      final isSel = hex == _selectedGlowColor;
                      final color = DeckTheme.fromHex(hex);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedGlowColor = hex;
                            _selectedActiveColor = hex;
                          }),
                          child: Container(
                            height: 30,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Toggle Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Toggle Button',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DeckTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Alternates between ON/OFF states on press',
                      style: TextStyle(fontSize: 11, color: DeckTheme.textMuted),
                    ),
                    value: _isToggle,
                    activeThumbColor: DeckTheme.cyan,
                    onChanged: (val) => setState(() => _isToggle = val),
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: DeckTheme.border, height: 1),

          // Bottom Bar Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                if (widget.initialButton != null && widget.onDelete != null)
                  IconButton(
                    onPressed: () {
                      widget.onDelete?.call();
                      Navigator.of(context).pop();
                    },
                    tooltip: 'Delete Button',
                    icon: const Icon(Icons.delete_outline_rounded, color: DeckTheme.red),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: DeckTheme.textMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final btn = _buildPreviewButton();
                    widget.onSave(btn);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DeckTheme.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Key', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionDetailsField() {
    switch (_selectedActionType) {
      case DeckActionType.media:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _commandController.text.isEmpty ? 'volume_up' : _commandController.text,
              dropdownColor: DeckTheme.card,
              decoration: _inputDeco('Media Command', ''),
              items: const [
                DropdownMenuItem(value: 'volume_up', child: Text('Volume Up (+)')),
                DropdownMenuItem(value: 'volume_down', child: Text('Volume Down (-)')),
                DropdownMenuItem(value: 'volume_mute', child: Text('Toggle Mute')),
                DropdownMenuItem(value: 'play_pause', child: Text('Play / Pause')),
                DropdownMenuItem(value: 'next', child: Text('Next Track')),
                DropdownMenuItem(value: 'prev', child: Text('Previous Track')),
                DropdownMenuItem(value: 'stop', child: Text('Stop')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _commandController.text = val);
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _presetActionChip('Vol +', () => _applyQuickPreset(title: 'VOL +', icon: 'volume_up', command: 'volume_up', colorHex: '#00F0FF')),
                _presetActionChip('Vol -', () => _applyQuickPreset(title: 'VOL -', icon: 'volume_down', command: 'volume_down', colorHex: '#00F0FF')),
                _presetActionChip('Mute', () => _applyQuickPreset(title: 'MUTE', icon: 'volume_mute', command: 'volume_mute', colorHex: '#F43F5E')),
                _presetActionChip('Play/Pause', () => _applyQuickPreset(title: 'PLAY', icon: 'play', command: 'play_pause', colorHex: '#10B981')),
                _presetActionChip('Next', () => _applyQuickPreset(title: 'NEXT', icon: 'next', command: 'next', colorHex: '#00F0FF')),
                _presetActionChip('Prev', () => _applyQuickPreset(title: 'PREV', icon: 'prev', command: 'prev', colorHex: '#00F0FF')),
              ],
            ),
          ],
        );

      case DeckActionType.obs:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _commandController.text.isEmpty ? 'stream_toggle' : _commandController.text,
              dropdownColor: DeckTheme.card,
              decoration: _inputDeco('OBS Command (Auto-Launches if Closed)', ''),
              items: const [
                DropdownMenuItem(value: 'stream_toggle', child: Text('Toggle Stream (Starts OBS if closed)')),
                DropdownMenuItem(value: 'record_toggle', child: Text('Toggle Recording (Starts OBS if closed)')),
                DropdownMenuItem(value: 'camera_toggle', child: Text('Toggle Virtual Camera')),
                DropdownMenuItem(value: 'replay_save', child: Text('Save Replay Buffer (Clip That!)')),
                DropdownMenuItem(value: 'launch_obs', child: Text('Launch OBS Studio')),
                DropdownMenuItem(value: 'scene_gaming', child: Text('Gaming Scene')),
                DropdownMenuItem(value: 'scene_chatting', child: Text('Chatting Scene')),
                DropdownMenuItem(value: 'scene_brb', child: Text('BRB Scene')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _commandController.text = val);
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _presetActionChip('Stream Toggle', () => _applyQuickPreset(title: 'STREAM', subtitle: 'OBS Live', icon: 'stream', command: 'stream_toggle', colorHex: '#F43F5E', isToggle: true)),
                _presetActionChip('Record Toggle', () => _applyQuickPreset(title: 'RECORD', subtitle: 'Capture', icon: 'record', command: 'record_toggle', colorHex: '#F43F5E', isToggle: true)),
                _presetActionChip('Virtual Cam', () => _applyQuickPreset(title: 'CAMERA', subtitle: 'Virtual', icon: 'camera', command: 'camera_toggle', colorHex: '#00F0FF', isToggle: true)),
                _presetActionChip('Clip That', () => _applyQuickPreset(title: 'CLIP', subtitle: 'Replay Buffer', icon: 'clip', command: 'replay_save', colorHex: '#FB923C')),
                _presetActionChip('Launch OBS', () => _applyQuickPreset(title: 'OBS', subtitle: 'Studio', icon: 'obs', command: 'launch_obs', colorHex: '#8B5CF6')),
              ],
            ),
          ],
        );

      case DeckActionType.window:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _commandController.text.isEmpty ? 'show_desktop' : _commandController.text,
              dropdownColor: DeckTheme.card,
              decoration: _inputDeco('Window Action', ''),
              items: const [
                DropdownMenuItem(value: 'show_desktop', child: Text('Toggle Desktop (Win+D)')),
                DropdownMenuItem(value: 'minimize', child: Text('Minimize Window (Win+Down)')),
                DropdownMenuItem(value: 'maximize', child: Text('Maximize Window (Win+Up)')),
                DropdownMenuItem(value: 'snap_left', child: Text('Snap Left (Win+Left)')),
                DropdownMenuItem(value: 'snap_right', child: Text('Snap Right (Win+Right)')),
                DropdownMenuItem(value: 'close_window', child: Text('Close Window (Alt+F4)')),
                DropdownMenuItem(value: 'switch_window', child: Text('Switch Window (Alt+Tab)')),
                DropdownMenuItem(value: 'next_desktop', child: Text('Next Desktop (Ctrl+Win+Right)')),
                DropdownMenuItem(value: 'prev_desktop', child: Text('Prev Desktop (Ctrl+Win+Left)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _commandController.text = val);
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _presetActionChip('Desktop', () => _applyQuickPreset(title: 'DESKTOP', icon: 'desktop', command: 'show_desktop', colorHex: '#3B82F6')),
                _presetActionChip('Close App', () => _applyQuickPreset(title: 'CLOSE', icon: 'back', command: 'close_window', colorHex: '#F43F5E')),
                _presetActionChip('Snap Left', () => _applyQuickPreset(title: 'SNAP L', icon: 'snippet', command: 'snap_left', colorHex: '#00F0FF')),
                _presetActionChip('Snap Right', () => _applyQuickPreset(title: 'SNAP R', icon: 'snippet', command: 'snap_right', colorHex: '#00F0FF')),
                _presetActionChip('Alt+Tab', () => _applyQuickPreset(title: 'SWITCH', icon: 'grid', command: 'switch_window', colorHex: '#8B5CF6')),
              ],
            ),
          ],
        );

      case DeckActionType.browser:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _commandController.text.isEmpty ? 'new_tab' : _commandController.text,
              dropdownColor: DeckTheme.card,
              decoration: _inputDeco('Browser Action', ''),
              items: const [
                DropdownMenuItem(value: 'new_tab', child: Text('New Tab (Ctrl+T)')),
                DropdownMenuItem(value: 'close_tab', child: Text('Close Tab (Ctrl+W)')),
                DropdownMenuItem(value: 'reopen_tab', child: Text('Reopen Closed Tab (Ctrl+Shift+T)')),
                DropdownMenuItem(value: 'refresh', child: Text('Refresh Page (F5)')),
                DropdownMenuItem(value: 'hard_refresh', child: Text('Hard Refresh (Ctrl+F5)')),
                DropdownMenuItem(value: 'devtools', child: Text('Inspect / DevTools (F12)')),
                DropdownMenuItem(value: 'next_tab', child: Text('Next Tab (Ctrl+Tab)')),
                DropdownMenuItem(value: 'prev_tab', child: Text('Previous Tab (Ctrl+Shift+Tab)')),
                DropdownMenuItem(value: 'bookmark', child: Text('Bookmark Page (Ctrl+D)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _commandController.text = val);
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _presetActionChip('New Tab', () => _applyQuickPreset(title: 'NEW TAB', icon: 'chrome', command: 'new_tab', colorHex: '#FB923C')),
                _presetActionChip('Close Tab', () => _applyQuickPreset(title: 'CLOSE TAB', icon: 'back', command: 'close_tab', colorHex: '#F43F5E')),
                _presetActionChip('Refresh', () => _applyQuickPreset(title: 'REFRESH', icon: 'refresh', command: 'refresh', colorHex: '#10B981')),
                _presetActionChip('DevTools', () => _applyQuickPreset(title: 'DEVTOOLS', icon: 'code', command: 'devtools', colorHex: '#00F0FF')),
                _presetActionChip('Reopen Tab', () => _applyQuickPreset(title: 'REOPEN', icon: 'refresh', command: 'reopen_tab', colorHex: '#8B5CF6')),
              ],
            ),
          ],
        );

      case DeckActionType.streamDeckKey:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _commandController,
              onChanged: (_) => setState(() {}),
              decoration: _inputDeco('Macro Key (F13–F24)', 'e.g. F13, F14...'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Zero-conflict macro keys (standard for Stream Decks, games & OBS):',
              style: TextStyle(fontSize: 11, color: DeckTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(12, (i) {
                final fKey = 'F${i + 13}';
                return _presetActionChip(fKey, () => _applyQuickPreset(title: fKey, subtitle: 'Macro', icon: 'bolt', command: fKey, colorHex: '#00F0FF'));
              }),
            ),
          ],
        );

      case DeckActionType.hotkey:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _commandController,
              onChanged: (_) => setState(() {}),
              decoration: _inputDeco('Key Combination (Native, No NumLock)', 'e.g. ctrl+shift+m'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _presetActionChip('Mic Mute', () => _applyQuickPreset(title: 'MIC MUTE', icon: 'mic', command: 'ctrl+shift+m', colorHex: '#10B981', isToggle: true)),
                _presetActionChip('Deafen', () => _applyQuickPreset(title: 'DEAFEN', icon: 'discord', command: 'ctrl+shift+d', colorHex: '#8B5CF6', isToggle: true)),
                _presetActionChip('Snip', () => _applyQuickPreset(title: 'SNIP', icon: 'snippet', command: 'win+shift+s', colorHex: '#FB923C')),
                _presetActionChip('Lock PC', () => _applyQuickPreset(title: 'LOCK PC', icon: 'lock', command: 'lock', colorHex: '#F43F5E')),
                _presetActionChip('Game Bar', () => _applyQuickPreset(title: 'GAME BAR', icon: 'gamepad', command: 'win+g', colorHex: '#10B981')),
                _presetActionChip('Copy', () => _applyQuickPreset(title: 'COPY', icon: 'copy', command: 'ctrl+c', colorHex: '#00F0FF')),
                _presetActionChip('Paste', () => _applyQuickPreset(title: 'PASTE', icon: 'paste', command: 'ctrl+v', colorHex: '#00F0FF')),
              ],
            ),
          ],
        );

      case DeckActionType.launchApp:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _commandController,
              onChanged: (_) => setState(() {}),
              decoration: _inputDeco('App Name or Path', 'e.g. obs, spotify, chrome, code'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _presetActionChip('OBS Studio', () => _applyQuickPreset(title: 'OBS', subtitle: 'Studio', icon: 'obs', command: 'obs', colorHex: '#8B5CF6')),
                _presetActionChip('Google Chrome', () => _applyQuickPreset(title: 'CHROME', subtitle: 'Browser', icon: 'chrome', command: 'chrome', colorHex: '#FB923C')),
                _presetActionChip('Discord', () => _applyQuickPreset(title: 'DISCORD', subtitle: 'Chat', icon: 'discord', command: 'discord', colorHex: '#8B5CF6')),
                _presetActionChip('Spotify', () => _applyQuickPreset(title: 'SPOTIFY', subtitle: 'Music', icon: 'spotify', command: 'spotify', colorHex: '#10B981')),
                _presetActionChip('VS Code', () => _applyQuickPreset(title: 'VS CODE', subtitle: 'Editor', icon: 'code', command: 'code', colorHex: '#3B82F6')),
                _presetActionChip('Task Manager', () => _applyQuickPreset(title: 'TASK MGR', subtitle: 'System', icon: 'taskmgr', command: 'taskmgr', colorHex: '#00F0FF')),
                _presetActionChip('Calculator', () => _applyQuickPreset(title: 'CALC', subtitle: 'Tools', icon: 'calculator', command: 'calc', colorHex: '#FBBF24')),
                _presetActionChip('Terminal', () => _applyQuickPreset(title: 'TERMINAL', subtitle: 'PowerShell', icon: 'terminal', command: 'powershell', colorHex: '#10B981')),
              ],
            ),
          ],
        );

      case DeckActionType.openUrl:
        return TextField(
          controller: _commandController,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('Web URL', 'e.g. https://twitch.tv'),
        );

      case DeckActionType.systemMonitor:
        return DropdownButtonFormField<String>(
          initialValue: _selectedTelemetryType ?? 'cpu',
          dropdownColor: DeckTheme.card,
          decoration: _inputDeco('System Metric', ''),
          items: const [
            DropdownMenuItem(value: 'cpu', child: Text('Live CPU % Load')),
            DropdownMenuItem(value: 'ram', child: Text('Live RAM % Usage')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedTelemetryType = val;
                _commandController.text = 'taskmgr';
              });
            }
          },
        );

      case DeckActionType.script:
        return TextField(
          controller: _commandController,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: _inputDeco('PowerShell Code', 'e.g. shutdown /s /t 0'),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _presetActionChip(String label, VoidCallback onPressed) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: DeckTheme.cyan)),
      backgroundColor: DeckTheme.card,
      side: const BorderSide(color: DeckTheme.border),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }

  InputDecoration _inputDeco(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: DeckTheme.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: DeckTheme.textMuted, fontSize: 12),
      filled: true,
      fillColor: DeckTheme.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DeckTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DeckTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DeckTheme.cyan, width: 1.2),
      ),
    );
  }
}
