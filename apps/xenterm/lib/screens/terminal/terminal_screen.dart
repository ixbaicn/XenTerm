import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/app_fonts.dart';
import 'sftp_preview.dart';
import 'terminal_view.dart';

/// One connection workspace: the live terminal (or its SFTP view) on the left,
/// the tools panel on the right. Session tabs live in the title bar.
class TerminalScreen extends StatefulWidget {
  final Host host;
  final AppFonts fonts;

  /// SFTP view is toggled from the title bar's SFTP tab.
  final bool showSftp;

  const TerminalScreen({
    super.key,
    required this.host,
    required this.fonts,
    this.showSftp = false,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  @override
  void didUpdateWidget(TerminalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While the SFTP view covers the terminal, keys must not reach the hidden
    // PTY; the offstage terminal would otherwise keep primary focus.
    if (widget.showSftp && !oldWidget.showSftp) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: Offstage(
              offstage: widget.showSftp,
              child: TerminalView(host: widget.host, fonts: widget.fonts),
            ),
          ),
          if (widget.showSftp)
            Positioned.fill(child: SftpPreview(host: widget.host)),
        ],
      ),
    );
  }
}
