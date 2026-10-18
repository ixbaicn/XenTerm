/// The root shell: Termius's two-column spine — the labeled nav rail (~180px,
/// navigation only) and the content area. SFTP and Vaults anchor the rail's
/// bottom, as in the original (design-tokens.md §6).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/termius_theme.dart';
import 'title_bar.dart';
import '../screens/hosts/hosts_screen.dart';
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

  const RootShell({
    super.key,
    required this.lightTheme,
    required this.onThemeChanged,
    required this.fonts,
  });

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  NavDestination _active = NavDestination.hosts;
  Host? _terminalHost;
  double _navRailWidth = 200;

  static const double _dividerHitWidth = 8;
  static const double _minContentWidth = 320;

  static const List<(NavDestination, String, IconData)> _destinations = [
    (NavDestination.hosts, '主机', BootstrapIcons.hddRack),
    (NavDestination.keys, '密钥', BootstrapIcons.key),
    (NavDestination.forwards, '端口转发', BootstrapIcons.shuffle),
    (NavDestination.snippets, '快捷命令', BootstrapIcons.lightning),
    (NavDestination.knownHosts, '已知主机', BootstrapIcons.shieldCheck),
    (NavDestination.logs, '日志', BootstrapIcons.clockHistory),
    (NavDestination.settings, '设置', material.Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TitleBar(),
          Expanded(
            child: _terminalHost != null
                ? TerminalScreen(
                    host: _terminalHost!,
                    onClose: () => setState(() => _terminalHost = null),
                    fonts: widget.fonts,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final maxRailWidth = math.max(
                        0.0,
                        math.min(
                          400.0,
                          constraints.maxWidth -
                              _dividerHitWidth -
                              _minContentWidth,
                        ),
                      );
                      final minRailWidth = math.min(160.0, maxRailWidth);
                      final railWidth = _navRailWidth.clamp(
                        minRailWidth,
                        maxRailWidth,
                      );
                      return Row(
                        children: [
                          _NavRail(
                            width: railWidth,
                            active: _active,
                            destinations: _destinations,
                            onSelect: (d) => setState(() => _active = d),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (details) {
                                setState(() {
                                  _navRailWidth = (railWidth + details.delta.dx)
                                      .clamp(minRailWidth, maxRailWidth);
                                });
                              },
                              child: SizedBox(
                                width: _dividerHitWidth,
                                height: double.infinity,
                                child: Center(
                                  child: Container(
                                    width: 1,
                                    color: theme.colorScheme.border,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(child: _screenFor(_active)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _screenFor(NavDestination destination) {
    return switch (destination) {
      NavDestination.hosts => HostsScreen(
        onConnect: (host) => setState(() => _terminalHost = host),
      ),
      NavDestination.keys => const KeychainScreen(),
      NavDestination.logs => const LogsScreen(),
      NavDestination.settings => SettingsScreen(
        lightTheme: widget.lightTheme,
        onThemeChanged: widget.onThemeChanged,
        fonts: widget.fonts,
      ),
      // Placeholder until the bridge exposes each area's data; the rail is
      // honest about what exists, so these name their screen and wait.
      _ => _PlaceholderScreen(
        title: switch (destination) {
          NavDestination.forwards => '端口转发',
          NavDestination.snippets => '快捷命令',
          NavDestination.knownHosts => '已知主机',
          _ => '?',
        },
      ),
    };
  }
}

/// The labeled nav rail, ~180px, entries 32px tall with 13px labels — the
/// original's compact scale. SFTP / Vaults pin to the bottom.
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
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (destination, title, icon) in destinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _RailItem(
                icon: icon,
                label: title,
                selected: destination == active,
                onTap: () => onSelect(destination),
              ),
            ),
          const Spacer(),
          Divider(height: 1, color: theme.colorScheme.border),
          const SizedBox(height: 4),
          _RailItem(
            icon: BootstrapIcons.folder2Open,
            label: 'SFTP',
            selected: false,
            onTap: () {},
          ),
          _RailItem(
            icon: BootstrapIcons.cloudFill,
            label: 'Vaults',
            selected: false,
            onTap: () {},
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
    // Selected = the --list-select grey chip (--dark-grey-4 on the dark
    // theme) with primary text; hover = --list-hover (--dark-grey-5).
    final background = widget.selected
        ? theme.colorScheme.secondary
        : (_hovering ? theme.colorScheme.accent : Colors.transparent);
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
          height: 44,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(TermiusRadius.menu),
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
          Text(title, style: theme.typography.semiBold.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            '等待 Rust 桥接（docs/flutter-bridge.md）',
            style: theme.typography.normal.copyWith(
              fontSize: 14,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
