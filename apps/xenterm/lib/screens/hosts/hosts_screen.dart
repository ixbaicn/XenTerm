/// The Hosts screen — Termius's home, structurally faithful:
///
///   [search + Connect]          ← content top, full width
///   [New host ▾ | Terminal | Serial      …grid·tag·B·+]
///   [card grid]                 ← three compact columns
///
/// There is no middle hosts column: the hosts live in the content area as
/// cards; the sidebar holds only navigation (design-tokens.md §6).
library;

import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';
import 'host_card.dart';
import 'host_details_panel.dart';

enum HostsLayout { cards, rows }

class HostsScreen extends StatefulWidget {
  const HostsScreen({super.key});

  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  final TextEditingController _search = TextEditingController();
  HostsLayout _layout = HostsLayout.cards;
  Host? _selected;
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
        .where((h) =>
            h.label.toLowerCase().contains(q) ||
            h.address.toLowerCase().contains(q) ||
            h.username.toLowerCase().contains(q))
        .toList();
  }

  void _connect(Host? host) {
    if (host != null && kDebugMode) {
      debugPrint('connect → ${host.id} (bridge pending, docs/flutter-bridge.md)');
    }
  }

  void _onCardTap(Host host) {
    // Termius two-step: first click selects (Connect lights, card rings),
    // second connects.
    if (_selected?.id == host.id) {
      _connect(host);
    } else {
      setState(() => _selected = host);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hosts = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search + Connect: the header row, height 56, padding 8; the
        // field is 36px tall on --dark-grey-5, radius 10, borderless, and
        // Connect sits inside it at the right — Termius's exact header
        // (w6e styles, dumped from its bundle).
        Container(
          height: TermiusMetrics.headerHeight,
          color: theme.colorScheme.background,
          padding: const EdgeInsets.all(8),
          child: Container(
            height: TermiusMetrics.searchFieldHeight,
            decoration: BoxDecoration(
              color: TermiusMetrics.searchFieldFill,
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            padding: const EdgeInsets.only(left: 10, right: 5),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    borderRadius: BorderRadius.zero,
                    padding: EdgeInsets.zero,
                    controller: _search,
                    placeholder: Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: Text('查找主机或 ssh user@hostname…',
                          style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.mutedForeground)),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                    style: theme.typography.normal.copyWith(
                        fontSize: 13, color: theme.colorScheme.foreground),
                  ),
                ),
                PrimaryButton(
                  density: ButtonDensity.compact,
                  onPressed:
                      _selected == null ? null : () => _connect(_selected),
                  child: const Text('连接'),
                ),
              ],
            ),
          ),
        ),
        // ── Toolbar row: HostsFiltersHeader — height 45, padding 4/12,
        // gap 15 (its own styles, extracted).
        Container(
          height: TermiusMetrics.toolbarHeight,
          color: theme.colorScheme.background,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              GhostButton(
                density: ButtonDensity.compact,
                size: ButtonSize.small,
                onPressed: () {},
                leading: const Icon(BootstrapIcons.plus, size: 14),
                trailing: const Icon(BootstrapIcons.caretDownFill, size: 10),
                child: const Text('新建主机', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 15),
              GhostButton(
                density: ButtonDensity.compact,
                size: ButtonSize.small,
                onPressed: () {},
                leading: const Icon(BootstrapIcons.terminal, size: 14),
                child: const Text('终端', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 15),
              GhostButton(
                density: ButtonDensity.compact,
                size: ButtonSize.small,
                onPressed: () {},
                leading: const Icon(BootstrapIcons.usbPlug, size: 14),
                child: const Text('串口', style: TextStyle(fontSize: 13)),
              ),
              const Spacer(),
              GhostButton(
                density: ButtonDensity.compact,
                onPressed: () => setState(() => _layout =
                    _layout == HostsLayout.cards
                        ? HostsLayout.rows
                        : HostsLayout.cards),
                child: Icon(
                  _layout == HostsLayout.cards
                      ? BootstrapIcons.grid
                      : BootstrapIcons.list,
                  size: 15,
                ),
              ),
              const SizedBox(width: 4),
              GhostButton(
                density: ButtonDensity.compact,
                onPressed: () {},
                child: const Icon(BootstrapIcons.tag, size: 15),
              ),
              const SizedBox(width: 4),
              // The account chip: a 24px green circle with the initial.
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF21B568),
                  shape: BoxShape.circle,
                ),
                child: const Text('B',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 4),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF21B568),
                  shape: BoxShape.circle,
                ),
                child: const Icon(BootstrapIcons.plus,
                    size: 13, color: Colors.white),
              ),
            ],
          ),
        ),
        // ── Cards ───────────────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: _layout == HostsLayout.cards
                    ? _cardGrid(hosts)
                    : _rowList(hosts),
              ),
              if (_selected != null)
                Positioned(
                  left: 16,
                  top: 8,
                  bottom: 16,
                  width: 460,
                  child: HostDetailsPanel(
                    host: _selected!,
                    onClose: () => setState(() => _selected = null),
                    onConnect: () => _connect(_selected),
                    onEditAll: () {},
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardGrid(List<Host> hosts) {
    // The grid card is 430px wide on disk; cells shrink in narrower panes.
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 440,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 430 / 60,
      ),
      itemCount: hosts.length,
      itemBuilder: (context, index) {
        final host = hosts[index];
        return HostCard.grid(
          host: host,
          selected: _selected?.id == host.id,
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
          padding: const EdgeInsets.only(bottom: 6),
          child: HostCard.row(
            host: host,
            selected: _selected?.id == host.id,
            onTap: () => _onCardTap(host),
          ),
        );
      },
    );
  }
}
