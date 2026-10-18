import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/app_fonts.dart';
import '../../theme/termius_theme.dart';

/// The desktop terminal's right-hand tools: live search over the visible
/// buffer, session status, font size, and real actions on the running PTY.
/// No placeholder controls — everything here acts on the live session.
class TerminalToolsPanel extends StatelessWidget {
  final AppFonts fonts;
  final Map<String, dynamic>? screen;
  final String search;
  final FocusNode? searchFocus;
  final int matchCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  final VoidCallback onReconnect;

  const TerminalToolsPanel({
    super.key,
    required this.fonts,
    required this.screen,
    required this.search,
    this.searchFocus,
    required this.matchCount,
    required this.onSearch,
    required this.onClear,
    required this.onCopy,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final closed = screen?['closed'] != null;
    final status = closed
        ? 'Disconnected'
        : (screen == null ? 'Connecting…' : 'Connected');
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1D2033),
        border: Border(left: BorderSide(color: Color(0xFF262A3D))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('terminal-search'),
            focusNode: searchFocus,
            onChanged: onSearch,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF282B3D),
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            placeholder: const Text(
              'Search terminal',
              style: TextStyle(fontSize: 13, color: Color(0xFF8D91A5)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            search.trim().isEmpty
                ? 'Ctrl+Shift+F'
                : '$matchCount match${matchCount == 1 ? '' : 'es'} in view',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6E7388)),
          ),
          const SizedBox(height: 18),
          const _PanelLabel('SESSION'),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: closed
                      ? const Color(0xFFE5484D)
                      : const Color(0xFF21B568),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(fontSize: 13, color: scheme.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _PanelLabel('TERMINAL'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Font size',
                  style: TextStyle(fontSize: 13, color: Color(0xFFC7CBD6)),
                ),
              ),
              _StepButton(
                key: const ValueKey('terminal-size-down'),
                label: '−',
                onTap: () => fonts.setTerminalSize(fonts.terminalSize - 1),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${fonts.terminalSize.round()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: scheme.foreground),
                ),
              ),
              _StepButton(
                key: const ValueKey('terminal-size-up'),
                label: '+',
                onTap: () => fonts.setTerminalSize(fonts.terminalSize + 1),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PanelAction(
                  icon: LucideIcons.copy,
                  label: 'Copy',
                  onTap: onCopy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PanelAction(
                  icon: LucideIcons.eraser,
                  label: 'Clear',
                  onTap: onClear,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PanelAction(
            icon: LucideIcons.refreshCw,
            label: 'Reconnect',
            onTap: onReconnect,
          ),
        ],
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  final String text;
  const _PanelLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: Color(0xFF6E7388),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _StepButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF282B3D),
          borderRadius: BorderRadius.circular(TermiusRadius.menu),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, color: Color(0xFFC7CBD6)),
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PanelAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF282B3D),
          borderRadius: BorderRadius.circular(TermiusRadius.menu),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFC7CBD6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFC7CBD6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies the visible terminal text to the clipboard (no scrollback yet).
Future<void> copyScreenText(Map<String, dynamic>? screen) async {
  final rows = (screen?['rows'] as List?) ?? const [];
  final text = rows
      .map(
        (row) => ((row as Map<String, dynamic>)['text'] as String? ?? '')
            .replaceFirst(RegExp(r' +$'), ''),
      )
      .join('\n')
      .replaceFirst(RegExp(r'\n+$'), '\n');
  await Clipboard.setData(ClipboardData(text: text));
}
