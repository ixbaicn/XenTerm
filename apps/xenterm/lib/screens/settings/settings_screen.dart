/// Settings — rebuilt to Termius's desktop settings window:
///
/// - header 80px, "Settings" 700, --dark-grey-3, 1px bottom border
/// - 220px tab sidebar (Account / Terminal / SFTP / Logs / Shortcuts) with
///   36px entries, 10px radius, selected --dark-grey-5
/// - content --dark-grey-2, centred cards max-width 700, 30px apart, 20px
///   padding, 10px radius, --card-a
/// - rows: switch items (12px/500 label + 14px secondary description),
///   dropdown values (plain text + chevron), and the Text Size stepper
///   (36px buttons around a 51px centred field) — all from the settings
///   source's own SettingsSwitch / SettingsSection / SettingsText styles.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

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

  const SettingsScreen({
    super.key,
    required this.lightTheme,
    required this.onThemeChanged,
    required this.fonts,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _tabs = [
    'Terminal',
    'SFTP',
    'Logs',
    'Shortcuts',
  ];

  int _tab = 0; // Terminal holds the functional settings.

  // Preview-only toggles (backend integration pending, as before).
  final Map<String, bool> _toggles = {
    'autoreconnect': true,
    'import_shell_history': true,
    'copy_on_select': true,
    'bell_sound': false,
    'bright_bold': false,
    'hotkeys': false,
    'custom_keyboard': false,
  };

  String _commandModifier = 'Ctrl';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: _chrome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: 80px, "Settings" 700, hairline underneath ──────────
          Container(
            height: 80,
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _hairline)),
            ),
            alignment: Alignment.topLeft,
            child: Text(
              'Settings',
              style: theme.typography.bold.copyWith(
                fontSize: 24,
                height: 45 / 24,
                color: theme.colorScheme.foreground,
              ),
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
                      children: _contentFor(_tab),
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

  // ── Tab pages ─────────────────────────────────────────────────────────

  List<Widget> _terminalTab() {
    final fonts = widget.fonts;
    return [
      _SectionCard(
        title: 'Terminal settings',
        children: [
          _SwitchRow(
            label: 'Autoreconnect',
            value: _toggles['autoreconnect']!,
            onChanged: (v) => setState(() => _toggles['autoreconnect'] = v),
          ),
          _SwitchRow(
            label: 'Import shell history',
            description:
                'Required for autocomplete and command history',
            value: _toggles['import_shell_history']!,
            onChanged: (v) =>
                setState(() => _toggles['import_shell_history'] = v),
          ),
          _SwitchRow(
            label: 'Select text to copy & Right click to paste',
            value: _toggles['copy_on_select']!,
            onChanged: (v) =>
                setState(() => _toggles['copy_on_select'] = v),
          ),
          _SwitchRow(
            label: 'Bell sound',
            value: _toggles['bell_sound']!,
            onChanged: (v) => setState(() => _toggles['bell_sound'] = v),
          ),
          _SwitchRow(
            label: 'Use bright colours for bold text',
            value: _toggles['bright_bold']!,
            onChanged: (v) => setState(() => _toggles['bright_bold'] = v),
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
            onSelected: (v) => setState(() {
              fonts.setTerminalFamily(v == 'Default' ? '' : _familyValue(v));
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
            onSelected: (v) => widget.onThemeChanged(v == 'Light'),
          ),
        ],
      ),
      _SectionCard(
        title: 'Interface',
        children: [
          _DropdownRow(
            label: 'Font',
            value: fonts.uiFamily.isEmpty ? 'Default' : _familyLabel(fonts.uiFamily),
            options: _fontOptions(fonts),
            onSelected: (v) => setState(() {
              fonts.setUiFamily(v == 'Default' ? '' : _familyValue(v));
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
          children: const [
            _SettingsText(
              'SFTP preferences (double-click behaviour, editor, downloads) '
              'arrive with the file browser.',
            ),
          ],
        ),
      ];

  List<Widget> _logsTab() => [
        _SectionCard(
          title: 'Logs',
          children: const [
            _SettingsText(
              'Session logs are not available on the current plan.',
            ),
          ],
        ),
      ];

  List<Widget> _shortcutsTab() => [
        _SectionCard(
          title: 'Keyboard shortcuts',
          children: [
            _SwitchRow(
              label: 'Keyboard shortcuts',
              value: _toggles['hotkeys']!,
              onChanged: (v) => setState(() => _toggles['hotkeys'] = v),
            ),
            _DropdownRow(
              label: 'Command modifier',
              value: _commandModifier,
              options: const ['Ctrl', 'Alt', 'Off'],
              onSelected: (v) => setState(() => _commandModifier = v),
            ),
            _SwitchRow(
              label: 'Custom keyboard',
              description: 'Pressed keys control the terminal on mobile',
              value: _toggles['custom_keyboard']!,
              onChanged: (v) =>
                  setState(() => _toggles['custom_keyboard'] = v),
            ),
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

/// MUI switch from the original: 52×32 track, 16px thumb (24px checked).
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
          width: 52,
          height: 32,
          padding: EdgeInsets.all(value ? 4 : 8),
          decoration: BoxDecoration(
            color: value ? theme.colorScheme.primary : _selected,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Align(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: TermiusMotion.micro,
              curve: TermiusMotion.easeOut,
              width: value ? 24 : 16,
              height: value ? 24 : 16,
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
                  const Icon(LucideIcons.chevronDown,
                      size: 12, color: _labelGrey),
                ],
              ),
            ),
          ),
          OverlayPortal(
            controller: _menu,
            overlayChildBuilder: _overlay,
          ),
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
                Icon(LucideIcons.check,
                    size: 14, color: theme.colorScheme.foreground),
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
              const Icon(LucideIcons.chevronRight,
                  size: 15, color: _labelGrey),
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
