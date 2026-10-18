/// The host details drawer — the original's right panel, faithful to the
/// screenshots:
///
/// - header: "Host Details" title, "..." and →| close at right
/// - "Personal" vault selector dropdown card at the top
/// - sections as cards on --card (padding 15px 20px, titles 14px/500 normal
///   case): Address (icon inside field), General (icon-bearing fields, tag
///   pill, Backspace row), Share this host outline button, SSH on [22] port
///   inline row, Credentials (username)
/// - the Connect bar floats at the panel's bottom on --dark-grey-2
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';

class HostDetailsPanel extends StatefulWidget {
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
  State<HostDetailsPanel> createState() => _HostDetailsPanelState();
}

class _HostDetailsPanelState extends State<HostDetailsPanel> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = widget.host;
    return Container(
      color: theme.colorScheme.background,
      child: Column(
        children: [
          _Header(onClose: widget.onClose),
          // ── Scrollable body ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _VaultSelector(name: 'Personal'),
                  const SizedBox(height: 16),
                  _Section(title: '地址', children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD70A53),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(BootstrapIcons.lightningChargeFill,
                              size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TermiusField(
                            initialValue: host.address,
                            placeholder: 'IP 或主机名',
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _Section(title: '通用', children: [
                    TermiusField(initialValue: host.label, placeholder: '标签'),
                    _iconField(context, '父分组', BootstrapIcons.collection),
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.background,
                        borderRadius:
                            BorderRadius.circular(TermiusRadius.field),
                        border: Border.all(color: theme.colorScheme.secondary),
                      ),
                      child: Row(
                        children: [
                          Icon(BootstrapIcons.tag,
                              size: 13,
                              color: theme.colorScheme.mutedForeground),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(
                                  TermiusRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(host.group,
                                    style: theme.typography.normal.copyWith(
                                        fontSize: 13,
                                        color: theme.colorScheme.foreground)),
                                const SizedBox(width: 6),
                                Icon(BootstrapIcons.xCircleFill,
                                    size: 12,
                                    color: theme.colorScheme.mutedForeground),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _valueRow(context, '退格键', '默认',
                        leading: BootstrapIcons.keyboard),
                  ]),
                  const SizedBox(height: 16),
                  OutlineButton(
                    onPressed: widget.onEditAll,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('共享此主机',
                            style: theme.typography.normal.copyWith(
                                fontSize: 14,
                                color: theme.colorScheme.primary)),
                        const SizedBox(width: 8),
                        Icon(BootstrapIcons.peopleFill,
                            size: 15, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Text('SSH on',
                            style: theme.typography.normal.copyWith(
                                fontSize: 15,
                                color: theme.colorScheme.foreground)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 72,
                          child: TermiusField(
                            initialValue: '${host.port}',
                            placeholder: '22',
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('端口',
                            style: theme.typography.normal.copyWith(
                                fontSize: 15,
                                color: theme.colorScheme.foreground)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(title: '凭据', children: [
                    _iconField(context, host.username, BootstrapIcons.person),
                    AnimatedSize(
                      duration: _showMore
                          ? TermiusMotion.panel
                          : TermiusMotion.collapse,
                      curve: TermiusMotion.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _showMore
                          ? Column(children: [
                              TermiusField(placeholder: '密码', obscure: true),
                              TermiusField(placeholder: 'SSH 密钥、证书…'),
                            ])
                          : const SizedBox(width: double.infinity),
                    ),
                    GhostButton(
                      density: ButtonDensity.compact,
                      onPressed: () => setState(() => _showMore = !_showMore),
                      child: Text(
                        _showMore ? '收起' : '显示更多',
                        style: theme.typography.normal.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              border: Border(top: BorderSide(color: theme.colorScheme.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                onPressed: widget.onConnect,
                child: const Text('连接'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconField(BuildContext context, String placeholder, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        placeholder: Row(children: [
          Icon(icon, size: 14, color: theme.colorScheme.mutedForeground),
          const SizedBox(width: 8),
          Text(placeholder,
              style: TextStyle(
                  fontSize: 14, color: theme.colorScheme.mutedForeground)),
        ]),
        style: theme.typography.normal.copyWith(fontSize: 14),
      ),
    );
  }

  Widget _valueRow(BuildContext context, String label, String value,
      {IconData? leading}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 14, color: theme.colorScheme.mutedForeground),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label,
                style: theme.typography.normal.copyWith(
                    fontSize: 14, color: theme.colorScheme.mutedForeground)),
          ),
          Text(value,
              style: theme.typography.normal.copyWith(
                  fontSize: 14, color: theme.colorScheme.foreground)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text('主机详情',
                style: theme.typography.semiBold.copyWith(
                    fontSize: 16, color: theme.colorScheme.foreground)),
          ),
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: () {},
            child: const Icon(BootstrapIcons.threeDots,
                size: 14, color: Color(0xFF8D91A5)),
          ),
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

class _VaultSelector extends StatelessWidget {
  final String name;

  const _VaultSelector({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Row(
        children: [
          Icon(BootstrapIcons.viewStacked,
              size: 15, color: theme.colorScheme.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: theme.typography.normal.copyWith(
                    fontSize: 14, color: theme.colorScheme.foreground)),
          ),
          Icon(BootstrapIcons.chevronDown,
              size: 13, color: theme.colorScheme.mutedForeground),
        ],
      ),
    );
  }
}

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
        color: theme.colorScheme.popover,
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
