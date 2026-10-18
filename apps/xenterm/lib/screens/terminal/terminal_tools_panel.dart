import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/termius_theme.dart';
import '../../theme/app_fonts.dart';

enum _ToolsTab { keys, snippets, history, appearance }

/// Right-hand tools from the reference screenshots. TODO(ffi/terminal): wire
/// keys to PTY input, snippets/history to stored session data, and appearance
/// to terminal rendering preferences. These controls preview layout only.
class TerminalToolsPanel extends StatefulWidget {
  final AppFonts fonts;
  const TerminalToolsPanel({super.key, required this.fonts});

  @override
  State<TerminalToolsPanel> createState() => _TerminalToolsPanelState();
}

class _TerminalToolsPanelState extends State<TerminalToolsPanel> {
  _ToolsTab _active = _ToolsTab.keys;
  String _search = '';
  String _terminalTheme = 'Termius Dark';

  static const _snippets = [
    ('apt update', 'apt update'),
    ('apt install cockpit', 'apt install cockpit'),
    ('lsblk -f', 'lsblk -f'),
  ];
  // Representative UI-only examples; never expose real command histories.
  static const _history = [
    'cd',
    'screen -ls',
    'ps -ef',
    'locale -a',
    'ls -la',
    'pwd',
  ];
  static const _themes = [
    'Termius Dark',
    'Termius Light',
    'Flexoki Dark',
    'Flexoki Light',
    'Kanagawa Wave',
    'Kanagawa Dragon',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _tab(const _FourSquares(), _ToolsTab.keys, '快捷键'),
                _tab(
                  const Text(
                    '{}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  _ToolsTab.snippets,
                  '命令片段',
                ),
                _tab(
                  const Icon(material.Icons.history, size: 19),
                  _ToolsTab.history,
                  '历史',
                ),
                _tab(
                  const Icon(material.Icons.palette_outlined, size: 19),
                  _ToolsTab.appearance,
                  '外观',
                ),
                Container(height: 24, width: 1, color: scheme.border),
                const Icon(
                  material.Icons.keyboard_outlined,
                  size: 19,
                  color: Color(0xFF8D91A5),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_active) {
              _ToolsTab.keys => _keysView(),
              _ToolsTab.snippets => _commandsView(context, true),
              _ToolsTab.history => _commandsView(context, false),
              _ToolsTab.appearance => _appearanceView(context),
            },
          ),
        ],
      ),
    );
  }

  Widget _tab(Widget icon, _ToolsTab tab, String label) {
    final selected = _active == tab;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('terminal-${tab.name}-tab'),
        onTap: () => setState(() {
          _active = tab;
          _search = '';
        }),
        child: Tooltip(
          tooltip: (_) => Text(label),
          child: Container(
            width: 48,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF17443A) : Colors.transparent,
              borderRadius: BorderRadius.circular(TermiusRadius.card),
            ),
            child: IconTheme(
              data: IconThemeData(
                color: selected
                    ? const Color(0xFF21B568)
                    : const Color(0xFF8D91A5),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF21B568)
                      : const Color(0xFF8D91A5),
                ),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keysView() {
    const rows = <List<String>>[
      ['shift+tab', 'ctrl', 'esc'],
      ['←', '↑', '↓', '→'],
      ['ctrl+B, %', 'ctrl+B, "'],
      ['ctrl+B, O', 'ctrl+B, X'],
      ['alt', 'tab', 'ins', 'del'],
      ['home', 'pgUp', 'pgDn', 'end'],
      ['|', '\\', '?', '-'],
      ['|', ':', ';', '!'],
      ['~', '@', r'$', '*'],
      ['^', '%', '=', '`'],
      ['<', '>', '(', ')'],
      ['{', '}', '[', ']'],
      ['F1', 'F2', 'F3', 'F4'],
      ['F5', 'F6', 'F7', 'F8'],
      ['F9', 'F10', 'F11', 'F12'],
      ['^_', '^W', '^R', '^XX'],
      ['^C', '^L', '^S', '^Z'],
      ['^X', '^G', '^N', '^P'],
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
      children: [
        _keyRow(['⚙ 自定义'], height: 38),
        const SizedBox(height: 6),
        _shortcutActions(),
        for (final row in rows) _keyRow(row),
      ],
    );
  }

  Widget _shortcutActions() {
    final scheme = Theme.of(context).colorScheme;
    const icons = [
      material.Icons.auto_fix_high,
      material.Icons.key_outlined,
      material.Icons.open_with,
      material.Icons.attach_file,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (var index = 0; index < icons.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.card,
                  borderRadius: BorderRadius.circular(TermiusRadius.menu),
                ),
                child: Icon(
                  icons[index],
                  size: 17,
                  color: scheme.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _keyRow(List<String> labels, {double height = 38}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.card,
                  borderRadius: BorderRadius.circular(TermiusRadius.menu),
                ),
                child: Text(
                  labels[index],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: scheme.mutedForeground),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _commandsView(BuildContext context, bool snippets) {
    final scheme = Theme.of(context).colorScheme;
    final commands = snippets
        ? _snippets
              .where(
                (item) => item.$1.toLowerCase().contains(_search.toLowerCase()),
              )
              .map((item) => (item.$1, item.$2))
              .toList()
        : _history
              .where(
                (item) => item.toLowerCase().contains(_search.toLowerCase()),
              )
              .map((item) => (item, ''))
              .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: TextField(
            key: ValueKey(_active),
            onChanged: (value) => setState(() => _search = value),
            placeholder: const Text('搜索'),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final item in commands)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.card,
                          borderRadius: BorderRadius.circular(
                            TermiusRadius.card,
                          ),
                        ),
                        child: Icon(
                          snippets
                              ? material.Icons.code
                              : material.Icons.history,
                          size: 17,
                          color: scheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.foreground,
                              ),
                            ),
                            if (snippets)
                              Text(
                                item.$2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: scheme.mutedForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (snippets)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '＋ 添加命令片段',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _appearanceView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('字号', style: TextStyle(color: scheme.foreground)),
            ),
            _sizeButton(
              '−',
              () => widget.fonts.setTerminalSize(widget.fonts.terminalSize - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${widget.fonts.terminalSize.round()}',
                style: TextStyle(color: scheme.foreground),
              ),
            ),
            _sizeButton(
              '+',
              () => widget.fonts.setTerminalSize(widget.fonts.terminalSize + 1),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.border),
            borderRadius: BorderRadius.circular(TermiusRadius.field),
          ),
          child: Text(
            '${widget.fonts.labelFor(widget.fonts.terminalFamily)}  ▾',
            style: TextStyle(color: scheme.mutedForeground),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          '主题',
          style: TextStyle(color: scheme.mutedForeground, fontSize: 15),
        ),
        const SizedBox(height: 10),
        for (final name in _themes)
          GestureDetector(
            onTap: () => setState(() => _terminalTheme = name),
            child: Container(
              height: 68,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _terminalTheme == name
                    ? scheme.card
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(TermiusRadius.card),
              ),
              child: Row(
                children: [
                  Container(
                    width: 76,
                    height: 48,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: name.contains('Light')
                          ? const Color(0xFFE6EBED)
                          : const Color(0xFF141729),
                      borderRadius: BorderRadius.circular(TermiusRadius.menu),
                    ),
                    child: Column(
                      children: [
                        Container(height: 4, color: const Color(0xFF21B568)),
                        const SizedBox(height: 6),
                        Container(height: 4, color: const Color(0xFF21B568)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: _terminalTheme == name
                            ? const Color(0xFF21B568)
                            : scheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sizeButton(String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: BorderRadius.circular(TermiusRadius.card),
        ),
        child: Text(
          label,
          style: TextStyle(color: scheme.mutedForeground, fontSize: 22),
        ),
      ),
    );
  }
}

/// Four rounded squares match the shortcut tab glyph in the reference image.
class _FourSquares extends StatelessWidget {
  const _FourSquares();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    return SizedBox(
      width: 18,
      height: 18,
      child: Column(
        children: [
          for (var row = 0; row < 2; row++)
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < 2; column++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
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
}
