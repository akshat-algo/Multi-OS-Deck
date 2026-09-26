import 'deck_button.dart';

/// Represents a single page/grid of Stream Deck buttons.
class DeckPage {
  final String id;
  final String name;
  final int rows;
  final int columns;
  final Map<int, DeckButton> buttons;
  final String? folderId;

  const DeckPage({
    required this.id,
    required this.name,
    this.rows = 3,
    this.columns = 5,
    this.buttons = const {},
    this.folderId,
  });

  int get totalSlots => rows * columns;

  DeckPage copyWith({
    String? id,
    String? name,
    int? rows,
    int? columns,
    Map<int, DeckButton>? buttons,
    String? folderId,
  }) {
    return DeckPage(
      id: id ?? this.id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      buttons: buttons ?? this.buttons,
      folderId: folderId ?? this.folderId,
    );
  }

  Map<String, dynamic> toJson() {
    final buttonsJson = <String, dynamic>{};
    buttons.forEach((slot, btn) {
      buttonsJson[slot.toString()] = btn.toJson();
    });

    return {
      'id': id,
      'name': name,
      'rows': rows,
      'columns': columns,
      'buttons': buttonsJson,
      if (folderId != null) 'folderId': folderId,
    };
  }

  factory DeckPage.fromJson(Map<String, dynamic> json) {
    final buttonsMap = <int, DeckButton>{};
    if (json['buttons'] is Map) {
      final rawButtons = json['buttons'] as Map;
      rawButtons.forEach((key, val) {
        final slot = int.tryParse(key.toString());
        if (slot != null && val is Map) {
          buttonsMap[slot] = DeckButton.fromJson(Map<String, dynamic>.from(val));
        }
      });
    }

    return DeckPage(
      id: json['id'] as String? ?? 'page_1',
      name: json['name'] as String? ?? 'Page 1',
      rows: json['rows'] as int? ?? 3,
      columns: json['columns'] as int? ?? 5,
      buttons: buttonsMap,
      folderId: json['folderId'] as String?,
    );
  }
}

/// Represents a complete user profile containing multiple pages and folders.
class DeckProfile {
  final String id;
  final String name;
  final List<DeckPage> pages;
  final int activePageIndex;

  const DeckProfile({
    required this.id,
    required this.name,
    required this.pages,
    this.activePageIndex = 0,
  });

  DeckPage get activePage {
    if (activePageIndex >= 0 && activePageIndex < pages.length) {
      return pages[activePageIndex];
    }
    return pages.isNotEmpty ? pages.first : const DeckPage(id: 'default', name: 'Main');
  }

  DeckProfile copyWith({
    String? id,
    String? name,
    List<DeckPage>? pages,
    int? activePageIndex,
  }) {
    return DeckProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      pages: pages ?? this.pages,
      activePageIndex: activePageIndex ?? this.activePageIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pages': pages.map((p) => p.toJson()).toList(),
      'activePageIndex': activePageIndex,
    };
  }

  factory DeckProfile.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List? ?? [];
    final pagesList = rawPages
        .whereType<Map>()
        .map((p) => DeckPage.fromJson(Map<String, dynamic>.from(p)))
        .toList();

    return DeckProfile(
      id: json['id'] as String? ?? 'profile_default',
      name: json['name'] as String? ?? 'Default Profile',
      pages: pagesList.isNotEmpty
          ? pagesList
          : [const DeckPage(id: 'page_1', name: 'Page 1')],
      activePageIndex: json['activePageIndex'] as int? ?? 0,
    );
  }
}
