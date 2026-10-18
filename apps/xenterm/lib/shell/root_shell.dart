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
import '../widgets/lucide_extra_icons.dart';
import '../screens/snippets/snippets_screen.dart';
import '../screens/keychain/keychain_screen.dart';
import '../screens/logs/logs_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/terminal/terminal_screen.dart';
import '../data/hosts.dart';
import '../bridge/native_bridge.dart';
import '../terminal/core_settings.dart';
import '../terminal/terminal_command_bus.dart';
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

// Every rail screen is backed by real core data (sessions, quick commands,
// known hosts, forwards, keys, transcripts, settings).

class RootShell extends StatefulWidget {
  final bool lightTheme;
  final ValueChanged<bool> onThemeChanged;
  final AppFonts fonts;
  final CoreSettingsController settings;
  final Future<List<Host>> Function()? hostsLoader;

  const RootShell({
    super.key,
    required this.lightTheme,
    required this.onThemeChanged,
    required this.fonts,
    required this.settings,
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
  bool _railOpen = true;
  final TerminalCommandBus _commands = TerminalCommandBus();
  final ValueNotifier<int> _newHostRequest = ValueNotifier<int>(0);

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
      // The terminal gets the full width; the hamburger brings the rail back
      // (the original's terminal window opens with the side menu collapsed).
      _railOpen = false;
    });
  }

  /// Runs a saved snippet in the active terminal (or the most recent one when
  /// the rail screen is showing) and brings that session back to the front.
  void _runSnippet(QuickCommand snippet) {
    final target = _activeHost ?? (_openHosts.isEmpty ? null : _openHosts.last);
    if (target == null) return;
    setState(() {
      _activeHostId = target.id;
      _terminalSftp = false;
    });
    // Send after the offstage switch so the terminal can take focus too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commands.send(target.id, snippet.command, sendEnter: snippet.sendEnter);
    });
  }

  /// The title bar's + opens a fresh editor on the Hosts screen.
  void _requestNewHost() {
    setState(() {
      _active = NavDestination.hosts;
      _activeHostId = null;
      _terminalSftp = false;
    });
    // HostsScreen may be built by this same frame; notify after it mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newHostRequest.value++;
    });
  }

  @override
  void dispose() {
    _newHostRequest.dispose();
    _commands.dispose();
    super.dispose();
  }

  void _closeHost(String id) {
    setState(() {
      _openHosts.removeWhere((h) => h.id == id);
      if (_activeHostId == id) {
        _activeHostId = null;
        _terminalSftp = false;
        if (_openHosts.isEmpty) _railOpen = true;
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
            onNewTab: _requestNewHost,
            showSftp: _terminalSftp,
            onToggleSftp: () => setState(() => _terminalSftp = !_terminalSftp),
            onToggleSidebar: () => setState(() => _railOpen = !_railOpen),
          ),
          Expanded(
            child: Row(
              children: [
                // Collapsible rail: fixed-width content clipped by an
                // animated 0⇄182px box (no squashing mid-animation).
                ClipRect(
                  child: AnimatedContainer(
                    duration: TermiusMotion.micro,
                    curve: TermiusMotion.easeOut,
                    width: _railOpen ? _navRailWidth : 0,
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: _navRailWidth,
                      maxWidth: _navRailWidth,
                      child: _NavRail(
                        width: _navRailWidth,
                        active: _active,
                        destinations: _destinations,
                        onSelect: (d) => setState(() {
                          _active = d;
                          // Choosing a screen in the rail parks the session
                          // tabs; clicking a tab in the title bar brings them
                          // back.
                          _activeHostId = null;
                          _terminalSftp = false;
                        }),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  // Every open workspace stays mounted (offstage when not in
                  // front), so switching session tabs never reconnects and
                  // background PTYs keep running.
                  child: Stack(
                    children: [
                      for (final host in _openHosts)
                        Positioned.fill(
                          child: Offstage(
                            offstage: host.id != _activeHostId,
                            child: TerminalScreen(
                              key: ValueKey('workspace-${host.id}'),
                              host: host,
                              fonts: widget.fonts,
                              settings: widget.settings,
                              showSftp:
                                  host.id == _activeHostId && _terminalSftp,
                              commandBus: _commands,
                            ),
                          ),
                        ),
                      if (_activeHostId == null)
                        Positioned.fill(child: _screenFor(_active)),
                    ],
                  ),
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
        newHostRequest: _newHostRequest,
      ),
      NavDestination.keys => const KeychainScreen(),
      NavDestination.logs => const LogsScreen(),
      NavDestination.settings => SettingsScreen(
        lightTheme: widget.lightTheme,
        onThemeChanged: widget.onThemeChanged,
        fonts: widget.fonts,
        settings: widget.settings,
      ),
      NavDestination.forwards => const ForwardsScreen(),
      NavDestination.snippets => SnippetsScreen(
        onRun: _openHosts.isEmpty ? null : _runSnippet,
      ),
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
              glyphBuilder: switch (destination) {
                NavDestination.knownHosts => (
                  size,
                  color,
                ) => FingerprintPatternIcon(size: size, color: color),
                NavDestination.logs => (size, color) => ClipboardClockIcon(
                  size: size,
                  color: color,
                ),
                _ => null,
              },
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

  /// Overrides the font glyph (for icons newer than the bundled set).
  final Widget Function(double size, Color color)? glyphBuilder;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    this.glyphBuilder,
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
              widget.glyphBuilder?.call(16, foreground) ??
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
