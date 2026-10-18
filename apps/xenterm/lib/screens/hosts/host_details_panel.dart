/// The host details drawer — the original's right panel, faithful to the
/// screenshots: header (title / ⋯ / →|), the Personal vault selector, the
/// sections (地址 with the OS icon INSIDE the outlined field, 通用 with
/// icon-bearing fields + the backspace row, 共享此主机, SSH on [port] 端口,
/// 凭据), and the Connect bar pinned at the bottom.
///
/// Field style: OUTLINED — a 1px border on a `--background` fill, radius 10 —
/// not the filled blocks the search field uses. Icons sit inside the field's
/// left edge; the backspace row carries its right-aligned "默认" value.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';

/// The drawer's outlined input. [leading] and [leadingWidget] render INSIDE
/// the field container; [trailing] right-aligns a muted value (退格键 → 默认).
class _DrawerField extends StatelessWidget {
  final String placeholder;
  final String? initialValue;
  final IconData? leading;
  final Widget? leadingWidget;
  final String? trailing;

  const _DrawerField({
    required this.placeholder,
    this.initialValue,
    this.leading,
    this.leadingWidget,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 6, right: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: [
          if (leadingWidget != null) ...[
            leadingWidget!,
            const SizedBox(width: 8),
          ] else if (leading != null) ...[
            Icon(leading, size: 14, color: theme.colorScheme.mutedForeground),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              initialValue: initialValue,
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(TermiusRadius.field),
              ),
              placeholder: Text(
                placeholder,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              style: theme.typography.normal.copyWith(
                fontSize: 14,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}

/// The pink OS chip that lives inside the address field's left edge.
class _OsChip extends StatelessWidget {
  const _OsChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFD70A53),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        BootstrapIcons.lightningChargeFill,
        size: 14,
        color: Colors.white,
      ),
    );
  }
}

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
    return Column(
      children: [
        _Header(onClose: onClose),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _VaultSelector(name: 'Personal'),
                const SizedBox(height: 16),
                _Section(
                  title: '地址',
                  child: _DrawerField(
                    initialValue: host.address,
                    placeholder: 'IP 或主机名',
                    leadingWidget: const _OsChip(),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: '通用',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DrawerField(
                        initialValue: host.label,
                        placeholder: '标签',
                      ),
                      const SizedBox(height: 10),
                      const _DrawerField(
                        placeholder: '父分组',
                        leading: BootstrapIcons.collection,
                      ),
                      const SizedBox(height: 10),
                      const _DrawerField(
                        placeholder: '标签',
                        leading: BootstrapIcons.tag,
                      ),
                      const SizedBox(height: 10),
                      const _DrawerField(
                        placeholder: '退格键',
                        leading: BootstrapIcons.keyboard,
                        trailing: '默认',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 共享此主机 — a full-width outlined row, text left, people
                // icon right, exactly the original's share affordance.
                _OutlinedRow(
                  onPressed: onEditAll,
                  child: Row(
                    children: [
                      Text(
                        '共享此主机',
                        style: theme.typography.normal.copyWith(
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        BootstrapIcons.peopleFill,
                        size: 15,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // SSH on [port] 端口 — the inline port row.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Text(
                        'SSH on',
                        style: theme.typography.normal.copyWith(
                          fontSize: 15,
                          color: theme.colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DrawerField(
                          initialValue: '${host.port}',
                          placeholder: '22',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '端口',
                        style: theme.typography.normal.copyWith(
                          fontSize: 15,
                          color: theme.colorScheme.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: '凭据',
                  child: _DrawerField(
                    initialValue: host.username,
                    placeholder: '用户名',
                    leading: BootstrapIcons.person,
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Connect bar, pinned to the drawer's bottom ────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.background,
            border: Border(
              top: BorderSide(color: theme.colorScheme.border),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: onConnect,
              child: const Text('连接'),
            ),
          ),
        ),
      ],
    );
  }
}

/// The panel header: title left, ⋯ and the →| collapse at right.
class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '主机详情',
              style: theme.typography.semiBold.copyWith(
                fontSize: 16,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () {},
            child: const Icon(
              BootstrapIcons.threeDots,
              size: 14,
              color: Color(0xFF8D91A5),
            ),
          ),
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: onClose,
            child: const Icon(
              BootstrapIcons.boxArrowRight,
              size: 14,
              color: Color(0xFF8D91A5),
            ),
          ),
        ],
      ),
    );
  }
}

/// The vault selector: vault glyph, name, chevron — one quiet row, no card.
class _VaultSelector extends StatelessWidget {
  final String name;

  const _VaultSelector({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Icon(
            BootstrapIcons.viewStacked,
            size: 15,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: theme.typography.normal.copyWith(
                fontSize: 14,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
          Icon(
            BootstrapIcons.chevronDown,
            size: 13,
            color: theme.colorScheme.mutedForeground,
          ),
        ],
      ),
    );
  }
}

/// One section: popover ground, radius 8, 15/20 padding, a 14px/500 title in
/// normal case — the original's titleSection, with content below.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.popover,
        borderRadius: BorderRadius.circular(TermiusRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.typography.medium.copyWith(
              fontSize: 14,
              color: theme.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// The full-width outlined action row (共享此主机).
class _OutlinedRow extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _OutlinedRow({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TermiusRadius.field),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: child,
      ),
    );
  }
}
