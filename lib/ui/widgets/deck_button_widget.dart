import 'package:flutter/material.dart';
import '../../models/deck_button.dart';
import '../theme/deck_icons.dart';
import '../theme/deck_theme.dart';

/// Highly tactile physical-feel LCD key widget for the Stream Deck.
class DeckButtonWidget extends StatefulWidget {
  final DeckButton? button;
  final int slotIndex;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int? telemetryValue;
  final bool isEditMode;

  const DeckButtonWidget({
    super.key,
    this.button,
    required this.slotIndex,
    this.onTap,
    this.onLongPress,
    this.telemetryValue,
    this.isEditMode = true,
  });

  @override
  State<DeckButtonWidget> createState() => _DeckButtonWidgetState();
}

class _DeckButtonWidgetState extends State<DeckButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final btn = widget.button;

    if (btn == null) {
      // Empty slot placeholder: minimal, non-intrusive ghost pad
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.isEditMode ? widget.onLongPress : null,
          child: Container(
            decoration: BoxDecoration(
              color: _isHovered
                  ? DeckTheme.card.withValues(alpha: 0.4)
                  : DeckTheme.card.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered
                    ? DeckTheme.cyan.withValues(alpha: 0.3)
                    : DeckTheme.border.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.add_rounded,
                color: widget.isEditMode
                    ? (_isHovered
                        ? DeckTheme.cyan.withValues(alpha: 0.6)
                        : DeckTheme.textMuted.withValues(alpha: 0.25))
                    : Colors.transparent,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    final isToggledActive = btn.isToggle && btn.isActive;
    final primaryColor = isToggledActive
        ? DeckTheme.fromHex(btn.activeColorHex, DeckTheme.green)
        : DeckTheme.fromHex(btn.glowColorHex, DeckTheme.cyan);

    final bgBase = DeckTheme.fromHex(btn.backgroundColorHex, DeckTheme.card);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              onLongPress: widget.isEditMode ? widget.onLongPress : null,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isToggledActive
                      ? primaryColor.withValues(alpha: 0.18)
                      : bgBase,
                  border: Border.all(
                    color: isToggledActive
                        ? primaryColor.withValues(alpha: 0.8)
                        : _isHovered
                            ? primaryColor.withValues(alpha: 0.5)
                            : DeckTheme.border.withValues(alpha: 0.8),
                    width: isToggledActive ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    if (isToggledActive)
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.22),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    else if (_isHovered)
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.12),
                        blurRadius: 8,
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Key Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icon or Telemetry Gauge
                            if (btn.telemetryType != null &&
                                (btn.telemetryType == 'cpu' || btn.telemetryType == 'ram'))
                              _buildTelemetryTile(btn, primaryColor)
                            else
                              _buildIconTile(btn, primaryColor, isToggledActive),

                            const SizedBox(height: 5),

                            // Main Title Label
                            Text(
                              btn.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isToggledActive
                                    ? primaryColor
                                    : DeckTheme.textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),

                            // Optional Subtitle
                            if (btn.subtitle != null && btn.subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                btn.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: DeckTheme.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Clean Active State Indicator Pill / Dot
                      if (btn.isToggle)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToggledActive
                                  ? primaryColor
                                  : DeckTheme.textMuted.withValues(alpha: 0.3),
                              boxShadow: isToggledActive
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.8),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),

                      // Subtle Edit badge indicator in edit mode
                      if (widget.isEditMode && _isHovered)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Icon(
                            Icons.edit_rounded,
                            size: 11,
                            color: DeckTheme.textMuted.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconTile(DeckButton btn, Color color, bool isActive) {
    final iconData = DeckIcons.getIcon(btn.iconKey);
    return Icon(
      iconData,
      color: isActive ? color : color.withValues(alpha: 0.9),
      size: 26,
    );
  }

  Widget _buildTelemetryTile(DeckButton btn, Color color) {
    final value = widget.telemetryValue ?? 0;

    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            strokeWidth: 3.0,
            backgroundColor: DeckTheme.border.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              value > 85 ? DeckTheme.red : color,
            ),
          ),
          Center(
            child: Text(
              '$value%',
              style: TextStyle(
                color: value > 85 ? DeckTheme.red : DeckTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
