/// Settings — the desktop settings window. Every control here changes a real
/// value: terminal rendering reads the core settings live, font choices are
/// persisted by [AppFonts], the SFTP download folder is used by the file
/// browser, and "Save session logs" controls the core transcript writer.
///
/// Header 80px, a 220px tab sidebar and the tab content, all painted from the
/// shared theme tokens. Every control is the shared primitive (XtSwitchRow,
/// XtSelectRow, XtStepper, XtCard) rather than a screen-local copy.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart'
    show CoreSettings, exportProfileFromCore, importProfileToCore;
import '../../l10n/app_language.dart';
import '../../terminal/core_settings.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primitives.dart';

class SettingsScreen extends StatefulWidget {
  final bool lightTheme;
  final ValueChanged<bool> onThemeChanged;
  final AppFonts fonts;
  final CoreSettingsController settings;

  /// Test/alternate persistence hook; defaults to the shared controller.
  final Future<String?> Function(Map<String, dynamic> values)? saveSettings;

  const SettingsScreen({
    super.key,
    required this.lightTheme,
    required this.onThemeChanged,
    required this.fonts,
    required this.settings,
    this.saveSettings,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dataBusy = false;
  bool _dataError = false;
  String? _dataStatus;

  Future<void> _exportProfile() async {
    setState(() {
      _dataBusy = true;
      _dataStatus = null;
      _dataError = false;
    });
    try {
      final export = await exportProfileFromCore();
      final location = await getSaveLocation(
        suggestedName: 'xenterm-profile.json',
      );
      if (location == null) {
        if (mounted) setState(() => _dataBusy = false);
        return;
      }
      await File(location.path).writeAsString(export.json, flush: true);
      if (!mounted) return;
      setState(() {
        _dataBusy = false;
        _dataStatus =
            'Exported ${export.count} session${export.count == 1 ? '' : 's'} '
            'to ${location.path.split(Platform.pathSeparator).last}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dataBusy = false;
        _dataError = true;
        _dataStatus = '$error';
      });
    }
  }

  Future<void> _importProfile() async {
    setState(() {
      _dataBusy = true;
      _dataStatus = null;
      _dataError = false;
    });
    try {
      final file = await openFile();
      if (file == null) {
        if (mounted) setState(() => _dataBusy = false);
        return;
      }
      final raw = await File(file.path).readAsString();
      // Validate first, then commit — the core is append-only either way.
      final preview = await importProfileToCore(raw, dryRun: true);
      final applied = await importProfileToCore(raw);
      if (!mounted) return;
      setState(() {
        _dataBusy = false;
        _dataStatus =
            'Imported ${applied.added} session${applied.added == 1 ? '' : 's'} '
            '(${preview.skipped} already present, skipped)';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dataBusy = false;
        _dataError = true;
        _dataStatus = '$error';
      });
    }
  }

  static const _tabs = ['Terminal', 'SFTP', 'Logs', 'Shortcuts'];

  int _tab = 0;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_changed);
    if (!widget.settings.loaded) widget.settings.load();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  CoreSettings get _core => widget.settings.settings;

  Future<void> _save(Map<String, dynamic> values) async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final error =
        await (widget.saveSettings?.call(values) ??
            widget.settings.update(values));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = error;
    });
  }

  Future<void> _chooseDownloadFolder() async {
    final directory = await getDirectoryPath();
    if (directory == null || directory.isEmpty) return;
    await _save({'download_dir': directory});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: XtColors.chrome(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 80,
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: XtColors.hairline(context)),
              ),
            ),
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Text(
                  AppLanguage.tr(context, 'Settings'),
                  style: theme.typography.bold.copyWith(
                    fontSize: 24,
                    height: 45 / 24,
                    color: XtColors.textPrimary(context),
                  ),
                ),
                const Spacer(),
                if (_saving)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The tab rail shrinks a step on small windows so the 700px
                // card column keeps its breathing room at the 940px minimum.
                final sidebarWidth = constraints.maxWidth < 1000 ? 176.0 : 220.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TabSidebar(
                      width: sidebarWidth,
                      tabs: _tabs,
                      active: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: XtColors.page(context),
                        // The content column is capped at 700 and centred; the
                        // surrounding ListView scrolls so a short window never
                        // clips the last card, and the horizontal padding keeps
                        // the card off the window edge at narrow widths.
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
                          children: [
                            if (_saveError != null)
                              _SectionCard(
                                children: [
                                  _SettingsText(
                                    _saveError!,
                                    color: XtColors.danger(context),
                                  ),
                                ],
                              ),
                            ..._contentFor(_tab),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contentFor(int tab) => switch (tab) {
    0 => _terminalTab(),
    1 => _sftpTab(),
    2 => _logsTab(),
    _ => _shortcutsTab(),
  };

  List<Widget> _terminalTab() {
    final fonts = widget.fonts;
    final core = _core;
    final language = AppLanguage.maybeOf(context);
    return [
      // Language is global, so it sits first: switching it rebuilds the whole
      // shell while every value below stays untouched.
      _SectionCard(
        title: 'Language',
        children: [
          XtSelectRow<String>(
            key: const ValueKey('setting-language'),
            label: 'Interface language',
            value: language?.code ?? 'en',
            options: const {'en': 'English', 'zh': '简体中文'},
            onChanged: (code) => language?.onChanged(code),
          ),
        ],
      ),
      _SectionCard(
        title: 'Terminal settings',
        children: [
          XtSelectRow<String>(
            label: 'Cursor style',
            value: switch (core.cursorStyle) {
              'bar' => 'Bar',
              'underline' => 'Underline',
              _ => 'Block',
            },
            options: const {'Block': 'Block', 'Bar': 'Bar', 'Underline': 'Underline'},
            onChanged: (value) => _save({
              'cursor_style': switch (value) {
                'Bar' => 'bar',
                'Underline' => 'underline',
                _ => 'block',
              },
            }),
          ),
          XtSelectRow<String>(
            label: 'Line spacing',
            value: switch (core.lineSpacing) {
              <= 0.92 => 'Compact',
              >= 1.08 => 'Relaxed',
              _ => 'Normal',
            },
            options: const {
              'Compact': 'Compact',
              'Normal': 'Normal',
              'Relaxed': 'Relaxed',
            },
            onChanged: (value) => _save({
              'line_spacing': switch (value) {
                'Compact' => 0.85,
                'Relaxed' => 1.15,
                _ => 1.0,
              },
            }),
          ),
          XtSwitchRow(
            key: const ValueKey('setting-padding'),
            label: 'Inset terminal text',
            description: 'Keep a small margin around the character grid',
            value: core.padding,
            onChanged: (value) => _save({'padding': value}),
          ),
          XtSwitchRow(
            key: const ValueKey('setting-bold'),
            label: 'Use a bold face for terminal text',
            value: core.bold,
            onChanged: (value) => _save({'bold': value}),
          ),
        ],
      ),
      _SectionCard(
        children: [
          XtSelectRow<String>(
            label: 'Font',
            value: fonts.terminalFamily.isEmpty
                ? 'Default'
                : _familyLabel(fonts.terminalFamily),
            options: _fontChoice(fonts),
            onChanged: (value) => setState(() {
              fonts.setTerminalFamily(
                value == 'Default' ? '' : _familyValue(value),
              );
            }),
          ),
          _StepperRow(
            label: 'Text Size',
            keyPrefix: 'terminal',
            value: fonts.terminalSize,
            onChanged: fonts.setTerminalSize,
            min: 10,
            max: 28,
          ),
        ],
      ),
      _SectionCard(
        title: 'Terminal theme',
        children: [
          XtSelectRow<String>(
            label: 'Theme',
            value: widget.lightTheme ? 'Light' : 'Dark',
            options: const {'Dark': 'Dark', 'Light': 'Light'},
            onChanged: (value) => widget.onThemeChanged(value == 'Light'),
          ),
        ],
      ),
      _SectionCard(
        title: 'Interface',
        children: [
          XtSelectRow<String>(
            label: 'Font',
            value: fonts.uiFamily.isEmpty
                ? 'Default'
                : _familyLabel(fonts.uiFamily),
            options: _fontChoice(fonts),
            onChanged: (value) => setState(() {
              fonts.setUiFamily(value == 'Default' ? '' : _familyValue(value));
            }),
          ),
          _StepperRow(
            label: 'Text Size',
            keyPrefix: 'interface',
            value: fonts.uiSize,
            onChanged: fonts.setUiSize,
            min: 11,
            max: 22,
          ),
          _DestinationRow(
            label: 'Import font (TTF/OTF)',
            onTap: () async {
              await fonts.importFont();
              if (mounted) setState(() {});
            },
          ),
          if (fonts.error != null)
            _SettingsText(
              fonts.error!,
              color: XtColors.danger(context),
            )
          else
            const _SettingsText(
              'Imported fonts are stored in this device\'s app data.',
            ),
        ],
      ),
    ];
  }

  List<Widget> _sftpTab() => [
    _SectionCard(
      title: 'SFTP settings',
      children: [
        XtSwitchRow(
          key: const ValueKey('setting-sftp-follow'),
          label: 'Follow the terminal directory',
          description:
              'Open the file browser at the shell\'s current folder when supported',
          value: _core.sftpFollowCd,
          onChanged: (value) => _save({'sftp_follow_cd': value}),
        ),
        _PathRow(
          label: 'Download folder',
          value: _core.downloadDir.isEmpty
              ? 'Ask for a folder each time'
              : _core.downloadDir,
          onChoose: _chooseDownloadFolder,
        ),
        if (_core.downloadDir.isNotEmpty)
          _DestinationRow(
            label: 'Clear download folder',
            onTap: () => _save({'download_dir': ''}),
          ),
        const _SettingsText(
          'Downloaded files are written to this folder; the picker appears when '
          'no folder is set.',
        ),
      ],
    ),
  ];

  List<Widget> _logsTab() => [
    _SectionCard(
      title: 'Session logs',
      children: [
        XtSwitchRow(
          key: const ValueKey('setting-session-logs'),
          label: 'Save session logs',
          description:
              'Record new terminal sessions as text transcripts. Existing '
              'sessions are not recorded retroactively.',
          value: _core.sessionLogs,
          onChanged: (value) => _save({'session_logs': value}),
        ),
        const _SettingsText(
          'Transcripts are stored in the app data folder and appear in Logs, '
          'where they can be opened or deleted. Nothing is uploaded.',
        ),
      ],
    ),
    _SectionCard(
      title: 'Profile data',
      children: [
        _DestinationRow(
          key: const ValueKey('settings-export'),
          label: 'Export sessions (JSON)',
          onTap: _dataBusy ? null : _exportProfile,
        ),
        _DestinationRow(
          key: const ValueKey('settings-import'),
          label: 'Import sessions (JSON)',
          onTap: _dataBusy ? null : _importProfile,
        ),
        if (_dataStatus != null)
          _SettingsText(
            _dataStatus!,
            color: _dataError == true ? XtColors.danger(context) : null,
          )
        else
          const _SettingsText(
            'Exports carry every saved host; secrets are written in the '
            'portable encrypted form. Importing never overwrites existing '
            'sessions — new ones are appended.',
          ),
      ],
    ),
  ];

  List<Widget> _shortcutsTab() => const [
    _SectionCard(
      title: 'Keyboard shortcuts',
      children: [
        _ShortcutRow(
          keys: 'Ctrl+Shift+F',
          action: 'Search the terminal buffer',
        ),
        _ShortcutRow(
          keys: 'Ctrl+L',
          action: 'Clear the screen (sent to the shell)',
        ),
        _ShortcutRow(keys: 'Ctrl+C', action: 'Interrupt the running command'),
        _ShortcutRow(keys: 'Shift+Tab', action: 'Backtab'),
        _ShortcutRow(
          keys: 'Home / End / PgUp / PgDn',
          action: 'Move through the terminal buffer',
        ),
        _ShortcutRow(keys: 'Enter', action: 'Run the command'),
      ],
    ),
  ];

  // Font families are stored as family identifiers; show their display names.
  Map<String, String> _fontChoice(AppFonts fonts) => {
    for (final label in _fontOptions(fonts)) label: label,
  };

  List<String> _fontOptions(AppFonts fonts) => [
    'Default',
    for (final f in fonts.imported) f.name,
  ];

  String _familyLabel(String family) {
    for (final f in widget.fonts.imported) {
      if (f.family == family) return f.name;
    }
    return 'Default';
  }

  String _familyValue(String label) {
    for (final f in widget.fonts.imported) {
      if (f.name == label) return f.family;
    }
    return '';
  }
}

// ── The 220px tab sidebar ───────────────────────────────────────────────
class _TabSidebar extends StatelessWidget {
  final double width;
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onSelect;

  const _TabSidebar({
    required this.width,
    required this.tabs,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: XtColors.chrome(context),
        border: Border(right: BorderSide(color: XtColors.hairline(context))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _TabItem(
              label: AppLanguage.tr(context, tabs[i]),
              selected: i == active,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: XtHoverRow(
        selected: selected,
        onTap: onTap,
        height: 36,
        radius: XtRadius.field,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: theme.typography.normal.copyWith(
              fontSize: 13,
              color: selected
                  ? XtColors.textPrimary(context)
                  : XtColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// A read-only path with a real folder picker.
class _PathRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onChoose;

  const _PathRow({
    required this.label,
    required this.value,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLanguage.tr(context, label),
                  style: theme.typography.medium.copyWith(
                    fontSize: 13,
                    color: XtColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLanguage.tr(context, value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.normal.copyWith(
                    fontSize: 13,
                    color: XtColors.textTertiary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          XtActionButton(
            label: AppLanguage.tr(context, 'Choose…'),
            variant: XtActionVariant.secondary,
            onPressed: onChoose,
          ),
        ],
      ),
    );
  }
}

/// One accurate shortcut entry (no fake alternative key bindings).
class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String action;

  const _ShortcutRow({required this.keys, required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          XtKeyChip(label: keys),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              AppLanguage.tr(context, action),
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: XtColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card: max-width 700, 20 padding, surface fill, radius 10 ────
class _SectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _SectionCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: XtCard(
          margin: const EdgeInsets.only(top: 30),
          padding: const EdgeInsets.all(20),
          radius: XtRadius.field,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Text(
                  AppLanguage.tr(context, title!),
                  style: theme.typography.normal.copyWith(
                    fontSize: 16,
                    height: 1.75,
                    color: XtColors.textPrimary(context),
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// "Text Size" with a minus/plus pair and a centred numeric field.
class _StepperRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String keyPrefix;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLanguage.tr(context, label),
              style: theme.typography.medium.copyWith(
                fontSize: 13,
                color: XtColors.textPrimary(context),
              ),
            ),
          ),
          // The two step buttons are the shared XtIconButton, so settings and
          // the terminal tools panel cannot drift apart. Their ValueKeys stay
          // because the widget tests drive them.
          XtIconButton(
            key: ValueKey('$keyPrefix-minus'),
            icon: LucideIcons.minus,
            size: 34,
            iconSize: 14,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 51,
            child: Text(
              '${value.round()}',
              textAlign: TextAlign.center,
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: XtColors.textPrimary(context),
              ),
            ),
          ),
          XtIconButton(
            key: ValueKey('$keyPrefix-plus'),
            icon: LucideIcons.plus,
            size: 34,
            iconSize: 14,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// A destination row: label left, chevron right.
class _DestinationRow extends StatelessWidget {
  final String label;

  /// Null disables the row (shown muted, not tappable) while a long export or
  /// import runs.
  final VoidCallback? onTap;

  const _DestinationRow({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLanguage.tr(context, label),
                  style: theme.typography.medium.copyWith(
                    fontSize: 13,
                    color: onTap == null
                        ? XtColors.textDisabled(context)
                        : XtColors.textPrimary(context),
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 15,
                color: XtColors.textTertiary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SettingsText: 13px secondary body, 15px top margin.
class _SettingsText extends StatelessWidget {
  final String text;
  final Color? color;

  const _SettingsText(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Text(
        AppLanguage.tr(context, text),
        style: theme.typography.normal.copyWith(
          fontSize: 13,
          color: color ?? XtColors.textSecondary(context),
        ),
      ),
    );
  }
}
