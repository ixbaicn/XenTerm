/// The Snippets screen — the original's toolbar ([+ New snippet][▾], group
/// ghost action, right icon group) over snippet cards: script chip + name +
/// one-line command preview (design-tokens.md entity patterns).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';

class _Snippet {
  final String name;
  final String group;
  final String command;

  const _Snippet(this.name, this.group, this.command);
}

const _snippets = <_Snippet>[
  _Snippet('清理磁盘', '运维', 'df -h && sudo apt clean'),
  _Snippet('Nginx 重载', '运维', 'sudo systemctl reload nginx'),
  _Snippet('Docker 清理', '容器', 'docker system prune -af'),
  _Snippet('查端口占用', '诊断', 'ss -tulpn | grep LISTEN'),
];

class SnippetsScreen extends StatelessWidget {
  const SnippetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const SplitButton(
                  label: '新建快捷命令', icon: BootstrapIcons.plus),
              const SizedBox(width: 20),
              const GhostAction(
                  icon: BootstrapIcons.collection, label: '分组管理'),
              const Spacer(),
              const Row(children: [
                IconToggleButton(icon: BootstrapIcons.search),
                SizedBox(width: 6),
                IconToggleButton(icon: BootstrapIcons.list),
              ]),
            ],
          ),
        ),
        const SectionTitle(text: '快捷命令'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              for (final snippet in _snippets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SnippetCard(snippet: snippet),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SnippetCard extends StatelessWidget {
  final _Snippet snippet;

  const _SnippetCard({required this.snippet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.popover,
              borderRadius: BorderRadius.circular(TermiusRadius.card),
            ),
            child: Icon(BootstrapIcons.terminal,
                size: 18, color: theme.colorScheme.mutedForeground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(snippet.name,
                        style: theme.typography.medium.copyWith(
                            fontSize: 15)),
                    const SizedBox(width: 8),
                    if (snippet.group.isNotEmpty)
                      Text(snippet.group,
                          style: theme.typography.normal.copyWith(
                              fontSize: 12,
                              color: theme.colorScheme.mutedForeground)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(snippet.command,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.normal.copyWith(
                        fontSize: 13,
                        fontFamily: 'GeistMono',
                        color: theme.colorScheme.mutedForeground)),
              ],
            ),
          ),
          // Send-to-terminal action, revealed per the original's hover.
          Icon(BootstrapIcons.send,
              size: 15, color: theme.colorScheme.mutedForeground),
        ],
      ),
    );
  }
}
