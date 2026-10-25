import 'package:shadcn_flutter/shadcn_flutter.dart';

/// UI language lives above the shell so every page can read the same choice.
///
/// The selected code is persisted by the app root (`main.dart`) in
/// `SharedPreferences` under `xenterm.language`; changing it rebuilds the
/// subtree because [updateShouldNotify] compares the code. Translations are a
/// small literal map instead of generated ARB files: the desktop UI ships two
/// languages and only needs a stable key (the English string) for now.
class AppLanguage extends InheritedWidget {
  static const supported = <String, String>{'en': 'English', 'zh': '简体中文'};

  final String code;
  final ValueChanged<String> onChanged;

  const AppLanguage({
    super.key,
    required this.code,
    required this.onChanged,
    required super.child,
  });

  static AppLanguage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguage>();

  static AppLanguage of(BuildContext context) => maybeOf(context)!;

  /// Translates [english] for the language above [context]; falls back to the
  /// English source string when no [AppLanguage] is mounted (widget tests that
  /// pump a single panel) or the key is not translated yet.
  static String tr(BuildContext context, String english) =>
      maybeOf(context)?.text(english) ?? english;

  /// Display name for a supported code (`en` → `English`).
  static String? nameOf(String code) => supported[code];

  String text(String english) => _translations[code]?[english] ?? english;

  @override
  bool updateShouldNotify(AppLanguage oldWidget) =>
      code != oldWidget.code || onChanged != oldWidget.onChanged;
}

const _translations = <String, Map<String, String>>{'zh': _zh};

/// Simplified-Chinese strings. Keys are the English source literals used in the
/// shell and the Settings screen; unknown keys fall back to English.
const _zh = <String, String>{
  // Navigation rail and window-level titles.
  'Home': '首页',
  'Keychain': '密钥管理',
  'Tunnels': '隧道与跳板',
  'Snippets': '命令片段',
  'Known Hosts': '已知主机',
  'Logs': '日志',
  'Settings': '设置',

  // Settings tabs and language picker.
  'Terminal': '终端',
  'SFTP': 'SFTP',
  'Shortcuts': '快捷键',
  'Language': '语言',
  'Interface language': '界面语言',

  // Terminal tab.
  'Terminal settings': '终端设置',
  'Cursor style': '光标样式',
  'Block': '方块',
  'Bar': '竖线',
  'Underline': '下划线',
  'Line spacing': '行间距',
  'Compact': '紧凑',
  'Normal': '正常',
  'Relaxed': '宽松',
  'Inset terminal text': '终端文字内边距',
  'Keep a small margin around the character grid': '在字符网格周围留出少量空白',
  'Use a bold face for terminal text': '终端文字使用粗体',
  'Font': '字体',
  'Default': '默认',
  'Text Size': '文字大小',
  'Terminal theme': '终端主题',
  'Theme': '主题',
  'Dark': '深色',
  'Light': '浅色',
  'Interface': '界面',
  'Import font (TTF/OTF)': '导入字体 (TTF/OTF)',
  "Imported fonts are stored in this device's app data.": '导入的字体保存在本机应用数据中。',

  // SFTP tab.
  'SFTP settings': 'SFTP 设置',
  'Follow the terminal directory': '跟随终端目录',
  "Open the file browser at the shell's current folder when supported":
      '支持时在终端当前目录打开文件浏览器',
  'Download folder': '下载文件夹',
  'Ask for a folder each time': '每次询问文件夹',
  'Clear download folder': '清除下载文件夹',
  'Downloaded files are written to this folder; the picker appears when no folder is set.':
      '下载文件将保存到此文件夹；未设置时会显示文件夹选择器。',

  // Logs tab.
  'Session logs': '会话日志',
  'Save session logs': '保存会话日志',
  'Record new terminal sessions as text transcripts. Existing sessions are not recorded retroactively.':
      '将新终端会话记录为文字日志，已有会话不会追溯记录。',
  'Transcripts are stored in the app data folder and appear in Logs, where they can be opened or deleted. Nothing is uploaded.':
      '会话记录保存在本机应用数据文件夹，可在日志中查看或删除；不会上传。',
  'Profile data': '配置数据',
  'Export sessions (JSON)': '导出会话 (JSON)',
  'Import sessions (JSON)': '导入会话 (JSON)',
  'Exports carry every saved host; secrets are written in the portable encrypted form. Importing never overwrites existing sessions — new ones are appended.':
      '导出包含全部已保存主机，密钥使用可移植加密形式写入；导入不会覆盖已有会话，只追加新会话。',

  // Shortcuts tab.
  'Keyboard shortcuts': '键盘快捷键',
  'Search the terminal buffer': '搜索终端缓冲区',
  'Clear the screen (sent to the shell)': '清屏（发送到 shell）',
  'Interrupt the running command': '中断正在运行的命令',
  'Backtab': '反向切换',
  'Move through the terminal buffer': '浏览终端缓冲区',
  'Run the command': '运行命令',

  // Shared controls.
  'Choose…': '选择…',
  'Remove host': '删除主机',
};
