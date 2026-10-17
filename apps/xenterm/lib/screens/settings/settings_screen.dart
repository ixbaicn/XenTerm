import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/termius_theme.dart';
import 'settings_catalog.dart';

/// Settings preview. Only the appearance switch changes the running app;
/// all other values live in memory and are deliberately not wired to the core.
class SettingsScreen extends StatefulWidget {
  final bool lightTheme;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.lightTheme,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, String> _previewValues = {};
  String? _expandedKey;

  String _valueFor(SettingEntry entry) =>
      _previewValues[entry.backendKey] ?? entry.initialValue ?? '';

  void _open(SettingEntry entry) {
    setState(
      () => _expandedKey = _expandedKey == entry.backendKey
          ? null
          : entry.backendKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        Text(
          '设置',
          style: theme.typography.bold.copyWith(
            fontSize: 22,
            color: theme.colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '界面预览 · 除主题外，选项暂未连接实际功能',
          style: theme.typography.normal.copyWith(
            fontSize: 13,
            color: theme.colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),
        _section(context, '外观', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '界面主题',
                    style: theme.typography.medium.copyWith(fontSize: 15),
                  ),
                ),
                _themeButton(
                  context,
                  '深色',
                  !widget.lightTheme,
                  () => widget.onThemeChanged(false),
                ),
                const SizedBox(width: 8),
                _themeButton(
                  context,
                  '浅色',
                  widget.lightTheme,
                  () => widget.onThemeChanged(true),
                ),
              ],
            ),
          ),
        ]),
        for (final section in settingsSections) ...[
          const SizedBox(height: 16),
          _section(context, section.title, [
            for (final entry in section.entries) ...[
              _settingRow(context, entry),
              if (_expandedKey == entry.backendKey) _details(context, entry),
            ],
          ]),
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Text(
              title,
              style: theme.typography.bold.copyWith(fontSize: 18),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _settingRow(BuildContext context, SettingEntry entry) {
    final theme = Theme.of(context);
    final isToggle = entry.kind == SettingKind.toggle;
    final enabled = _valueFor(entry) == 'true';
    final detail = entry.kind == SettingKind.choice
        ? _valueFor(entry)
        : entry.subtitle;
    // TODO(settings/backend): On integration, read/write entry.backendKey from
    // the real preference store and apply it to the matching feature. A toggle
    // here currently changes only the preview, not platform/SSH behavior.
    void activate() {
      if (isToggle) {
        setState(
          () => _previewValues[entry.backendKey] = (!enabled).toString(),
        );
      } else {
        _open(entry);
      }
    }

    return Semantics(
      button: true,
      label: entry.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: activate,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.title,
                              style: theme.typography.medium.copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (entry.mobileOnly) ...[
                            const SizedBox(width: 8),
                            Text(
                              '移动端',
                              style: theme.typography.normal.copyWith(
                                fontSize: 11,
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (detail != null && detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          style: theme.typography.normal.copyWith(
                            fontSize: 13,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isToggle)
                  _previewSwitch(context, enabled)
                else if (entry.kind == SettingKind.destination ||
                    entry.kind == SettingKind.info)
                  Icon(
                    BootstrapIcons.chevronRight,
                    size: 15,
                    color: theme.colorScheme.mutedForeground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewSwitch(BuildContext context, bool enabled) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: TermiusMotion.micro,
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: enabled ? scheme.primary : scheme.mutedForeground,
        borderRadius: BorderRadius.circular(TermiusRadius.pill),
      ),
      child: Align(
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _details(BuildContext context, SettingEntry entry) {
    final theme = Theme.of(context);
    if (entry.kind != SettingKind.choice || entry.options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Text(
          '待接入实际功能：${entry.backendKey}',
          style: theme.typography.normal.copyWith(
            fontSize: 12,
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in entry.options)
            _themeButton(context, option, _valueFor(entry) == option, () {
              setState(() {
                _previewValues[entry.backendKey] = option;
                _expandedKey = null;
              });
            }),
        ],
      ),
    );
  }

  Widget _themeButton(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(TermiusRadius.menu),
            ),
            child: Text(
              label,
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: selected
                    ? theme.colorScheme.primaryForeground
                    : theme.colorScheme.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
