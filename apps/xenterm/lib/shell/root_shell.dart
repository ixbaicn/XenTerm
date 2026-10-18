/// The root shell: Termius's two-column spine — the labeled nav rail (~182px,
/// --dark-grey-3 surface) and the content area. The rail carries the screens;
/// Settings anchors its bottom, as the original keeps app-wide actions apart.
library;

import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/termius_theme.dart';
import 'title_bar.dart';
import '../screens/hosts/hosts_screen.dart';
import '../screens/forwards/forwards_screen.dart';
import '../screens/known_hosts/known_hosts_screen.dart';
import '../screens/snippets/snippets_screen.dart';
import '../screens/keychain/keychain_screen.dart';
import '../screens/logs/logs_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/terminal/terminal_screen.dart';
import '../data/hosts.dart';
import '../theme/app_fonts.dart';

enum NavDestination {
  hosts,
  keys,
  forwards,
  snippets,
  knownHosts,
  logs,
  settings,
}

// Keychain 与 Logs 已按原版截图实现（screens/keychain, screens/logs）；
// forwards/snippets/knownHosts 仍为占位，等桥接数据。

class RootShell extends StatefulWidget {
  final bool lightTheme;
  final ValueChanged<bool> onThemeChanged;
  final AppFonts fonts;
  final Future<List<Host>> Function()? hostsLoader;

  const RootShell({
    super.key,
    required this.lightTheme,
    required this.onThemeChanged,
    required this.fonts,
    this.hostsLoader,
  });

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  NavDestination _active = NavDestination.hosts;
  final List<Host> _openHosts = <Host>[];
  String? _activeHostId;
  bool _terminalSftp = false;

  Host? get _activeHost {
    for (final host in _openHosts) {
      if (host.id == _activeHostId) return host;
    }
    return null;
  }

  void _openHost(Host host) {
    setState(() {
      if (!_openHosts.any((h) => h.id == host.id)) _openHosts.add(host);
      _activeHostId = host.id;
    });
  }

  void _closeHost(String id) {
    setState(() {
      _openHosts.removeWhere((h) => h.id == id);
      if (_activeHostId == id) {
        _activeHostId = null;
        _terminalSftp = false;
      }
    });
  }

  static const double _navRailWidth = 182;

  static const List<(NavDestination, String, IconData)> _destinations = [
    (NavDestination.hosts, 'Hosts', LucideIcons.layoutGrid),
    (NavDestination.keys, 'Keychain', LucideIcons.keyRound),
    (NavDestination.forwards, 'Port Forwarding', LucideIcons.arrowLeftRight),
    (NavDestination.snippets, 'Snippets', LucideIcons.braces),
    (NavDestination.knownHosts, 'Known Hosts', LucideIcons.shieldCheck),
    (NavDestination.logs, 'Logs', LucideIcons.circleAlert),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(
            openHosts: _openHosts,
            activeHostId: _activeHostId,
            onSelectHost: (id) => setState(() {
              _activeHostId = id;
              _terminalSftp = false;
            }),
            onCloseHost: _closeHost,
            onNewTab: () => setState(() => _activeHostId = null),
            showSftp: _terminalSftp,
            onToggleSftp: () => setState(() => _terminalSftp = !_terminalSftp),
          ),
          Expanded(
            child: Row(
              children: [
                _NavRail(
                  width: _navRailWidth,
                  active: _active,
                  destinations: _destinations,
                  onSelect: (d) => setState(() {
                    _active = d;
                    // Choosing a screen in the rail parks the session tabs;
                    // clicking a tab in the title bar brings them back.
                    _activeHostId = null;
                    _terminalSftp = false;
                  }),
                ),
                Expanded(
                  child: _activeHost != null
                      ? TerminalScreen(
                          host: _activeHost!,
                          fonts: widget.fonts,
                          showSftp: _terminalSftp,
                        )
                      : _screenFor(_active),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _screenFor(NavDestination destination) {
    return switch (destination) {
      NavDestination.hosts => HostsScreen(
        onConnect: _openHost,
        loadHosts: widget.hostsLoader,
      ),
      NavDestination.keys => const KeychainScreen(),
      NavDestination.logs => const LogsScreen(),
      NavDestination.settings => SettingsScreen(
        lightTheme: widget.lightTheme,
        onThemeChanged: widget.onThemeChanged,
        fonts: widget.fonts,
      ),
      NavDestination.forwards => const ForwardsScreen(),
      NavDestination.snippets => const SnippetsScreen(),
      NavDestination.knownHosts => const KnownHostsScreen(),
    };
  }
}

/// The labeled nav rail on the --dark-grey-3 surface: 36px entries with 15px
/// labels, selected = --dark-grey-5 chip. Settings sits at the bottom.
class _NavRail extends StatelessWidget {
  final double width;
  final NavDestination active;
  final List<(NavDestination, String, IconData)> destinations;
  final ValueChanged<NavDestination> onSelect;

  const _NavRail({
    required this.width,
    required this.active,
    required this.destinations,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: const Color(0xFF282B3D), // --dark-grey-3 chrome surface
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (destination, title, icon) in destinations)
            _RailItem(
              icon: icon,
              label: title,
              selected: destination == active,
              onTap: () => onSelect(destination),
            ),
          const Spacer(),
          const Divider(height: 1, color: Color(0xFF1D2033)),
          const SizedBox(height: 4),
          _RailItem(
            icon: material.Icons.settings_outlined,
            label: 'Settings',
            selected: active == NavDestination.settings,
            onTap: () => onSelect(NavDestination.settings),
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

  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Selected = --dark-grey-5 chip with primary text; hover = --dark-grey-4.
    final background = widget.selected
        ? const Color(0xFF3E4257)
        : (_hovering ? const Color(0xFF32364A) : Colors.transparent);
    final foreground = widget.selected
        ? theme.colorScheme.foreground
        : theme.colorScheme.mutedForeground;
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
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(TermiusRadius.card),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.normal.copyWith(
                    fontSize: 15,
                    color: foreground,
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
