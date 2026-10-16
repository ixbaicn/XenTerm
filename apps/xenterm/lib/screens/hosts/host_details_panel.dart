/// The host details panel: the floating card over the grid's left side,
/// sectioned the way the hosts screen sections a host (Address /
/// Credentials / General), Connect pinned at the bottom (design-tokens.md §6).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';

class HostDetailsPanel extends StatelessWidget {
  final Host host;
  final VoidCallback onClose;
  final VoidCallback onConnect;
  final VoidCallback onEditAll;

  const HostDetailsPanel({
    super.key,
    required this.host,
    required this.onClose,
    required this.onConnect,
    required this.onEditAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
        border: Border.all(color: theme.colorScheme.border),
        // Termius's overlay card sits on a soft shadow.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: what this panel is, the save state word, the way out.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('主机详情',
                      style: theme.typography.semiBold.copyWith(fontSize: 14)),
                ),
                Text('就绪',
                    style: theme.typography.normal.copyWith(
                        fontSize: 12, color: theme.colorScheme.mutedForeground)),
                const SizedBox(width: 8),
                GhostButton(
                  density: ButtonDensity.compact,
                  onPressed: onClose,
                  child: const Icon(BootstrapIcons.x, size: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: '地址',
                    children: [
                      _field(context, '标签', host.label),
                      _field(context, 'IP 或主机名', host.address),
                      _field(context, '端口', '${host.port}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: '凭据',
                    children: [
                      _field(context, '用户名', host.username),
                      _field(context, '密码', ''),
                      _field(context, '私钥路径', ''),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: '通用',
                    children: [
                      _field(context, '分组', host.group),
                      _row(context, '最近使用', host.lastUsed ?? '—'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Footer: connect is what this panel exists to make one click.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.colorScheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    onPressed: onConnect,
                    child: const Text('连接'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: onEditAll,
                  child: const Text('编辑全部…'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.typography.normal.copyWith(
                  fontSize: 11, color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 4),
          TextField(
            initialValue: value,
            style: theme.typography.normal.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: theme.typography.normal.copyWith(
                  fontSize: 11, color: theme.colorScheme.mutedForeground)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                style: theme.typography.normal.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// One section card: the uppercase 12/700 heading over its rows.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(TermiusRadius.card),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // b12wu from the typography scale: 12px/700, uppercase, 1px
          // letter-spacing (design-tokens.md §3).
          Text(
            title.toUpperCase(),
            style: theme.typography.bold.copyWith(
              fontSize: 12,
              letterSpacing: 1,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
