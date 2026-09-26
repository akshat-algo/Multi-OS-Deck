/// Supported types of Stream Deck actions.
enum DeckActionType {
  media,
  hotkey,
  launchApp,
  openUrl,
  obs,
  systemMonitor,
  window,
  browser,
  streamDeckKey,
  script,
  folder,
  pageNav,
  none,
}

/// Represents an executable action assigned to a Stream Deck button.
class DeckAction {
  final DeckActionType type;
  final String command;
  final Map<String, dynamic> params;
  final String? targetFolderId;
  final int? targetPageIndex;

  const DeckAction({
    required this.type,
    required this.command,
    this.params = const {},
    this.targetFolderId,
    this.targetPageIndex,
  });

  const DeckAction.empty()
      : type = DeckActionType.none,
        command = '',
        params = const {},
        targetFolderId = null,
        targetPageIndex = null;

  factory DeckAction.media(String mediaCommand) {
    return DeckAction(
      type: DeckActionType.media,
      command: mediaCommand,
    );
  }

  factory DeckAction.hotkey(String keys) {
    return DeckAction(
      type: DeckActionType.hotkey,
      command: keys,
    );
  }

  factory DeckAction.window(String windowCommand) {
    return DeckAction(
      type: DeckActionType.window,
      command: windowCommand,
    );
  }

  factory DeckAction.browser(String browserCommand) {
    return DeckAction(
      type: DeckActionType.browser,
      command: browserCommand,
    );
  }

  factory DeckAction.streamDeckKey(String fKey) {
    return DeckAction(
      type: DeckActionType.streamDeckKey,
      command: fKey,
    );
  }

  factory DeckAction.launchApp(String appPath, [List<String>? args]) {
    return DeckAction(
      type: DeckActionType.launchApp,
      command: appPath,
      params: args != null ? {'args': args} : const {},
    );
  }

  factory DeckAction.openUrl(String url) {
    return DeckAction(
      type: DeckActionType.openUrl,
      command: url,
    );
  }

  factory DeckAction.obs(String obsAction, [Map<String, dynamic>? params]) {
    return DeckAction(
      type: DeckActionType.obs,
      command: obsAction,
      params: params ?? const {},
    );
  }

  factory DeckAction.systemMonitor(String metric) {
    return DeckAction(
      type: DeckActionType.systemMonitor,
      command: metric, // 'cpu', 'ram', 'gpu'
    );
  }

  factory DeckAction.script(String scriptContent, {bool isPowershell = true}) {
    return DeckAction(
      type: DeckActionType.script,
      command: scriptContent,
      params: {'isPowershell': isPowershell},
    );
  }

  factory DeckAction.folder(String folderId) {
    return DeckAction(
      type: DeckActionType.folder,
      command: folderId,
      targetFolderId: folderId,
    );
  }

  factory DeckAction.pageNav(int pageIndex) {
    return DeckAction(
      type: DeckActionType.pageNav,
      command: pageIndex.toString(),
      targetPageIndex: pageIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'command': command,
      'params': params,
      if (targetFolderId != null) 'targetFolderId': targetFolderId,
      if (targetPageIndex != null) 'targetPageIndex': targetPageIndex,
    };
  }

  factory DeckAction.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'none';
    final type = DeckActionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => DeckActionType.none,
    );

    return DeckAction(
      type: type,
      command: json['command'] as String? ?? '',
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'] as Map)
          : const {},
      targetFolderId: json['targetFolderId'] as String?,
      targetPageIndex: json['targetPageIndex'] as int?,
    );
  }

  @override
  String toString() => 'DeckAction(type: ${type.name}, command: $command)';
}
