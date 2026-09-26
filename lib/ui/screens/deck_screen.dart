import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/deck_action.dart';
import '../../models/deck_button.dart';
import '../../services/deck_client_service.dart';
import '../../services/deck_storage_service.dart';
import '../../services/haptic_sound_service.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_button_widget.dart';
import 'connect_screen.dart';
import 'editor_screen.dart';

/// The primary interactive Stream Deck controller interface.
class DeckScreen extends StatefulWidget {
  final VoidCallback? onSwitchToHostView;

  const DeckScreen({super.key, this.onSwitchToHostView});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  int? _customColumns;
  int? _customRows;
  bool _isEditMode = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<DeckStorageService>();
    final client = context.watch<DeckClientService>();

    final profile = storage.activeProfile;
    final pages = profile.pages;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Determine grid rows and columns
    final cols = _customColumns ?? (isLandscape ? 5 : 3);
    final rows = _customRows ?? (isLandscape ? 3 : 4);
    final totalSlots = cols * rows;

    return Scaffold(
      backgroundColor: DeckTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Minimal Header Bar
            _buildAdaptiveHeader(context, profile, storage, client, isLandscape),

            // Swipeable Deck Pages Grid
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (idx) => storage.switchPage(idx),
                itemBuilder: (context, pageIdx) {
                  final currentPage = pages[pageIdx];

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 12 : 10,
                      vertical: isLandscape ? 4 : 8,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 8.0;
                        final totalHorizontalSpacing = spacing * (cols - 1);
                        final totalVerticalSpacing = spacing * (rows - 1);

                        final itemWidth = (constraints.maxWidth - totalHorizontalSpacing) / cols;
                        final itemHeight = (constraints.maxHeight - totalVerticalSpacing) / rows;
                        final childAspectRatio = (itemWidth / itemHeight).clamp(0.7, 1.4);

                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: totalSlots,
                          itemBuilder: (context, slot) {
                            final btn = currentPage.buttons[slot];

                            // Real-time telemetry values
                            int? telemetryValue;
                            if (btn?.telemetryType == 'cpu') {
                              telemetryValue = client.cpuPercent;
                            } else if (btn?.telemetryType == 'ram') {
                              telemetryValue = client.ramPercent;
                            }

                            return DeckButtonWidget(
                              slotIndex: slot,
                              button: btn,
                              telemetryValue: telemetryValue,
                              isEditMode: _isEditMode,
                              onTap: () => _handleButtonPress(slot, btn, client, storage, profile, pageIdx),
                              onLongPress: () => _openButtonEditor(slot, btn, profile, storage, pageIdx),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Minimal Footer / Pagination Indicator
            if (pages.length > 1 || _isEditMode)
              _buildMinimalFooter(profile, storage, isLandscape),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveHeader(
    BuildContext context,
    dynamic profile,
    DeckStorageService storage,
    DeckClientService client,
    bool isLandscape,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isLandscape ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: DeckTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: DeckTheme.border.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Profile Switcher Pill
          InkWell(
            onTap: () => _showProfilePicker(context, storage),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DeckTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DeckTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(
                      color: DeckTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: DeckTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Live / Edit Mode Pill Toggle
          IconButton(
            tooltip: _isEditMode ? 'Lock Deck (Live Mode)' : 'Edit Mode',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _isEditMode ? Icons.edit_rounded : Icons.lock_outline_rounded,
              color: _isEditMode ? DeckTheme.cyan : DeckTheme.textSecondary,
              size: 20,
            ),
            onPressed: () {
              setState(() => _isEditMode = !_isEditMode);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isEditMode ? 'Edit Mode ON: Tap any key or slot to customize' : 'Live Mode ON: Keys locked against edits'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          // Grid Layout Size Toggle
          PopupMenuButton<String>(
            tooltip: 'Grid Dimensions',
            icon: const Icon(Icons.grid_view_rounded, size: 20, color: DeckTheme.textSecondary),
            color: DeckTheme.surface,
            onSelected: (val) {
              setState(() {
                if (val == 'auto') {
                  _customColumns = null;
                  _customRows = null;
                } else if (val == '3x3') {
                  _customColumns = 3;
                  _customRows = 3;
                } else if (val == '4x3') {
                  _customColumns = 4;
                  _customRows = 3;
                } else if (val == '5x3') {
                  _customColumns = 5;
                  _customRows = 3;
                }
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'auto', child: Text('Auto (Device Adaptive)')),
              PopupMenuItem(value: '3x3', child: Text('3 × 3 (9 Keys)')),
              PopupMenuItem(value: '4x3', child: Text('4 × 3 (12 Keys)')),
              PopupMenuItem(value: '5x3', child: Text('5 × 3 (15 Keys - Classic)')),
            ],
          ),

          const SizedBox(width: 4),

          // Connection Status Pill
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: client.isConnected
                    ? DeckTheme.green.withValues(alpha: 0.12)
                    : DeckTheme.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: client.isConnected
                      ? DeckTheme.green.withValues(alpha: 0.4)
                      : DeckTheme.red.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: client.isConnected ? DeckTheme.green : DeckTheme.red,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    client.isConnected ? '${client.latencyMs}ms' : 'PAIR',
                    style: TextStyle(
                      color: client.isConnected ? DeckTheme.green : DeckTheme.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalFooter(
    dynamic profile,
    DeckStorageService storage,
    bool isLandscape,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLandscape ? 3 : 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dot Indicators for Multi-page
          if (profile.pages.length > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(profile.pages.length, (i) {
                final isSelected = i == profile.activePageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? DeckTheme.cyan : DeckTheme.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  void _showProfilePicker(BuildContext context, DeckStorageService storage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DeckTheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DeckTheme.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddProfileDialog(context, storage);
                      },
                      icon: const Icon(Icons.add_rounded, size: 18, color: DeckTheme.cyan),
                      label: const Text('New Profile', style: TextStyle(color: DeckTheme.cyan, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: DeckTheme.border),
                ...List.generate(storage.profiles.length, (i) {
                  final p = storage.profiles[i];
                  final isSelected = i == storage.profiles.indexOf(storage.activeProfile);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? DeckTheme.cyan : DeckTheme.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? DeckTheme.textPrimary : DeckTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    trailing: storage.profiles.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: DeckTheme.textMuted),
                            onPressed: () {
                              storage.deleteProfile(i);
                              Navigator.pop(ctx);
                            },
                          )
                        : null,
                    onTap: () {
                      storage.switchProfile(i);
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      storage.resetToDefaults();
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 16, color: DeckTheme.textMuted),
                    label: const Text('Reset to Ready-to-Use Profiles', style: TextStyle(color: DeckTheme.textMuted, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddProfileDialog(BuildContext context, DeckStorageService storage) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeckTheme.surface,
        title: const Text('New Profile', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Photoshop / Premier',
            filled: true,
            fillColor: DeckTheme.card,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                storage.addProfile(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DeckTheme.cyan,
              foregroundColor: Colors.black,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _handleButtonPress(
    int slot,
    DeckButton? btn,
    DeckClientService client,
    DeckStorageService storage,
    dynamic profile,
    int pageIdx,
  ) {
    HapticSoundService.triggerClick(context);

    if (btn == null) {
      if (_isEditMode) {
        _openButtonEditor(slot, null, profile, storage, pageIdx);
      }
      return;
    }

    // Toggle state update
    if (btn.isToggle) {
      storage.toggleButtonState(pageIdx, slot);
    }

    // Handle Folder / Page navigation
    if (btn.action.type == DeckActionType.pageNav && btn.action.targetPageIndex != null) {
      _pageController.animateToPage(
        btn.action.targetPageIndex!,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Dispatch action over WebSocket to Windows Host
    if (client.isConnected) {
      client.pressButton(btn.id, slot, btn.action);
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${btn.title} triggered [${btn.action.command}] (Not paired with PC)'),
          duration: const Duration(seconds: 1),
          backgroundColor: DeckTheme.card,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Pair PC',
            textColor: DeckTheme.cyan,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  void _openButtonEditor(
    int slot,
    DeckButton? btn,
    dynamic profile,
    DeckStorageService storage,
    int pageIdx,
  ) {
    HapticSoundService.triggerHeavy(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DeckTheme.surface,
      builder: (ctx) => ButtonEditorSheet(
        slotIndex: slot,
        initialButton: btn,
        onSave: (savedBtn) {
          storage.updateButton(pageIdx, slot, savedBtn);
        },
        onDelete: btn != null
            ? () {
                storage.deleteButton(pageIdx, slot);
              }
            : null,
      ),
    );
  }
}
