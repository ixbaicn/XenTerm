/// The Hosts screen — faithful to the original screenshots:
/// search+Connect row, split [New host|▾] + Terminal + Serial toolbar with
/// grid/tag/keyboard/avatar/+ at right, a bold "主机" section title over the
/// card grid, cards with colored OS chips and a hover edit-pencil.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';
import 'host_card.dart';
import 'host_details_panel.dart';

enum HostsLayout { cards, rows }

typedef HostSaver = Future<CoreWriteResult> Function({
  required String id,
  required String label,
  required String address,
  required int port,
  required String username,
  required String group,
  required String kind,
  String keyPath,
});
typedef HostDeleter = Future<CoreWriteResult> Function(String id);

class HostsScreen extends StatefulWidget {
  final ValueChanged<Host>? onConnect;

  /// Session source; defaults to the Rust core through the FFI bridge.
  final Future<List<Host>> Function()? loadHosts;

  /// Incremented by the title bar's + button to open the New host drawer.
  final ValueListenable<int>? newHostRequest;

  /// Test seams; production uses the FFI bridge.
  final HostSaver? saveSession;
  final HostDeleter? deleteSession;

  const HostsScreen({
    super.key,
    this.onConnect,
    this.loadHosts,
    this.newHostRequest,
    this.saveSession,
    this.deleteSession,
  });

  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  final TextEditingController _search = TextEditingController();
  HostsLayout _layout = HostsLayout.cards;
  Host? _drawerHost;
  bool _drawerOpen = false;
  String _query = '';
  List<Host> _hosts = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    widget.newHostRequest?.addListener(_onNewHostRequest);
    _reload();
  }

  @override
  void didUpdateWidget(HostsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.newHostRequest != widget.newHostRequest) {
      oldWidget.newHostRequest?.removeListener(_onNewHostRequest);
      widget.newHostRequest?.addListener(_onNewHostRequest);
    }
  }

  void _onNewHostRequest() {
    if (mounted) _createSession();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final hosts = await (widget.loadHosts ?? loadHostsFromCore)();
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is NativeBridgeError ? error.message : '$error';
      });
    }
  }

  @override
  void dispose() {
    widget.newHostRequest?.removeListener(_onNewHostRequest);
    _search.dispose();
    super.dispose();
  }

  List<Host> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _hosts;
    return _hosts
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

  /// Persists the drawer's edits into the core store, then refreshes the list.
  Future<String?> _saveHostToCore(Host host) async {
    try {
      final result = await (widget.saveSession ?? saveSessionToCore)(
        id: host.id,
        label: host.label,
        address: host.address,
        port: host.port,
        username: host.username,
        group: host.group,
        kind: host.protocol,
        keyPath: host.keyPath,
      );
      if (!result.ok) return result.error ?? 'Save failed';
      await _reload(silent: true);
      final id = result.id ?? host.id;
      for (final h in _hosts) {
        if (h.id == id) {
          if (mounted) setState(() => _drawerHost = h);
          break;
        }
      }
      return null;
    } catch (error) {
      return '$error';
    }
  }

  /// Deletes one session through the core and refreshes the list.
  Future<String?> _deleteHostToCore(Host host) async {
    try {
      final result = await (widget.deleteSession ?? deleteSessionFromCore)(
        host.id,
      );
      if (!result.ok) return result.error ?? 'Delete failed';
      _closeDrawer();
      await _reload(silent: true);
      return null;
    } catch (error) {
      return '$error';
    }
  }

  /// Creates a session in the core and returns it after the list reloads.
  Future<Host?> _createSessionFor({
    required String kind,
    required String label,
    String address = '',
    int port = 22,
    String username = '',
  }) async {
    try {
      final result = await (widget.saveSession ?? saveSessionToCore)(
        id: '',
        label: label,
        address: address,
        port: port,
        username: username,
        group: '',
        kind: kind,
      );
      if (!result.ok) {
        if (mounted) {
          setState(() => _loadError = result.error ?? 'Could not create host');
        }
        return null;
      }
      await _reload(silent: true);
      for (final host in _hosts) {
        if (host.id == result.id) return host;
      }
      return null;
    } catch (error) {
      if (mounted) setState(() => _loadError = '$error');
      return null;
    }
  }

  /// The New host button: create an SSH session and edit it in the drawer.
  Future<void> _createSession() async {
    final host = await _createSessionFor(kind: 'ssh', label: 'New Host');
    if (host == null || !mounted) return;
    setState(() {
      _drawerHost = host;
      _drawerOpen = true;
    });
  }

  /// The toolbar's Terminal action: a real local PTY session, opened directly.
  /// An existing "Local terminal" is reused instead of piling up duplicates.
  Future<void> _quickLocal() async {
    for (final host in _hosts) {
      if (host.protocol == 'local' && host.label == 'Local terminal') {
        _connect(host);
        return;
      }
    }
    final host = await _createSessionFor(
      kind: 'local',
      label: 'Local terminal',
    );
    if (host != null) _connect(host);
  }

  /// The toolbar's Serial action: a serial session, opened in the editor so the
  /// port can be filled in.
  Future<void> _quickSerial() async {
    final host = await _createSessionFor(
      kind: 'serial',
      label: 'Serial',
      // The serial device goes in Address; the SSH port field stays unused.
      port: 22,
    );
    if (host == null || !mounted) return;
    setState(() {
      _drawerHost = host;
      _drawerOpen = true;
    });
  }

  /// Quick connect from the search field: an existing host wins; otherwise a
  /// `user@host:port` query creates a new SSH session and connects immediately.
  Future<void> _quickConnect() async {
    final query = _query.trim();
    if (query.isEmpty) return;
    final lower = query.toLowerCase();
    for (final host in _hosts) {
      if (host.label.toLowerCase() == lower ||
          host.address.toLowerCase() == lower) {
        _connect(host);
        return;
      }
    }
    var user = '';
    var addressPort = query;
    final at = query.indexOf('@');
    if (at > 0) {
      user = query.substring(0, at);
      addressPort = query.substring(at + 1);
    }
    var address = addressPort;
    var port = 22;
    final colon = addressPort.lastIndexOf(':');
    if (colon > 0 && !addressPort.contains(']')) {
      address = addressPort.substring(0, colon);
      port = int.tryParse(addressPort.substring(colon + 1)) ?? 22;
    }
    if (address.isEmpty) return;
    final host = await _createSessionFor(
      kind: 'ssh',
      label: query,
      address: address,
      port: port,
      username: user,
    );
    if (host != null) _connect(host);
  }

  /// Collapse the slider; the panel content stays mounted for the next open.
  void _closeDrawer() => setState(() => _drawerOpen = false);

  /// A plain card click connects immediately — the desktop fast path.
  void _onCardTap(Host host) => _connect(host);

  /// The hover pencil opens the details drawer (edit path).
  void _onEditHost(Host host) => setState(() {
    _drawerHost = host;
    _drawerOpen = true;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hosts = _filtered;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The hosts content: search row, toolbar, section title, grid. The
        // drawer is its SIBLING, so it spans the full content height from the
        // title bar down — exactly the original's RelativeSlider, whose
        // header sits level with the search row instead of below the toolbar.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header band: search row + toolbar on --dark-grey-3 ──────
              // The original's hosts header sits on a lighter surface than
              // the page, and the rail shares that surface.
              Container(
                color: const Color(0xFF282B3D), // --dark-grey-3
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search + Connect (inside the field).
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: TermiusMetrics.searchFieldFill,
                          borderRadius: BorderRadius.circular(
                            TermiusRadius.field,
                          ),
                        ),
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('host-search'),
                                controller: _search,
                                border: Border.all(color: Colors.transparent),
                                borderRadius: BorderRadius.circular(
                                  TermiusRadius.field,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(TermiusRadius.field),
                                  ),
                                ),
                                placeholder: Text(
                                  'Find a host or ssh user@hostname...',
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
                            // Connect lives INSIDE the field; the original
                            // keeps it a muted text button in every state (the
                            // blue Connect is the drawer's).
                            GhostButton(
                              key: const ValueKey('quick-connect'),
                              density: ButtonDensity.compact,
                              onPressed: _query.trim().isEmpty
                                  ? null
                                  : _quickConnect,
                              child: Text(
                                'Connect',
                                style: theme.typography.normal.copyWith(
                                  fontSize: 13,
                                  color: _query.trim().isEmpty
                                      ? theme.colorScheme.mutedForeground
                                      : theme.colorScheme.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Toolbar row.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                      child: Row(
                        children: [
                          SplitButton(
                            label: 'New host',
                            icon: LucideIcons.plus,
                            onPressed: _createSession,
                          ),
                          const SizedBox(width: 20),
                          GhostAction(
                            icon: LucideIcons.terminal,
                            label: 'Terminal',
                            onPressed: _quickLocal,
                          ),
                          const SizedBox(width: 20),
                          GhostAction(
                            icon: LucideIcons.usb,
                            label: 'Serial',
                            onPressed: _quickSerial,
                          ),
                          const Spacer(),
                          IconToggleButton(
                            icon: _layout == HostsLayout.cards
                                ? LucideIcons.layoutGrid
                                : LucideIcons.list,
                            onPressed: () => setState(
                              () => _layout = _layout == HostsLayout.cards
                                  ? HostsLayout.rows
                                  : HostsLayout.cards,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            key: const ValueKey('new-host-fab'),
                            onTap: _createSession,
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF21B568),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF21B568)
                                      .withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.plus,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Section title + cards ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 0, 12),
                child: Text(
                  'Hosts',
                  style: theme.typography.bold.copyWith(
                    fontSize: 18,
                    color: theme.colorScheme.foreground,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            size: 20,
                            strokeWidth: 2,
                          ),
                        )
                      : _loadError != null
                      ? _ErrorState(message: _loadError!, onRetry: _reload)
                      : hosts.isEmpty
                      ? const _EmptyState()
                      : _layout == HostsLayout.cards
                      ? _cardGrid(hosts)
                      : _rowList(hosts),
                ),
              ),
            ],
          ),
        ),
        // The details drawer: a 340px panel revealed from the right exactly
        // like Termius's RelativeSlider (min-width 0→340, 200ms). It spans
        // the whole content height; the hosts column reflows beside it.
        _DrawerSlider(
          open: _drawerOpen,
          child: _drawerHost == null
              ? const SizedBox.shrink()
              : HostDetailsPanel(
                  host: _drawerHost!,
                  onClose: _closeDrawer,
                  onConnect: () {
                    final host = _drawerHost;
                    _closeDrawer();
                    _connect(host);
                  },
                  onSave: _saveHostToCore,
                  onDelete: _deleteHostToCore,
                ),
        ),
      ],
    );
  }

  Widget _cardGrid(List<Host> hosts) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // Original: 3 columns at a 1280-wide window, cards ≈347×60 logical,
        // 10px gaps — measured from the reference screenshot (520×90 physical
        // at 1.5 DPR). The delegate rounds up, so 350 yields three columns.
        maxCrossAxisExtent: 350,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 347 / 60,
      ),
      itemCount: hosts.length,
      itemBuilder: (context, index) {
        final host = hosts[index];
        return HostCard.grid(
          host: host,
          selected: _drawerOpen && _drawerHost?.id == host.id,
          onTap: () => _onCardTap(host),
          onEdit: () => _onEditHost(host),
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
            onEdit: () => _onEditHost(host),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.server,
            size: 34,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(height: 12),
          Text(
            'No hosts yet',
            style: theme.typography.semiBold.copyWith(
              fontSize: 16,
              color: theme.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hosts saved by the XenTerm core appear here.',
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.circleAlert,
            size: 30,
            color: theme.colorScheme.destructive,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load hosts',
            style: theme.typography.semiBold.copyWith(
              fontSize: 16,
              color: theme.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.typography.normal.copyWith(
                fontSize: 12,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GhostButton(
            density: ButtonDensity.compact,
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Termius's RelativeSlider: the panel is laid out at its full width and the
/// container's width animates 0↔340 with the content anchored right, so the
/// drawer slides in/out instead of stretching its children. 200ms, ease —
/// the exact `sliderAnimationDuration` and default timing function.
class _DrawerSlider extends StatefulWidget {
  final bool open;
  final Widget child;

  const _DrawerSlider({required this.open, required this.child});

  @override
  State<_DrawerSlider> createState() => _DrawerSliderState();
}

class _DrawerSliderState extends State<_DrawerSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TermiusMotion.micro,
    reverseDuration: TermiusMotion.micro,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(_DrawerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      widget.open ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ClipRect(
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: _controller.value,
          child: child,
        ),
      ),
      child: SizedBox(width: 340, child: widget.child),
    );
  }
}
