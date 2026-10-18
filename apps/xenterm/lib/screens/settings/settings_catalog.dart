/// Settings visible in the supplied Termius mobile screenshots. These are UI
/// defaults only: values are neither persisted nor applied to SSH/terminal APIs.
/// `backendKey` names the intended integration point for a future settings store.
enum SettingKind { choice, toggle, destination, info }

class SettingEntry {
  final String title;
  final String? subtitle;
  final String backendKey;
  final SettingKind kind;
  final String? initialValue;
  final List<String> options;
  final bool mobileOnly;

  const SettingEntry(
    this.title,
    this.backendKey,
    this.kind, {
    this.subtitle,
    this.initialValue,
    this.options = const [],
    this.mobileOnly = false,
  });
}

class SettingSection {
  final String title;
  final List<SettingEntry> entries;

  const SettingSection(this.title, this.entries);
}

// TODO(settings/backend): Replace initialValue with values loaded from the
// settings store; route each backendKey to its platform-specific implementation.
// Mobile-only entries stay visible on desktop as a UI reference, but must not
// claim to control Android hardware or security until implemented there.
const settingsSections = <SettingSection>[
  SettingSection('终端', [
    SettingEntry(
      '快捷键设置',
      'terminal.hotkeys.modifier',
      SettingKind.choice,
      initialValue: '使用 Ctrl',
      options: ['使用 Ctrl', '使用 Alt', '关闭'],
    ),
    SettingEntry(
      '自定义键盘',
      'terminal.keyboard.layout',
      SettingKind.destination,
      mobileOnly: true,
    ),
    SettingEntry(
      '终端回滚缓冲区大小',
      'terminal.scrollback.lines',
      SettingKind.choice,
      initialValue: '1000 行',
      options: ['500 行', '1000 行', '5000 行', '10000 行', '无限制'],
    ),
    SettingEntry(
      '提示音设置',
      'terminal.bell.mode',
      SettingKind.choice,
      initialValue: '振动和声音',
      options: ['振动和声音', '仅振动', '仅声音', '关闭'],
      mobileOnly: true,
    ),
    SettingEntry(
      '启用自动补全',
      'terminal.autocomplete.enabled',
      SettingKind.toggle,
      initialValue: 'true',
    ),
    SettingEntry(
      '双指缩放',
      'terminal.pinch_zoom.enabled',
      SettingKind.toggle,
      initialValue: 'true',
      mobileOnly: true,
    ),
    SettingEntry(
      '光标速度',
      'terminal.cursor.speed',
      SettingKind.choice,
      initialValue: '正常',
      options: ['慢', '正常', '快'],
      mobileOnly: true,
    ),
    SettingEntry(
      '防止休眠',
      'terminal.keep_awake',
      SettingKind.toggle,
      subtitle: '使用终端时保持屏幕常亮',
      initialValue: 'false',
      mobileOnly: true,
    ),
    SettingEntry(
      '实验性键盘支持',
      'terminal.keyboard.experimental',
      SettingKind.toggle,
      subtitle: '语音输入及中日韩输入法布局支持',
      initialValue: 'false',
      mobileOnly: true,
    ),
  ]),
  SettingSection('会话', [
    SettingEntry(
      '保活间隔',
      'session.keepalive.interval_seconds',
      SettingKind.choice,
      initialValue: '60 秒',
      options: ['关闭', '30 秒', '60 秒', '120 秒'],
    ),
    SettingEntry(
      '保活最大次数',
      'session.keepalive.max_count',
      SettingKind.choice,
      initialValue: '1',
      options: ['1', '3', '5', '10'],
    ),
    SettingEntry(
      '后量子密钥交换',
      'session.ssh.post_quantum_kex',
      SettingKind.toggle,
      subtitle: '连接旧设备遇到问题时可关闭',
      initialValue: 'true',
    ),
    SettingEntry(
      '检测操作系统',
      'session.detect_os',
      SettingKind.toggle,
      initialValue: 'true',
    ),
    SettingEntry(
      '导入 Shell 历史',
      'session.shell_history.import',
      SettingKind.toggle,
      subtitle: '自动补全及查看命令历史所需',
      initialValue: 'true',
    ),
  ]),
  SettingSection('通知', [
    SettingEntry(
      '启用通知',
      'notifications.active_connections',
      SettingKind.destination,
      subtitle: '自定义或关闭活动连接通知',
    ),
  ]),
  SettingSection('安全与隐私', [
    SettingEntry(
      'PIN 码和图案锁',
      'privacy.app_lock',
      SettingKind.destination,
      subtitle: '已关闭',
      mobileOnly: true,
    ),
    SettingEntry('日志存储', 'privacy.logs.storage', SettingKind.destination),
    SettingEntry(
      '发送诊断数据',
      'privacy.diagnostics.enabled',
      SettingKind.toggle,
      subtitle: '帮助改进应用',
      initialValue: 'true',
    ),
    SettingEntry(
      '截图与屏幕录制',
      'privacy.screen_capture',
      SettingKind.choice,
      subtitle: '包含敏感数据的页面禁止截屏',
      initialValue: '禁止',
      options: ['禁止', '允许'],
      mobileOnly: true,
    ),
  ]),
  SettingSection('音量键', [
    SettingEntry(
      '音量增大',
      'mobile.volume_up.action',
      SettingKind.choice,
      initialValue: '已关闭',
      options: ['已关闭', '上翻页', '下翻页'],
      mobileOnly: true,
    ),
    SettingEntry(
      '音量减小',
      'mobile.volume_down.action',
      SettingKind.choice,
      initialValue: '已关闭',
      options: ['已关闭', '上翻页', '下翻页'],
      mobileOnly: true,
    ),
  ]),
  SettingSection('摇动', [
    SettingEntry(
      '摇动',
      'mobile.shake.action',
      SettingKind.choice,
      initialValue: '已关闭',
      options: ['已关闭', '打开终端', '新建连接'],
      mobileOnly: true,
    ),
  ]),
  SettingSection('关于', [
    SettingEntry(
      '为 Termius 评分',
      'about.termius.rating',
      SettingKind.info,
      subtitle: '参考截图版本：7.11.2 (988)',
    ),
    SettingEntry(
      '更多关于 Termius',
      'about.termius.website',
      SettingKind.info,
      subtitle: 'https://termius.com',
    ),
    SettingEntry('帮助与反馈', 'about.feedback', SettingKind.destination),
  ]),
];
