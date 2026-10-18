/// The Logs screen — the original's plan banner ("Logs are not available on
/// your current plan. Upgrade"), the Date/User/Host/Saved table header, and
/// session rows: date + time range, green user avatar + email + machine,
/// host chip + name + detail, bookmark icon.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';
import '../hosts/host_card.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = kSampleHosts.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Plan banner ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF282B3D), // --dark-grey-3 card
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Logs are not available on your current plan.',
                      style: theme.typography.normal.copyWith(
                          fontSize: 14, color: theme.colorScheme.foreground)),
                ),
                const SizedBox(width: 12),
                GhostButton(
                  density: ButtonDensity.compact,
                  onPressed: () {},
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Upgrade',
                          style: theme.typography.normal.copyWith(
                              fontSize: 13,
                              color: theme.colorScheme.foreground)),
                      const SizedBox(width: 6),
                      const Icon(BootstrapIcons.arrowUpCircle,
                          size: 13, color: Color(0xFF8D91A5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Table header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 18, 34, 0),
          child: Row(
            children: [
              _headerCell(context, 'Date',
                  trailing: BootstrapIcons.chevronDown, width: 170),
              _headerCell(context, 'User', width: 320),
              _headerCell(context, 'Host', width: 260),
              _headerCell(context, 'Saved',
                  trailing: BootstrapIcons.bookmark),
            ],
          ),
        ),
        // ── Rows: separate cards, 10px apart (the Termius list language) ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            itemCount: 3,
            itemBuilder: (context, index) {
              const dates = [
                ('2025年8月1日', '09:36 - 09:49'),
                ('2025年7月13日', '17:33 - 17:38'),
                ('2025年7月10日', '14:10 - 15:09'),
              ];
              final d = dates[index];
              return _LogRow(
                date: d.$1,
                time: d.$2,
                user: 'baizhanwl@qq.com',
                machine: 'DESKTOP-PKS43FI',
                hostLabel: host.label,
                hostDetail: 'ssh, root, 阿里云',
                os: host.os,
              );
            },
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

class _LogRow extends StatelessWidget {
  final String date;
  final String time;
  final String user;
  final String machine;
  final String hostLabel;
  final String hostDetail;
  final HostOs os;

  const _LogRow({
    required this.date,
    required this.time,
    required this.user,
    required this.machine,
    required this.hostLabel,
    required this.hostDetail,
    required this.os,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF282B3D), // --dark-grey-3 card
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: theme.typography.medium.copyWith(fontSize: 14)),
                Text(time,
                    style: theme.typography.normal.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.mutedForeground)),
              ],
            ),
          ),
          SizedBox(
            width: 320,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8BC34A),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('B',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user,
                        style: theme.typography.medium.copyWith(
                            fontSize: 14)),
                    Text(machine,
                        style: theme.typography.normal.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: osChipFor(os).fill,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(osChipFor(os).glyph,
                      size: 17, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hostLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.medium.copyWith(
                            fontSize: 14)),
                    Text(hostDetail,
                        style: theme.typography.normal.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground)),
                  ],
                ),
              ],
            ),
          ),
          Icon(BootstrapIcons.bookmark,
              size: 15, color: theme.colorScheme.mutedForeground),
        ],
      ),
    );
  }
}
