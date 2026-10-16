/// The root shell: Termius's three-column spine — the labeled nav rail, the
/// hosts sidebar, the content area (design-tokens.md §6). The rail collapses
/// to icons on the terminal screen; every other screen keeps the labels.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../data/hosts.dart';
import '../theme/termius_theme.dart';
import '../screens/hosts/hosts_screen.dart';

enum NavDestination { hosts, keys, forwards, snippets, settings }

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  NavDestination _active = NavDestination.hosts;

  static const _destinations = [
    (NavDestination.hosts, '主机', BootstrapIcons.hddRack),
    (NavDestination.keys, '密钥', BootstrapIcons.key),
    (NavDestination.forwards, '端口转发', BootstrapIcons.shuffle),
    (NavDestination.snippets, '快捷命令', BootstrapIcons.lightning),
    (NavDestination.settings, '设置', BootstrapIcons.gear),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      child: Row(
        children: [
          _NavRail(
            active: _active,
            destinations: _destinations,
            onSelect: (d) => setState(() => _active = d),
          ),
          Container(width: 1, color: theme.colorScheme.border),
          // The hosts sidebar: search on top, host rows below — Termius's
          // second column, at its measured ~250px.
          SizedBox(
            width: 250,
            child: _HostsSidebar(),
          ),
          Container(width: 1, color: theme.colorScheme.border),
          Expanded(child: _screenFor(_active)),
        ],
      ),
    );
  }

  Widget _screenFor(NavDestination destination) {
    return switch (destination) {
      NavDestination.hosts => const HostsScreen(),
      // Placeholder until the bridge exposes each area's data; the rail is
      // honest about what exists, so these name their screen and wait.
      _ => _PlaceholderScreen(
          title: switch (destination) {
            NavDestination.keys => '密钥',
            NavDestination.forwards => '端口转发',
            NavDestination.snippets => '快捷命令',
            _ => '设置',
          },
        ),
    };
  }
}

/// The labeled nav rail (190px). Selected = the --list-select grey chip with
/// white text; hover = --list-hover; the width animates when the shell later
/// collapses it for the terminal screen (TermiusMotion.panel, easeInOut —
/// MUI's Collapse cadence).
class _NavRail extends StatelessWidget {
  final NavDestination active;
  final List<(NavDestination, String, IconData)> destinations;
  final ValueChanged<NavDestination> onSelect;

  const _NavRail({
    required this.active,
    required this.destinations,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (destination, title, icon) in destinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _RailItem(
                icon: icon,
                label: title,
                selected: destination == active,
                onTap: () => onSelect(destination),
                selectedColor: theme.colorScheme.secondary,
                hoverColor: theme.colorScheme.accent,
                foreground: theme.colorScheme.foreground,
              ),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color hoverColor;
  final Color foreground;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.hoverColor,
    required this.foreground,
  });

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TermiusMotion.micro,
          curve: TermiusMotion.easeOut,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.selectedColor
                : (_hovering ? widget.hoverColor : Colors.transparent),
            borderRadius: BorderRadius.circular(TermiusRadius.card),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 16,
                  color: widget.selected
                      ? widget.foreground
                      : theme.colorScheme.mutedForeground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.normal.copyWith(
                    fontSize: 14,
                    color: widget.selected
                        ? widget.foreground
                        : theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hosts sidebar: the search field Termius leads with
/// ("Find a host or ssh user@hostname..."), then the host rows.
class _HostsSidebar extends StatefulWidget {
  @override
  State<_HostsSidebar> createState() => _HostsSidebarState();
}

class _HostsSidebarState extends State<_HostsSidebar> {
  String _query = '';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hosts = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            initialValue: _query,
            placeholder: const Text('查找主机或 ssh user@hostname…'),
            onChanged: (value) => setState(() => _query = value),
            style: theme.typography.normal.copyWith(fontSize: 13),
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.border),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: hosts.length,
            itemBuilder: (context, index) {
              final host = hosts[index];
              return _SidebarRow(host: host);
            },
          ),
        ),
      ],
    );
  }
}

class _SidebarRow extends StatefulWidget {
  final Host host;

  const _SidebarRow({required this.host});

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: TermiusMotion.micro,
        curve: TermiusMotion.easeOut,
        color: _hovering ? theme.colorScheme.accent : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: BorderRadius.circular(TermiusRadius.card),
              ),
              child: Icon(
                BootstrapIcons.hddRack,
                size: 16,
                color: theme.colorScheme.secondaryForeground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.host.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.medium.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(widget.host.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.normal.copyWith(
                          fontSize: 12, color: theme.colorScheme.mutedForeground)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: theme.typography.semiBold.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text('等待 Rust 桥接（docs/flutter-bridge.md）',
              style: theme.typography.normal.copyWith(
                  fontSize: 14, color: theme.colorScheme.mutedForeground)),
        ],
      ),
    );
  }
}
