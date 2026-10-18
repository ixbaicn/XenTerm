/// Settings — Termius's desktop settings window. Every control here changes a
/// real value: terminal rendering reads the core settings live, font choices are
/// persisted by [AppFonts], the SFTP download folder is used by the file browser,
/// and "Save session logs" controls the core transcript writer.
///
/// - header 80px, "Settings" 700, --dark-grey-3, 1px bottom border
/// - 220px tab sidebar (Terminal / SFTP / Logs / Shortcuts) with 36px entries
/// - content --dark-grey-2, centred cards max-width 700, 30px apart
library;

import 'package:file_selector/file_selector.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart' show CoreSettings;
import '../../terminal/core_settings.dart';
import '../../theme/app_fonts.dart';
import '../../theme/termius_theme.dart';

const _chrome = Color(0xFF282B3D); // --dark-grey-3 (header, sidebar, cards)
const _page = Color(0xFF1D2033); // --dark-grey-2 (tab content)
const _hairline = Color(0xFF141729); // --dark-grey-1 (window separators)
const _selected = Color(0xFF3E4257); // --dark-grey-5
const _hover = Color(0xFF32364A); // --dark-grey-4
const _labelGrey = Color(0xFF8D91A5); // --dark-grey-7

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
      color: _chrome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 80,
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _hairline)),
            ),
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Text(
                  'Settings',
                  style: theme.typography.bold.copyWith(
                    fontSize: 24,
                    height: 45 / 24,
                    color: theme.colorScheme.foreground,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TabSidebar(
                  tabs: _tabs,
                  active: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
                Expanded(
                  child: ColoredBox(
                    color: _page,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 60),
                      children: [
                        if (_saveError != null)
                          _SectionCard(
                            children: [
                              _SettingsText(
                                _saveError!,
                                color: theme.colorScheme.destructive,
                              ),
                            ],
                          ),
                        ..._contentFor(_tab),
                      ],
                    ),
                  ),
                ),
              ],
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
    return [
      _SectionCard(
        title: 'Terminal settings',
        children: [
          _DropdownRow(
            label: 'Cursor style',
            value: switch (core.cursorStyle) {
              'bar' => 'Bar',
              'underline' => 'Underline',
              _ => 'Block',
            },
            options: const ['Block', 'Bar', 'Underline'],
            onSelected: (value) => _save({
              'cursor_style': switch (value) {
                'Bar' => 'bar',
                'Underline' => 'underline',
                _ => 'block',
              },
            }),
          ),
          _DropdownRow(
            label: 'Line spacing',
            value: switch (core.lineSpacing) {
              <= 0.92 => 'Compact',
              >= 1.08 => 'Relaxed',
              _ => 'Normal',
            },
            options: const ['Compact', 'Normal', 'Relaxed'],
            onSelected: (value) => _save({
              'line_spacing': switch (value) {
                'Compact' => 0.85,
                'Relaxed' => 1.15,
                _ => 1.0,
              },
            }),
          ),
          _SwitchRow(
            key: const ValueKey('setting-padding'),
            label: 'Inset terminal text',
            description: 'Keep a small margin around the character grid',
            value: core.padding,
            onChanged: (value) => _save({'padding': value}),
          ),
          _SwitchRow(
            key: const ValueKey('setting-bold'),
            label: 'Use a bold face for terminal text',
            value: core.bold,
            onChanged: (value) => _save({'bold': value}),
          ),
        ],
      ),
      _SectionCard(
        children: [
          _DropdownRow(
            label: 'Font',
            value: fonts.terminalFamily.isEmpty
                ? 'Default'
                : _familyLabel(fonts.terminalFamily),
            options: _fontOptions(fonts),
            onSelected: (value) => setState(() {
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
          _DropdownRow(
            label: 'Theme',
            value: widget.lightTheme ? 'Light' : 'Dark',
            options: const ['Dark', 'Light'],
            onSelected: (value) => widget.onThemeChanged(value == 'Light'),
          ),
        ],
      ),
      _SectionCard(
        title: 'Interface',
        children: [
          _DropdownRow(
            label: 'Font',
            value: fonts.uiFamily.isEmpty
                ? 'Default'
                : _familyLabel(fonts.uiFamily),
            options: _fontOptions(fonts),
            onSelected: (value) => setState(() {
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
              color: Theme.of(context).colorScheme.destructive,
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
        _SwitchRow(
          key: const ValueKey('setting-sftp-follow'),
          label: 'Follow the terminal directory',
          description: 'Open the file browser at the shell\'s current folder when supported',
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
        _SwitchRow(
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
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onSelect;

  const _TabSidebar({
    required this.tabs,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: _chrome,
        border: Border(right: BorderSide(color: _hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _TabItem(
              label: tabs[i],
              selected: i == active,
              onTap: () => onSelect(i),
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: widget.selected
                ? _selected
                : (_hovering ? _hover : Colors.transparent),
            borderRadius: BorderRadius.circular(TermiusRadius.field),
          ),
          child: Text(
            widget.label,
            style: theme.typography.normal.copyWith(
              fontSize: 14,
              color: widget.selected
                  ? theme.colorScheme.foreground
                  : _labelGrey,
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
                  label,
                  style: theme.typography.medium.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.normal.copyWith(
                    fontSize: 13,
                    color: _labelGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Button(
            style: const ButtonStyle.outline(),
            onPressed: onChoose,
            child: const Text('Choose…'),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _selected,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              keys,
              style: theme.typography.medium.copyWith(
                fontSize: 12,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              action,
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: _labelGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card: max-width 700, 20 padding, --card-a, radius 10 ────────
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
        child: Container(
          margin: const EdgeInsets.only(top: 30),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _chrome,
            borderRadius: BorderRadius.circular(TermiusRadius.field),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: theme.typography.normal.copyWith(
                    fontSize: 16,
                    height: 1.75,
                    color: theme.colorScheme.foreground,
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

/// SettingsSwitch: 12px/500 label on the left, switch on the right, optional
/// 14px secondary description underneath; 20px top margin.
class _SwitchRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.typography.medium.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.foreground,
                  ),
                ),
              ),
              _TermiusSwitch(value: value, onChanged: onChanged),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: theme.typography.normal.copyWith(
                fontSize: 14,
                color: _labelGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One switch size for every row: 48×28 track with a constant 20px thumb.
/// (The old thumb grew from 16 to 24 when checked, which read as two
/// different controls side by side.)
class _TermiusSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TermiusSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? theme.colorScheme.primary : _selected,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row whose value is a plain text + chevron dropdown (the original's
/// filter-style value control, e.g. Autocomplete "Enabled ▾").
class _DropdownRow extends StatefulWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_DropdownRow> createState() => _DropdownRowState();
}

class _DropdownRowState extends State<_DropdownRow> {
  final OverlayPortalController _menu = OverlayPortalController();
  final LayerLink _link = LayerLink();

  void _close() => _menu.hide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: theme.typography.medium.copyWith(
                fontSize: 12,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          CompositedTransformTarget(
            link: _link,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _menu.isShowing ? _menu.hide() : _menu.show(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.value,
                    style: theme.typography.medium.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 12,
                    color: _labelGrey,
                  ),
                ],
              ),
            ),
          ),
          OverlayPortal(controller: _menu, overlayChildBuilder: _overlay),
        ],
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    return Stack(
      children: [
        // Click-out barrier.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 6),
          showWhenUnlinked: false,
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _chrome,
                borderRadius: BorderRadius.circular(TermiusRadius.field),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in widget.options)
                    _MenuOption(
                      label: option,
                      selected: option == widget.value,
                      onTap: () {
                        _close();
                        widget.onSelected(option);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuOption extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MenuOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_MenuOption> createState() => _MenuOptionState();
}

class _MenuOptionState extends State<_MenuOption> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovering ? _hover : Colors.transparent,
            borderRadius: BorderRadius.circular(TermiusRadius.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.typography.normal.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.foreground,
                  ),
                ),
              ),
              if (widget.selected)
                Icon(
                  LucideIcons.check,
                  size: 14,
                  color: theme.colorScheme.foreground,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Text Size" with the original's 36px −/+ buttons and 51px centred field.
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
              label,
              style: theme.typography.normal.copyWith(
                fontSize: 14,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          _StepButton(
            key: ValueKey('$keyPrefix-minus'),
            icon: LucideIcons.minus,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 51,
            child: Text(
              '${value.round()}',
              textAlign: TextAlign.center,
              style: theme.typography.normal.copyWith(
                fontSize: 14,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          _StepButton(
            key: ValueKey('$keyPrefix-plus'),
            icon: LucideIcons.plus,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 14,
            color: enabled ? theme.colorScheme.foreground : _labelGrey,
          ),
        ),
      ),
    );
  }
}

/// A destination row: label left, chevron right (the original's tab rows).
class _DestinationRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DestinationRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.typography.medium.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.foreground,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 15, color: _labelGrey),
            ],
          ),
        ),
      ),
    );
  }
}

/// SettingsText: 14px secondary body, 15px top margin.
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
        text,
        style: theme.typography.normal.copyWith(
          fontSize: 14,
          color: color ?? _labelGrey,
        ),
      ),
    );
  }
}
