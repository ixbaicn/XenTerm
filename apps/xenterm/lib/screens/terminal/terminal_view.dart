/// The live terminal pane: a rio-vt screen streamed from the Rust core over
/// the FFI bridge, painted as styled runs, with real key input, resize, prompt
/// handling (host key / credentials / MFA) and a reconnect action.
///
/// The bridge exposes a cheap version counter, so the pane polls at 20 fps and
/// only pays for a snapshot when the screen actually changed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../data/hosts.dart';
import '../../theme/app_fonts.dart';
import '../../terminal/terminal_command_bus.dart';
import '../../theme/termius_theme.dart';
import 'terminal_tools_panel.dart';

/// Concrete monospace families, in preference order. The generic `monospace`
/// family does not resolve on Windows (Flutter falls back to Segoe UI, a
/// proportional face), so the default is chosen per platform.
const _terminalFallbacks = <String>[
  'Cascadia Mono',
  'Consolas',
  'Courier New',
  'monospace',
];

String _terminalFontFamily(AppFonts fonts) {
  if (fonts.terminalFamily.isNotEmpty) return fonts.terminalFamily;
  if (Platform.isWindows) return 'Consolas';
  if (Platform.isMacOS) return 'Menlo';
  return 'DejaVu Sans Mono';
}

class TerminalView extends StatefulWidget {
  final Host host;
  final AppFonts fonts;
  final TerminalCommandBus? commandBus;

  const TerminalView({
    super.key,
    required this.host,
    required this.fonts,
    this.commandBus,
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  NativeBridge? _bridge;
  int? _handle;
  Timer? _poll;
  Map<String, dynamic>? _screen;
  String? _error;
  bool _closed = false;
  bool _starting = true;
  int _lastVersion = 0;
  int _cols = 0;
  int _rows = 0;
  String _search = '';
  int _lastCommand = 0;
  final FocusNode _focus = FocusNode(debugLabel: 'terminal');

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_globalKey);
    widget.commandBus?.addListener(_onCommand);
    _start();
  }

  Future<void> _start() async {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      setState(() {
        _error = 'xenterm_bridge library not found next to the app';
        _starting = false;
      });
      return;
    }
    _bridge = bridge;
    try {
      final handle = bridge.startSession(widget.host.id, 80, 24);
      if (!mounted) {
        bridge.closeSession(handle);
        return;
      }
      setState(() {
        _handle = handle;
        _starting = false;
        _error = null;
        _closed = false;
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
      _tick();
      _focus.requestFocus();
    } catch (error) {
      setState(() {
        _error = error is NativeBridgeError ? error.message : '$error';
        _starting = false;
      });
    }
  }

  void _tick() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) return;
    final version = bridge.sessionVersion(handle);
    if (version == _lastVersion) return;
    _lastVersion = version;
    final raw = bridge.sessionSnapshot(handle);
    if (raw == null) return;
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _screen = parsed;
      _closed = parsed['closed'] != null;
    });
  }

  void _reconnect() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge != null && handle != null) bridge.closeSession(handle);
    _poll?.cancel();
    setState(() {
      _handle = null;
      _screen = null;
      _closed = false;
      _starting = true;
      _lastVersion = 0;
    });
    _start();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandBus != widget.commandBus) {
      oldWidget.commandBus?.removeListener(_onCommand);
      widget.commandBus?.addListener(_onCommand);
    }
  }

  /// Runs a snippet/command link in this PTY. The bus carries the target host
  /// id, so background tabs never run another tab's command.
  void _onCommand() {
    final bus = widget.commandBus;
    final command = bus?.last;
    if (bus == null || command == null) return;
    if (command.hostId != widget.host.id) return;
    if (bus.sequence == _lastCommand) return;
    _lastCommand = bus.sequence;
    _send([
      ...utf8.encode(command.text),
      if (command.sendEnter) 13,
    ]);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    widget.commandBus?.removeListener(_onCommand);
    HardwareKeyboard.instance.removeHandler(_globalKey);
    _poll?.cancel();
    final handle = _handle;
    if (handle != null) _bridge?.closeSession(handle);
    _focus.dispose();
    super.dispose();
  }

  void _send(List<int> bytes) {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge != null && handle != null) {
      bridge.sendInput(handle, Uint8List.fromList(bytes));
    }
  }

  void _resize(int cols, int rows) {
    if (cols == _cols && rows == _rows) return;
    _cols = cols;
    _rows = rows;
    final bridge = _bridge;
    final handle = _handle;
    if (bridge != null && handle != null) {
      bridge.resizeSession(handle, cols, rows);
    }
  }

  /// Terminal input is captured by a global hardware-key handler gated on this
  /// pane's primary focus, so other shortcuts never fire mid-terminal and the
  /// encoding does not depend on the focus chain's event dispatch.
  bool _globalKey(KeyEvent event) {
    if (!_focus.hasPrimaryFocus) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final bytes = _encodeKey(event, _screen?['applicationCursor'] == true);
    if (bytes.isNotEmpty) _send(bytes);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = _terminalFontFamily(widget.fonts);
    final fontSize = widget.fonts.terminalSize;
    // Measure the cell with the SAME style the painter uses. 'monospace' is
    // not a real Windows family — Flutter silently falls back to Segoe UI,
    // which is proportional and makes cells drift away from the glyphs.
    final cellStyle = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: _terminalFallbacks,
      fontSize: fontSize,
      height: 1,
    );
    final measure = TextPainter(
      text: TextSpan(text: 'M' * 10, style: cellStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final cellWidth = measure.width / 10;
    final lineHeight = fontSize * 1.25;

    return Row(
      children: [
        Expanded(
          child: Container(
            key: const ValueKey('terminal-view'),
            color: const Color(0xFF141729),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cols = ((constraints.maxWidth - 24) / cellWidth)
                    .floor()
                    .clamp(2, 1000);
                final rows = ((constraints.maxHeight - 24) / lineHeight)
                    .floor()
                    .clamp(2, 1000);
                _resize(cols, rows);
                return Focus(
                  focusNode: _focus,
                  autofocus: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _focus.requestFocus,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CustomPaint(
                              painter: _TerminalPainter(
                                screen: _screen,
                                search: _search,
                                fontFamily: fontFamily,
                                fontSize: fontSize,
                                cellWidth: cellWidth,
                                lineHeight: lineHeight,
                              ),
                            ),
                          ),
                        ),
                        if (_starting)
                          const Center(
                            child: Text(
                              'Connecting…',
                              style: TextStyle(color: Color(0xFF8D91A5)),
                            ),
                          ),
                        if (_error != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Terminal unavailable\n$_error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF8D91A5),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        if (_closed && _error == null)
                          Center(
                            child: _StatusCard(
                              title: 'Disconnected',
                              detail: '${_screen?['closed'] ?? ''}',
                              actionLabel: 'Reconnect',
                              onAction: _reconnect,
                            ),
                          ),
                        if (_screen?['prompt'] != null && !_closed)
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 12,
                            child: _PromptBanner(
                              prompt:
                                  _screen!['prompt'] as Map<String, dynamic>,
                              onAnswer: (accept, {username, password, text}) {
                                final bridge = _bridge;
                                final handle = _handle;
                                if (bridge == null || handle == null) return;
                                bridge.answerPrompt(
                                  handle,
                                  (promptIdOf(_screen!)),
                                  accept: accept,
                                  username: username,
                                  password: password,
                                  text: text,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(
          width: 300,
          child: TerminalToolsPanel(
            fonts: widget.fonts,
            screen: _screen,
            search: _search,
            matchCount: _matchCount(),
            onSearch: (value) => setState(() => _search = value),
            onClear: () {
              _send(const [0x0c]);
              _focus.requestFocus();
            },
            onCopy: () async {
              await copyScreenText(_screen);
              _focus.requestFocus();
            },
            onReconnect: _reconnect,
          ),
        ),
      ],
    );
  }

  int _matchCount() {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return 0;
    final rows = (_screen?['rows'] as List?) ?? const [];
    var count = 0;
    for (final entry in rows) {
      final text = ((entry as Map<String, dynamic>)['text'] as String? ?? '')
          .toLowerCase();
      var index = 0;
      while ((index = text.indexOf(query, index)) != -1) {
        count++;
        index += query.length;
      }
    }
    return count;
  }
}

int promptIdOf(Map<String, dynamic> screen) {
  final prompt = screen['prompt'] as Map<String, dynamic>?;
  return (prompt?['id'] as num?)?.toInt() ?? 0;
}

/// Encodes one key event into the bytes a PTY expects (xterm conventions).
List<int> _encodeKey(KeyEvent event, bool applicationCursor) {
  final ctrl = HardwareKeyboard.instance.isControlPressed;
  final alt = HardwareKeyboard.instance.isAltPressed;
  final key = event.logicalKey;

  List<int>? bytes;
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    bytes = [13];
  } else if (key == LogicalKeyboardKey.backspace) {
    bytes = [127];
  } else if (key == LogicalKeyboardKey.tab) {
    bytes = HardwareKeyboard.instance.isShiftPressed ? [27, 91, 90] : [9];
  } else if (key == LogicalKeyboardKey.escape) {
    bytes = [27];
  } else if (key == LogicalKeyboardKey.arrowUp) {
    bytes = applicationCursor ? [27, 79, 65] : [27, 91, 65];
  } else if (key == LogicalKeyboardKey.arrowDown) {
    bytes = applicationCursor ? [27, 79, 66] : [27, 91, 66];
  } else if (key == LogicalKeyboardKey.arrowRight) {
    bytes = applicationCursor ? [27, 79, 67] : [27, 91, 67];
  } else if (key == LogicalKeyboardKey.arrowLeft) {
    bytes = applicationCursor ? [27, 79, 68] : [27, 91, 68];
  } else if (key == LogicalKeyboardKey.home) {
    bytes = applicationCursor ? [27, 79, 72] : [27, 91, 72];
  } else if (key == LogicalKeyboardKey.end) {
    bytes = applicationCursor ? [27, 79, 70] : [27, 91, 70];
  } else if (key == LogicalKeyboardKey.insert) {
    bytes = [27, 91, 50, 126];
  } else if (key == LogicalKeyboardKey.delete) {
    bytes = [27, 91, 51, 126];
  } else if (key == LogicalKeyboardKey.pageUp) {
    bytes = [27, 91, 53, 126];
  } else if (key == LogicalKeyboardKey.pageDown) {
    bytes = [27, 91, 54, 126];
  } else if (key == LogicalKeyboardKey.f1) {
    bytes = [27, 79, 80];
  } else if (key == LogicalKeyboardKey.f2) {
    bytes = [27, 79, 81];
  } else if (key == LogicalKeyboardKey.f3) {
    bytes = [27, 79, 82];
  } else if (key == LogicalKeyboardKey.f4) {
    bytes = [27, 79, 83];
  } else if (key == LogicalKeyboardKey.f5) {
    bytes = [27, 91, 49, 53, 126];
  } else if (key == LogicalKeyboardKey.f6) {
    bytes = [27, 91, 49, 55, 126];
  } else if (key == LogicalKeyboardKey.f7) {
    bytes = [27, 91, 49, 56, 126];
  } else if (key == LogicalKeyboardKey.f8) {
    bytes = [27, 91, 49, 57, 126];
  } else if (key == LogicalKeyboardKey.f9) {
    bytes = [27, 91, 50, 48, 126];
  } else if (key == LogicalKeyboardKey.f10) {
    bytes = [27, 91, 50, 49, 126];
  } else if (key == LogicalKeyboardKey.f11) {
    bytes = [27, 91, 50, 51, 126];
  } else if (key == LogicalKeyboardKey.f12) {
    bytes = [27, 91, 50, 52, 126];
  } else {
    var character = event.character;
    if (character == null || character.isEmpty) {
      // Some input paths (and injected key messages) carry no character; fall
      // back to the key label so typing still reaches the PTY.
      final label = key.keyLabel;
      if (label.length == 1) {
        final letter = label.toLowerCase();
        character = letter != label && !HardwareKeyboard.instance.isShiftPressed
            ? letter
            : label;
      }
    }
    if (character != null && character.isNotEmpty) {
      if (ctrl) {
        final code = character.toLowerCase().codeUnitAt(0);
        if (code >= 97 && code <= 122) {
          bytes = [code - 96];
        } else if (character == '@') {
          bytes = [0];
        } else if (character == '[') {
          bytes = [27];
        } else if (character == r'\') {
          bytes = [28];
        } else if (character == ']') {
          bytes = [29];
        } else if (character == '^') {
          bytes = [30];
        } else if (character == '_') {
          bytes = [31];
        } else if (character == '?') {
          bytes = [127];
        }
      }
      bytes ??= utf8.encode(character);
    }
  }
  if (bytes != null && alt && bytes.length == 1 && bytes.first >= 32) {
    return [27, ...bytes];
  }
  return bytes ?? const [];
}

class _TerminalPainter extends CustomPainter {
  final Map<String, dynamic>? screen;
  final String search;
  final String fontFamily;
  final double fontSize;
  final double cellWidth;
  final double lineHeight;

  _TerminalPainter({
    required this.screen,
    required this.search,
    required this.fontFamily,
    required this.fontSize,
    required this.cellWidth,
    required this.lineHeight,
  });

  static const _defaultFg = Color(0xFFD5DDE0);
  static const _defaultBg = Color(0xFF141729);
  static const _cursorColor = Color(0xFF21B568);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _defaultBg);
    final query = search.trim().toLowerCase();
    final rows = (screen?['rows'] as List?) ?? const [];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex] as Map<String, dynamic>;
      final runs = (row['runs'] as List?) ?? const [];
      if (query.isNotEmpty) {
        _highlightMatches(canvas, rowIndex, row, query);
      }
      var x = 0.0;
      for (final entry in runs) {
        final run = entry as Map<String, dynamic>;
        final cells = (run['c'] as num?)?.toInt() ?? 0;
        final style = (run['s'] as Map<String, dynamic>?) ?? const {};
        final width = cells * cellWidth;
        var fg = _color(style['fg'], _defaultFg);
        var bg = _color(style['bg'], null);
        if (style['i'] == true) {
          final previous = fg;
          fg = bg ?? _defaultBg;
          bg = previous;
        }
        if (bg != null && bg.a > 0) {
          canvas.drawRect(
            Rect.fromLTWH(x, rowIndex * lineHeight, width, lineHeight),
            Paint()..color = bg,
          );
        }
        final text = (run['t'] as String?) ?? '';
        if (text.isNotEmpty) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: _terminalFallbacks,
                fontSize: fontSize,
                height: 1,
                color: fg,
                fontWeight: style['b'] == true
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          painter.paint(
            canvas,
            Offset(
              x,
              rowIndex * lineHeight + (lineHeight - painter.height) / 2,
            ),
          );
        }
        x += width;
      }
    }
    final cursor = screen?['cursor'] as List?;
    if (cursor != null && screen?['cursorHidden'] != true) {
      final row = (cursor[0] as num).toInt();
      final col = (cursor[1] as num).toInt();
      canvas.drawRect(
        Rect.fromLTWH(col * cellWidth, row * lineHeight, cellWidth, lineHeight),
        Paint()..color = _cursorColor,
      );
    }
  }

  void _highlightMatches(
    Canvas canvas,
    int rowIndex,
    Map<String, dynamic> row,
    String query,
  ) {
    final text = ((row['text'] as String?) ?? '').toLowerCase();
    final paint = Paint()..color = const Color(0x5521B568);
    var index = 0;
    while ((index = text.indexOf(query, index)) != -1) {
      canvas.drawRect(
        Rect.fromLTWH(
          index * cellWidth,
          rowIndex * lineHeight,
          query.length * cellWidth,
          lineHeight,
        ),
        paint,
      );
      index += query.length;
    }
  }

  Color? _color(dynamic value, Color? fallback) {
    if (value == null) return fallback;
    if (value is Map) {
      final rgb = value['rgb'];
      if (rgb is List && rgb.length >= 3) {
        return Color.fromARGB(
          255,
          (rgb[0] as num).toInt(),
          (rgb[1] as num).toInt(),
          (rgb[2] as num).toInt(),
        );
      }
      final index = value['idx'];
      if (index is num) return _ansiPalette[index.toInt() % 256];
    }
    return fallback;
  }

  @override
  bool shouldRepaint(_TerminalPainter oldDelegate) =>
      oldDelegate.screen != screen ||
      oldDelegate.search != search ||
      oldDelegate.fontFamily != fontFamily ||
      oldDelegate.fontSize != fontSize;

  static final List<Color> _ansiPalette = _buildPalette();

  static List<Color> _buildPalette() {
    const base = <int>[
      0xFF000000,
      0xFFCD3131,
      0xFF0DBC79,
      0xFFE5E510,
      0xFF2472C8,
      0xFFBC3FBC,
      0xFF11A8CD,
      0xFFE5E5E5,
      0xFF666666,
      0xFFF14C4C,
      0xFF23D18B,
      0xFFF5F543,
      0xFF3B8EEA,
      0xFFD670D6,
      0xFF29B8DB,
      0xFFE5E5E5,
    ];
    final palette = <Color>[for (final v in base) Color(v)];
    const steps = <int>[0, 95, 135, 175, 215, 255];
    for (final r in steps) {
      for (final g in steps) {
        for (final b in steps) {
          palette.add(Color.fromARGB(255, r, g, b));
        }
      }
    }
    for (var i = 0; i < 24; i++) {
      final level = 8 + i * 10;
      palette.add(Color.fromARGB(255, level, level, level));
    }
    return palette;
  }
}

/// The blocking connect-time prompt (host key / credentials / MFA) as a banner
/// over the terminal — the answer goes back through the bridge to the paused
/// auth flow.
class _PromptBanner extends StatefulWidget {
  final Map<String, dynamic> prompt;
  final void Function(
    bool accept, {
    String? username,
    String? password,
    String? text,
  })
  onAnswer;

  const _PromptBanner({required this.prompt, required this.onAnswer});

  @override
  State<_PromptBanner> createState() => _PromptBannerState();
}

class _PromptBannerState extends State<_PromptBanner> {
  late final TextEditingController _user = TextEditingController(
    text: '${widget.prompt['user'] ?? ''}',
  );
  final TextEditingController _password = TextEditingController();
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = widget.prompt['kind'] as String?;
    final fields = <Widget>[];
    if (kind == 'host_key') {
      fields.add(
        Text(
          widget.prompt['changed'] == true
              ? 'Host key CHANGED for ${widget.prompt['host']}:${widget.prompt['port']} — possible MITM.'
              : 'Unknown host key for ${widget.prompt['host']}:${widget.prompt['port']}',
          style: theme.typography.medium.copyWith(fontSize: 13),
        ),
      );
      fields.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${widget.prompt['key_type']}  ${widget.prompt['fingerprint']}',
            style: theme.typography.normal.copyWith(
              fontSize: 12,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ),
      );
    } else if (kind == 'credential') {
      final needUser = widget.prompt['need_user'] == true;
      if (needUser) {
        fields.add(_promptField(_user, 'Username'));
      }
      if (widget.prompt['need_password'] == true) {
        fields.add(_promptField(_password, 'Password', obscure: true));
      }
    } else {
      fields.add(
        Text(
          '${widget.prompt['prompt'] ?? 'Verification code'}',
          style: theme.typography.medium.copyWith(fontSize: 13),
        ),
      );
      fields.add(
        _promptField(_text, 'Code', obscure: widget.prompt['echo'] == false),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF282B3D),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...fields,
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => widget.onAnswer(false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Button(
                style: const ButtonStyle.primary(),
                onPressed: () => widget.onAnswer(
                  true,
                  username: _user.text,
                  password: _password.text,
                  text: _text.text,
                ),
                child: Text(kind == 'host_key' ? 'Trust' : 'Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _promptField(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1D2033),
          borderRadius: BorderRadius.circular(TermiusRadius.field),
        ),
        placeholder: Text(hint, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  const _StatusCard({
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF282B3D),
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.typography.semiBold.copyWith(
              fontSize: 14,
              color: theme.colorScheme.foreground,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.typography.normal.copyWith(
                fontSize: 12,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Button(
            style: const ButtonStyle.primary(),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
