/// The Logs screen — the original's Date/User/Host/Saved table header.
/// Session logging is not implemented yet, so the body is an honest empty
/// state. There is no plan/upgrade banner: the product has no account or
/// paid tiers (user directive), so nothing here may imply one.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Table header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 18, 34, 0),
          child: Row(
            children: [
              _headerCell(context, 'Date',
                  trailing: LucideIcons.chevronDown, width: 170),
              _headerCell(context, 'User', width: 320),
              _headerCell(context, 'Host', width: 260),
              _headerCell(context, 'Saved',
                  trailing: LucideIcons.bookmark),
            ],
          ),
        ),
        // ── Empty state (no logs are recorded yet) ──────────────────────
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.scrollText,
                    size: 30, color: theme.colorScheme.mutedForeground),
                const SizedBox(height: 10),
                Text('No session logs yet',
                    style: theme.typography.semiBold.copyWith(
                        fontSize: 15, color: theme.colorScheme.foreground)),
                const SizedBox(height: 4),
                Text('Session logging arrives with the terminal stream.',
                    style: theme.typography.normal.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.mutedForeground)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(BuildContext context, String text,
      {IconData? trailing, double? width}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: theme.typography.normal.copyWith(
                  fontSize: 14, color: theme.colorScheme.foreground)),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Icon(trailing,
                size: 12, color: theme.colorScheme.mutedForeground),
          ],
        ],
      ),
    );
  }
}
