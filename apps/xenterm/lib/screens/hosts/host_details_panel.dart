/// The host details panel — Termius's floating editor card, faithful to its
/// extracted styles (HostsScreenSidebar chunk):
///
/// - header: "..." / title / save-state / close
/// - sections: cards on --card, padding 15px 20px, titles 14px/500 (NOT
///   uppercase), placeholders are the labels (no label rows)
/// - the address input carries the 36px entity icon inside its left edge
/// - the Connect bar floats at the panel's bottom on --dark-grey-2
///   (padding 20px 15px), over the scrolling content — not in flow
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
          _Header(onClose: onClose),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 85),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        title: '地址',
                        children: [
                          // The address row: the 36px entity icon sits
                          // inside the field's left edge, as on the original.
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary,
                                  borderRadius:
                                      BorderRadius.circular(TermiusRadius.card),
                                ),
                                child: Icon(
                                  BootstrapIcons.hddRack,
                                  size: 20,
                                  color: theme.colorScheme.secondaryForeground,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  initialValue: host.address,
                                  placeholder: const Text('IP 或主机名'),
                                  style: theme.typography.normal
                                      .copyWith(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          _field(context, '标签'),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _Section(
                        title: '凭据',
                        children: [
                          _field(context, '用户名'),
                          _field(context, '密码', obscure: true),
                          _field(context, 'SSH 密钥、证书…'),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _Section(
                        title: '通用',
                        children: [
                          _field(context, '标签'),
                          _field(context, '父分组'),
                          _field(context, '标签（Tags）'),
                          _row(context, '退格键', '默认'),
                        ],
                      ),
                    ],
                  ),
                ),
                // The floating Connect bar: bg dark-grey-2, padding 20px 15px,
                // pinned bottom over the content (connectButton styles).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D2033), // --dark-grey-2
                      border: Border(
                          top: BorderSide(color: theme.colorScheme.border)),
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
                          child: const Text('添加 Telnet'),
                        ),
                      ],
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

  /// A placeholder-labelled field: Termius's inputs carry no label rows —
  /// the placeholder is the label. Fill --main-form-bg (dark-grey-4).
  Widget _field(BuildContext context, String placeholder,
      {bool obscure = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        initialValue: null,
        placeholder: Text(placeholder,
            style: TextStyle(
                fontSize: 13, color: theme.colorScheme.mutedForeground)),
        style: theme.typography.normal.copyWith(fontSize: 14),
        obscureText: obscure,
      ),
    );
  }

  /// A value row that is not an input (Backspace / Last used): label left,
  /// value right-aligned muted — the Backspace row's layout.
  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    theme.typography.normal.copyWith(fontSize: 14)),
          ),
          Text(value,
              style: theme.typography.normal.copyWith(
                  fontSize: 13, color: theme.colorScheme.mutedForeground)),
        ],
      ),
    );
  }
}

/// The panel header: the "..." menu on the left, the title, the save-state
/// word, the close arrow on the right.
class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () {},
            child: const Icon(BootstrapIcons.threeDots,
                size: 14, color: Color(0xFF8D91A5)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text('主机详情',
                style: theme.typography.semiBold.copyWith(fontSize: 14)),
          ),
          Text('更改已保存',
              style: theme.typography.normal.copyWith(
                  fontSize: 12, color: theme.colorScheme.mutedForeground)),
          const SizedBox(width: 4),
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: onClose,
            child: const Icon(BootstrapIcons.boxArrowRight,
                size: 14, color: Color(0xFF8D91A5)),
          ),
        ],
      ),
    );
  }
}

/// One section card: bg --card (dark-grey-3), radius 8, padding 15px 20px;
/// the title is 14px/500 in normal case, white — the original's titleSection.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(TermiusRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: theme.typography.medium.copyWith(
                  fontSize: 14, color: theme.colorScheme.foreground)),
          ...children,
        ],
      ),
    );
  }
}
