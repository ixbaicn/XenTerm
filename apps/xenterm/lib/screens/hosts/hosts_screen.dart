/// The Hosts screen — faithful to the original screenshots:
/// search+Connect row, split [New host|▾] + Terminal + Serial toolbar with
/// grid/tag/keyboard/avatar/+ at right, a bold "主机" section title over the
/// card grid, cards with colored OS chips and a hover edit-pencil.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';
import 'host_card.dart';
import 'host_details_panel.dart';

enum HostsLayout { cards, rows }

class HostsScreen extends StatefulWidget {
  final ValueChanged<Host>? onConnect;

  const HostsScreen({super.key, this.onConnect});

  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  final TextEditingController _search = TextEditingController();
  HostsLayout _layout = HostsLayout.cards;
  Host? _drawerHost;
  bool _drawerOpen = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Host> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kSampleHosts;
    return kSampleHosts
        .where(
          (h) =>
              h.label.toLowerCase().contains(q) ||
              h.address.toLowerCase().contains(q) ||
              h.username.toLowerCase().contains(q),
        )
        .toList();
  }

  void _connect(Host? host) {
    if (host != null) widget.onConnect?.call(host);
  }

  /// Collapse first; AnimatedSize.onEnd unmounts the panel afterwards.
  void _closeDrawer() => setState(() => _drawerOpen = false);

  void _onCardTap(Host host) {
    if (_drawerOpen && _drawerHost?.id == host.id) {
      _connect(host);
      return;
    }
    setState(() {
      _drawerHost = host;
      _drawerOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hosts = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search + Connect (inside the field) ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    border: Border.all(color: Colors.transparent),
                    borderRadius: BorderRadius.circular(TermiusRadius.field),
                    placeholder: Text(
                      '查找主机或 ssh user@hostname…',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                    style: theme.typography.normal.copyWith(
                      fontSize: 14,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                ),
                // Connect lives INSIDE the field; the original keeps it a
                // muted text button in every state (the blue Connect is the
                // drawer's).
                GhostButton(
                  density: ButtonDensity.compact,
                  onPressed: _drawerOpen ? null : () => _connect(_drawerHost),
                  child: Text(
                    '连接',
                    style: theme.typography.normal.copyWith(
                      fontSize: 13,
                      color: _drawerOpen
                          ? theme.colorScheme.foreground
                          : theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Toolbar row ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              SplitButton(
                label: '新建主机',
                icon: BootstrapIcons.plus,
                onPressed: () {},
                onDropdown: () {},
              ),
              const SizedBox(width: 20),
              GhostAction(
                icon: BootstrapIcons.terminal,
                label: '终端',
                onPressed: () {},
              ),
              const SizedBox(width: 20),
              GhostAction(
                icon: BootstrapIcons.usbPlug,
                label: '串口',
                onPressed: () {},
              ),
              const Spacer(),
              IconToggleButton(
                icon: _layout == HostsLayout.cards
                    ? BootstrapIcons.grid
                    : BootstrapIcons.list,
                onPressed: () => setState(
                  () => _layout = _layout == HostsLayout.cards
                      ? HostsLayout.rows
                      : HostsLayout.cards,
                ),
              ),
              const SizedBox(width: 6),
              IconToggleButton(icon: BootstrapIcons.tag, onPressed: () {}),
              const SizedBox(width: 6),
              IconToggleButton(icon: BootstrapIcons.keyboard, onPressed: () {}),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF21B568),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF21B568).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Text(
                  'B',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF21B568),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF21B568).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  BootstrapIcons.plus,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // ── Section title + cards ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 0, 12),
          child: Text(
            '主机',
            style: theme.typography.bold.copyWith(
              fontSize: 18,
              color: theme.colorScheme.foreground,
            ),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _layout == HostsLayout.cards
                      ? _cardGrid(hosts)
                      : _rowList(hosts),
                ),
              ),
              // The details drawer PUSHES the grid: AnimatedSize animates
              // its width both ways, so the cards reflow while it opens and
              // the column is reclaimed while it collapses (no instant
              // removal, no floating popup — the original's behavior).
              AnimatedSize(
                duration:
                    _drawerOpen ? TermiusMotion.panel : TermiusMotion.collapse,
                curve: TermiusMotion.easeInOut,
                alignment: Alignment.centerRight,
                onEnd: () {
                  if (!_drawerOpen && _drawerHost != null) {
                    setState(() => _drawerHost = null);
                  }
                },
                child: _drawerOpen && _drawerHost != null
                    ? SizedBox(
                        // The original drawer is ~420 logical px wide —
                        // narrower than half the window, so the grid keeps
                        // its two-column rhythm while it pushes.
                        width: 420,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.background,
                            border: Border(
                              left: BorderSide(
                                  color: theme.colorScheme.border),
                            ),
                          ),
                          child: HostDetailsPanel(
                            host: _drawerHost!,
                            onClose: _closeDrawer,
                            onConnect: () => _connect(_drawerHost),
                            onEditAll: () {},
                          ),
                        ),
                      )
                    : const SizedBox(width: 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardGrid(List<Host> hosts) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 560,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 540 / 76,
      ),
      itemCount: hosts.length,
      itemBuilder: (context, index) {
        final host = hosts[index];
        return HostCard.grid(
          host: host,
          selected: _drawerOpen && _drawerHost?.id == host.id,
          onTap: () => _onCardTap(host),
        );
      },
    );
  }

  Widget _rowList(List<Host> hosts) {
    return ListView.builder(
      itemCount: hosts.length,
      itemBuilder: (context, index) {
        final host = hosts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: HostCard.row(
            host: host,
            selected: _drawerOpen && _drawerHost?.id == host.id,
            onTap: () => _onCardTap(host),
          ),
        );
      },
    );
  }
}
