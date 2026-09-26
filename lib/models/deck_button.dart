import 'deck_action.dart';

/// Represents a single key/pad on the Stream Deck grid.
class DeckButton {
  final String id;
  final String title;
  final String? subtitle;
  final String iconKey;
  final String backgroundColorHex;
  final String activeColorHex;
  final String glowColorHex;
  final DeckAction action;
  final bool isToggle;
  final bool isActive;
  final String? folderId;
  final String? telemetryType;
  final String? telemetryValue;

  const DeckButton({
    required this.id,
    required this.title,
    this.subtitle,
    required this.iconKey,
    this.backgroundColorHex = '#1A1D26',
    this.activeColorHex = '#00F0FF',
    this.glowColorHex = '#00E5FF',
    required this.action,
    this.isToggle = false,
    this.isActive = false,
    this.folderId,
    this.telemetryType,
    this.telemetryValue,
  });

  DeckButton copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? iconKey,
    String? backgroundColorHex,
    String? activeColorHex,
    String? glowColorHex,
    DeckAction? action,
    bool? isToggle,
    bool? isActive,
    String? folderId,
    String? telemetryType,
    String? telemetryValue,
  }) {
    return DeckButton(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconKey: iconKey ?? this.iconKey,
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      activeColorHex: activeColorHex ?? this.activeColorHex,
      glowColorHex: glowColorHex ?? this.glowColorHex,
      action: action ?? this.action,
      isToggle: isToggle ?? this.isToggle,
      isActive: isActive ?? this.isActive,
      folderId: folderId ?? this.folderId,
      telemetryType: telemetryType ?? this.telemetryType,
      telemetryValue: telemetryValue ?? this.telemetryValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'iconKey': iconKey,
      'backgroundColorHex': backgroundColorHex,
      'activeColorHex': activeColorHex,
      'glowColorHex': glowColorHex,
      'action': action.toJson(),
      'isToggle': isToggle,
      'isActive': isActive,
      if (folderId != null) 'folderId': folderId,
      if (telemetryType != null) 'telemetryType': telemetryType,
      if (telemetryValue != null) 'telemetryValue': telemetryValue,
    };
  }

  factory DeckButton.fromJson(Map<String, dynamic> json) {
    return DeckButton(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      iconKey: json['iconKey'] as String? ?? 'grid',
      backgroundColorHex: json['backgroundColorHex'] as String? ?? '#1A1D26',
      activeColorHex: json['activeColorHex'] as String? ?? '#00F0FF',
      glowColorHex: json['glowColorHex'] as String? ?? '#00E5FF',
      action: json['action'] != null
          ? DeckAction.fromJson(Map<String, dynamic>.from(json['action'] as Map))
          : DeckAction.empty(),
      isToggle: json['isToggle'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      telemetryType: json['telemetryType'] as String?,
      telemetryValue: json['telemetryValue'] as String?,
    );
  }

  @override
  String toString() => 'DeckButton(id: $id, title: $title, action: ${action.type})';
}
