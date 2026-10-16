/// The Hosts screen: Termius's home, rebuilt to the spec in
/// docs/termius/design-tokens.md §6 — toolbar, card grid (or row list), and
/// the details panel floating over the grid's left side.
library;

import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import 'host_card.dart';
import 'host_details_panel.dart';

enum HostsLayout { cards, rows }

class HostsScreen extends StatefulWidget {
  const HostsScreen({super.key});

  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  HostsLayout _layout = HostsLayout.cards;
  Host? _selected;

  List<Host> get _hosts => kSampleHosts;

  void _onCardTap(Host host) {
    // Termius two-step: the first click looks, the second connects. The
    // connect itself is a stub until the bridge exposes session_runtime.
    if (_selected?.id == host.id) {
      if (kDebugMode) {
        debugPrint('connect → ${host.id} (bridge pending, docs/flutter-bridge.md)');
      }
    } else {
      setState(() => _selected = host);
    }
  }

  void _connectSelected() {
    if (_selected case final host?) {
      if (kDebugMode) debugPrint('connect → ${host.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hosts = _hosts;
    final groups = hosts.map((h) => h.group).where((g) => g.isNotEmpty).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          hostCount: hosts.length,
          groupCount: groups.length,
          layout: _layout,
          canConnect: _selected != null,
          onToggleLayout: () => setState(() => _layout =
              _layout == HostsLayout.cards ? HostsLayout.rows : HostsLayout.cards),
          onNewHost: () {},
          onConnect: _connectSelected,
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.border),
        Expanded(
          child: Stack(
            children: [
              // The grid stays in place under the details panel, the way the
              // hosts screen's detail card covers rather than pushes.
              Padding(
                padding: const EdgeInsets.all(16),
                child: _layout == HostsLayout.cards
                    ? _cardGrid(hosts)
                    : _rowList(hosts),
              ),
              if (_selected != null)
                Positioned(
                  left: 16,
                  top: 16,
                  bottom: 16,
                  width: 460,
                  child: HostDetailsPanel(
                    host: _selected!,
                    onClose: () => setState(() => _selected = null),
                    onConnect: _connectSelected,
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
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 284,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 272 / 76,
      ),
      itemCount: hosts.length + 1,
      itemBuilder: (context, index) {
        if (index == hosts.length) return const _NewHostCard();
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
      itemCount: hosts.length + 1,
      itemBuilder: (context, index) {
        if (index == hosts.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _NewHostCard(),
          );
        }
        final host = hosts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
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

/// The content header: page title with inventory, layout toggle, New host,
/// and Connect enabled by the selection — Termius's toolbar verbatim.
class _Toolbar extends StatelessWidget {
  final int hostCount;
  final int groupCount;
  final HostsLayout layout;
  final bool canConnect;
  final VoidCallback onToggleLayout;
  final VoidCallback onNewHost;
  final VoidCallback onConnect;

  const _Toolbar({
    required this.hostCount,
    required this.groupCount,
    required this.layout,
    required this.canConnect,
    required this.onToggleLayout,
    required this.onNewHost,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('主机',
                    style: theme.typography.semiBold.copyWith(fontSize: 22, height: 1.3)),
                const SizedBox(height: 4),
                Text(
                  '$hostCount 个主机 · $groupCount 个分组',
                  style: theme.typography.normal.copyWith(
                      fontSize: 14, color: theme.colorScheme.mutedForeground),
                ),
              ],
            ),
          ),
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: onToggleLayout,
            child: Icon(
              layout == HostsLayout.cards ? BootstrapIcons.list : BootstrapIcons.grid,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          if (canConnect) ...[
            PrimaryButton(
              density: ButtonDensity.compact,
              onPressed: onConnect,
              child: const Text('连接'),
            ),
            const SizedBox(width: 8),
          ],
          PrimaryButton(
            density: ButtonDensity.compact,
            onPressed: onNewHost,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(BootstrapIcons.plus, size: 16), SizedBox(width: 6), Text('新建主机')],
            ),
          ),
        ],
      ),
    );
  }
}

/// The grid's last cell: a quiet card that adds rather than connects. Muted
/// fill carries the "not a host" reading (dashed borders are not native).
class _NewHostCard extends StatelessWidget {
  const _NewHostCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GhostButton(
      density: ButtonDensity.compact,
      onPressed: () {},
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.border),
          color: theme.colorScheme.card,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(BootstrapIcons.plus,
                  size: 16, color: theme.colorScheme.mutedForeground),
              const SizedBox(width: 8),
              Text('新建主机',
                  style: theme.typography.normal
                      .copyWith(fontSize: 14, color: theme.colorScheme.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}
