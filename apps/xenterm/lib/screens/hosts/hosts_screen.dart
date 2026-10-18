/// The Hosts screen — faithful to the original screenshots:
/// search+Connect row, split [New host|▾] + Terminal + Serial toolbar with
/// grid/tag/keyboard/avatar/+ at right, a bold "主机" section title over the
/// card grid, cards with colored OS chips and a hover edit-pencil.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../data/host_os_registry.dart';
import '../../data/hosts.dart';
import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';
import 'host_card.dart';
import 'host_details_panel.dart';
import 'serial_details_panel.dart';

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
  int? baudRate,
  int? dataBits,
  int? stopBits,
  String? parity,
  String? flowControl,
  String? password,
  bool? clearPassword,
  String? jumpHostId,
});
typedef HostDeleter = Future<CoreWriteResult> Function(String id);
typedef GroupLoader = Future<List<HostGroup>> Function();
typedef GroupCreator = Future<CoreWriteResult> Function(String name);
typedef GroupRenamer = Future<CoreWriteResult> Function(
  String old,
  String next,
);
typedef GroupDeleter = Future<CoreWriteResult> Function(String name);
typedef GroupCollapser = Future<CoreWriteResult> Function(
  String name,
  bool collapsed,
);
typedef HostImporter = Future<ImportResult> Function();

class HostsScreen extends StatefulWidget {
  final ValueChanged<Host>? onConnect;

  /// Session source; defaults to the Rust core through the FFI bridge.
  final Future<List<Host>> Function()? loadHosts;

  /// Incremented by the title bar's + button to open the New host drawer.
  final ValueListenable<int>? newHostRequest;

  /// Test seams; production uses the FFI bridge.
  final HostSaver? saveSession;
  final HostDeleter? deleteSession;

  /// Folder (group) source and mutations; production uses the FFI bridge.
  final GroupLoader? loadGroups;
  final GroupCreator? createGroup;
  final GroupRenamer? renameGroup;
  final GroupDeleter? deleteGroup;
  final GroupCollapser? collapseGroup;

  /// OpenSSH config importer; production reads `~/.ssh/config` through the core.
  final HostImporter? importHosts;

  /// Serial device enumeration for the serial modal (test seam).
  final SerialPortLoader? loadSerialPorts;

  const HostsScreen({
    super.key,
    this.onConnect,
    this.loadHosts,
    this.newHostRequest,
    this.saveSession,
    this.deleteSession,
    this.loadGroups,
    this.createGroup,
    this.renameGroup,
    this.deleteGroup,
    this.collapseGroup,
    this.importHosts,
    this.loadSerialPorts,
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
  List<HostGroup> _groups = const [];
  bool _loading = true;
  String? _loadError;

  /// Inline group editor: null = closed; `renaming == null` = create.
  bool _groupEditorOpen = false;
  String? _renaming;
  final TextEditingController _groupName = TextEditingController();
  String? _groupError;

  /// Group awaiting delete confirmation.
  String? _deletingGroup;

  /// Serial modal: null host creates, non-null edits that session.
  bool _serialPanelOpen = false;
  Host? _serialHost;
  String? _serialError;

  /// Result banner for the OpenSSH config import.
  String? _importNotice;
  bool _importError = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    widget.newHostRequest?.addListener(_onNewHostRequest);
    hostOsRegistry.addListener(_onOsDetected);
    _reload();
  }

  void _onOsDetected() {
    if (mounted) setState(() {});
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
      // Widget tests inject only the host loader; don't reach for the FFI
      // group store unless production wiring (or a group seam) is present.
      final groups = widget.loadGroups != null
          ? await widget.loadGroups!()
          : widget.loadHosts != null
          ? const <HostGroup>[]
          : await loadGroupsFromCore();
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _groups = groups;
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
    hostOsRegistry.removeListener(_onOsDetected);
    _search.dispose();
    _groupName.dispose();
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
  Future<String?> _saveHostToCore(Host host, {String password = ''}) async {
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
        baudRate: host.baudRate,
        dataBits: host.dataBits,
        stopBits: host.stopBits,
        parity: host.parity,
        flowControl: host.flowControl,
        password: password,
        jumpHostId: host.jumpHostId,
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
    String group = '',
    int baudRate = 115200,
    int dataBits = 8,
    int stopBits = 1,
    String parity = 'none',
    String flowControl = 'none',
    String password = '',
  }) async {
    try {
      final result = await (widget.saveSession ?? saveSessionToCore)(
        id: '',
        label: label,
        address: address,
        port: port,
        username: username,
        group: group,
        kind: kind,
        baudRate: baudRate,
        dataBits: dataBits,
        stopBits: stopBits,
        parity: parity,
        flowControl: flowControl,
        password: password,
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
  void _quickLocal() {
    // A local shell is a temporary tab: the toolbar is its dedicated entry, so
    // there is nothing to persist and nothing to clutter Home with.
    _connect(
      Host(
        id: 'adhoc-local-${DateTime.now().microsecondsSinceEpoch}',
        label: 'Local terminal',
        address: '',
        username: '',
        protocol: 'local',
        ephemeral: true,
      ),
    );
  }

  /// The toolbar's Serial action: Termius's serial connection modal, where the
  /// port and line parameters are chosen before the session exists.
  void _quickSerial() {
    setState(() {
      _serialHost = null;
      _serialError = null;
      _drawerHost = null;
      _serialPanelOpen = true;
      _drawerOpen = true;
    });
  }

  Future<void> _submitSerial(SerialDraft draft) async {
    Host? target;
    final editing = _serialHost;
    if (editing == null) {
      // Connecting from the toolbar is temporary; only editing an existing
      // serial host writes to the store.
      target = Host(
        id: 'adhoc-serial-${DateTime.now().microsecondsSinceEpoch}',
        label: draft.label,
        address: draft.port,
        port: 22,
        username: draft.username,
        group: draft.group,
        protocol: 'serial',
        baudRate: draft.baudRate,
        dataBits: draft.dataBits,
        stopBits: draft.stopBits,
        parity: draft.parity,
        flowControl: draft.flowControl,
        ephemeral: true,
        adhocPassword: draft.password,
      );
    } else {
      final updated = Host(
        id: editing.id,
        label: draft.label,
        address: draft.port,
        port: editing.port,
        username: draft.username,
        group: draft.group,
        tags: editing.tags,
        os: editing.os,
        lastUsed: editing.lastUsed,
        protocol: 'serial',
        auth: editing.auth,
        keyPath: editing.keyPath,
        baudRate: draft.baudRate,
        dataBits: draft.dataBits,
        stopBits: draft.stopBits,
        parity: draft.parity,
        flowControl: draft.flowControl,
        hasPassword: editing.hasPassword || draft.password.isNotEmpty,
      );
      final error = await _saveHostToCore(updated, password: draft.password);
      if (error != null) {
        if (mounted) setState(() => _serialError = error);
        return;
      }
      for (final host in _hosts) {
        if (host.id == editing.id) {
          target = host;
          break;
        }
      }
      target ??= updated;
    }
    if (!mounted) return;
    setState(() {
      _serialPanelOpen = false;
      _drawerOpen = false;
    });
    _connect(target);
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

  void _closeSerialPanel() => setState(() {
    _serialPanelOpen = false;
    _drawerOpen = false;
  });

  // ── Groups (folders) ───────────────────────────────────────────────────

  void _openGroupEditor({String? rename}) {
    setState(() {
      _groupEditorOpen = true;
      _renaming = rename;
      _groupName.text = rename ?? '';
      _groupError = null;
      _deletingGroup = null;
    });
  }

  void _closeGroupEditor() => setState(() {
    _groupEditorOpen = false;
    _renaming = null;
    _groupError = null;
  });

  Future<void> _saveGroup() async {
    final name = _groupName.text.trim();
    if (name.isEmpty) {
      setState(() => _groupError = 'Enter a group name');
      return;
    }
    final renaming = _renaming;
    try {
      final result = renaming == null
          ? await (widget.createGroup ?? createGroupInCore)(name)
          : await (widget.renameGroup ?? renameGroupInCore)(renaming, name);
      if (!result.ok) {
        setState(
          () => _groupError = result.error ?? 'Could not save the group',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _groupEditorOpen = false;
        _renaming = null;
        _groupError = null;
      });
      await _reload(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _groupError = '$error');
    }
  }

  Future<void> _deleteGroupNamed(String name) async {
    try {
      final result = await (widget.deleteGroup ?? deleteGroupFromCore)(name);
      if (!result.ok) {
        setState(
          () => _loadError = result.error ?? 'Could not delete the group',
        );
        return;
      }
      if (!mounted) return;
      setState(() => _deletingGroup = null);
      await _reload(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = '$error');
    }
  }

  Future<void> _toggleGroup(HostGroup group) async {
    final collapsed = !group.collapsed;
    setState(() {
      _groups = [
        for (final g in _groups)
          g.name == group.name
              ? HostGroup(name: g.name, collapsed: collapsed)
              : g,
      ];
    });
    try {
      final result = await (widget.collapseGroup ?? collapseGroupInCore)(
        group.name,
        collapsed,
      );
      if (!result.ok && mounted) {
        await _reload(silent: true);
      }
    } catch (_) {
      if (mounted) await _reload(silent: true);
    }
  }

  Future<void> _newHostInGroup(String group) async {
    final host = await _createSessionFor(
      kind: 'ssh',
      label: 'New Host',
      group: group,
    );
    if (host == null || !mounted) return;
    setState(() {
      _drawerHost = host;
      _drawerOpen = true;
    });
  }

  /// Imports `~/.ssh/config` through the core; the result stays in a banner.
  Future<void> _importHosts() async {
    setState(() {
      _importing = true;
      _importNotice = null;
      _importError = false;
    });
    try {
      final result = await (widget.importHosts ?? importSshConfigToCore)();
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importError = !result.ok;
        _importNotice = result.ok
            ? result.message
            : (result.error ?? 'Import failed');
      });
      if (result.ok && result.added > 0) await _reload(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importError = true;
        _importNotice = '$error';
      });
    }
  }

  /// A plain card click connects immediately — the desktop fast path.
  void _onCardTap(Host host) => _connect(host);

  /// The hover pencil opens the matching editor: serial hosts use the serial
  /// modal (line parameters), everything else the SSH details drawer.
  void _onEditHost(Host host) {
    if (host.isSerial) {
      setState(() {
        _serialHost = host;
        _serialError = null;
        _drawerHost = null;
        _serialPanelOpen = true;
        _drawerOpen = true;
      });
      return;
    }
    setState(() {
      _serialPanelOpen = false;
      _drawerHost = host;
      _drawerOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hosts = _filtered;

    final content = Row(
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
                      child: TermiusField(
                        key: const ValueKey('host-search'),
                        controller: _search,
                        placeholder: 'Find a host or ssh user@hostname...',
                        onChanged: (v) => setState(() => _query = v),
                        // Connect lives INSIDE the field; the original keeps it
                        // a muted text button in every state (the blue Connect
                        // is the drawer's).
                        trailing: GhostButton(
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
                            menuItems: [
                              SplitMenuEntry(
                                icon: LucideIcons.folderPlus,
                                label: 'New group',
                                onTap: _openGroupEditor,
                              ),
                              SplitMenuEntry(
                                icon: LucideIcons.import,
                                label: 'Import hosts',
                                onTap: _importHosts,
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          GhostAction(
                            icon: LucideIcons.terminal,
                            label: 'Terminal',
                            onPressed: _quickLocal,
                          ),
                          const SizedBox(width: 20),
                          GhostAction(
                            icon: LucideIcons.ethernetPort,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Inline group editor / import result ─────────────────────
              if (_groupEditorOpen) _groupEditorBar(theme),
              if (_importNotice != null) _importBanner(theme),
              // ── Section titles + cards ──────────────────────────────────
              if (_groups.isEmpty || _query.trim().isNotEmpty)
                _sectionTitle('Home', theme),
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
                      : hosts.isEmpty && _groups.isEmpty
                      ? const _EmptyState()
                      : _groups.isEmpty || _query.trim().isNotEmpty
                      ? (hosts.isEmpty
                            ? const _EmptyState()
                            : _layout == HostsLayout.cards
                            ? _cardGrid(hosts)
                            : _rowList(hosts))
                      : _groupedList(theme),
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
          child: _serialPanelOpen
              ? SerialDetailsPanel(
                  host: _serialHost,
                  loadPorts: widget.loadSerialPorts,
                  error: _serialError,
                  onSubmit: _submitSerial,
                  onClose: _closeSerialPanel,
                )
              : _drawerHost == null
              ? const SizedBox.shrink()
              : HostDetailsPanel(
                  host: _drawerHost!,
                  hosts: _hosts,
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
    return content;
  }

  Widget _groupEditorBar(ThemeData theme) {
    final renaming = _renaming;
    return Container(
      color: const Color(0xFF282B3D),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                renaming == null ? LucideIcons.folderPlus : LucideIcons.pencil,
                size: 16,
                color: theme.colorScheme.foreground,
              ),
              const SizedBox(width: 8),
              Text(
                renaming == null ? 'New group' : 'Rename group',
                style: theme.typography.medium.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TermiusField(
                  key: const ValueKey('group-name'),
                  controller: _groupName,
                  autofocus: true,
                  onSubmitted: (_) => _saveGroup(),
                  placeholder: 'Group name (for example: Production)',
                ),
              ),
              const SizedBox(width: 10),
              Button(
                key: const ValueKey('group-save'),
                onPressed: _saveGroup,
                style: const ButtonStyle.primary(),
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              GhostButton(
                key: const ValueKey('group-cancel'),
                onPressed: _closeGroupEditor,
                child: const Text('Cancel'),
              ),
            ],
          ),
          if (_groupError != null) ...[
            const SizedBox(height: 6),
            Text(
              _groupError!,
              style: theme.typography.normal.copyWith(
                fontSize: 12,
                color: theme.colorScheme.destructive,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _importBanner(ThemeData theme) {
    return Container(
      key: const ValueKey('import-banner'),
      color: _importError ? const Color(0xFF3A2028) : const Color(0xFF1F2C24),
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
      child: Row(
        children: [
          Icon(
            _importing
                ? LucideIcons.loader
                : _importError
                ? LucideIcons.circleAlert
                : LucideIcons.circleCheck,
            size: 15,
            color: _importError
                ? theme.colorScheme.destructive
                : const Color(0xFF21B568),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _importNotice!,
              style: theme.typography.normal.copyWith(
                fontSize: 12,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('import-dismiss'),
            onTap: () => setState(() => _importNotice = null),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.x,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 0, 12),
      child: Text(
        title,
        style: theme.typography.bold.copyWith(
          fontSize: 18,
          color: theme.colorScheme.foreground,
        ),
      ),
    );
  }

  /// Named groups plus the ungrouped bucket, in core display order.
  List<_HostSection> get _sections {
    final byGroup = <String, List<Host>>{};
    final ungrouped = <Host>[];
    for (final host in _hosts) {
      final group = host.group.trim();
      final reserved =
          group.toLowerCase() == 'default' || group.toLowerCase() == 'system';
      if (group.isEmpty || reserved) {
        ungrouped.add(host);
      } else {
        byGroup.putIfAbsent(group, () => []).add(host);
      }
    }
    final known = <String>{
      for (final group in _groups) group.name.toLowerCase(),
    };
    final names = <String>[
      for (final group in _groups) group.name,
      for (final name in byGroup.keys)
        if (!known.contains(name.toLowerCase())) name,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      if (ungrouped.isNotEmpty || names.isEmpty)
        _HostSection(name: null, collapsed: false, hosts: ungrouped),
      for (final name in names)
        _HostSection(
          name: name,
          collapsed: _groups.any((g) => g.name == name && g.collapsed),
          hosts: byGroup[name] ?? const [],
        ),
    ];
  }

  Widget _groupedList(ThemeData theme) {
    final sections = _sections;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final section in sections) ...[
          if (section.name == null)
            _sectionTitle('Home', theme)
          else
            _deletingGroup == section.name
                ? _deleteGroupBar(section.name!, theme)
                : _GroupHeader(
                    key: ValueKey('group-header-${section.name}'),
                    name: section.name!,
                    count: section.hosts.length,
                    collapsed: section.collapsed,
                    theme: theme,
                    onToggle: () => _toggleGroup(
                      HostGroup(
                        name: section.name!,
                        collapsed: section.collapsed,
                      ),
                    ),
                    onRename: () => _openGroupEditor(rename: section.name),
                    onDelete: () =>
                        setState(() => _deletingGroup = section.name),
                    onAdd: () => _newHostInGroup(section.name!),
                  ),
          if (section.name == null || !section.collapsed)
            Padding(
              padding: EdgeInsets.fromLTRB(
                section.name == null ? 0 : 12,
                0,
                0,
                section.name == null ? 0 : 14,
              ),
              child: section.hosts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No hosts in this group yet.',
                        style: theme.typography.normal.copyWith(
                          fontSize: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    )
                  : _layout == HostsLayout.cards
                  ? _cardGrid(section.hosts, shrinkWrap: true)
                  : _rowList(section.hosts, shrinkWrap: true),
            ),
        ],
      ],
    );
  }

  Widget _deleteGroupBar(String name, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF282B3D),
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 16,
            color: theme.colorScheme.destructive,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Delete “$name”? Its hosts become ungrouped.',
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          Button(
            key: const ValueKey('group-delete-confirm'),
            onPressed: () => _deleteGroupNamed(name),
            style: const ButtonStyle.primary(),
            child: const Text('Delete'),
          ),
          const SizedBox(width: 8),
          GhostButton(
            onPressed: () => setState(() => _deletingGroup = null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Applies the OS detected on the last connection without touching the
  /// stored session.
  Host _displayed(Host host) => host.copyWith(os: hostOsRegistry.of(host.id));

  Widget _cardGrid(List<Host> hosts, {bool shrinkWrap = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        // Keep cards wide enough to read when the window shrinks; the original
        // squeezes columns down to an unusable width instead.
        const minCardWidth = 260.0;
        final available = constraints.maxWidth;
        final columns = available.isFinite
            ? ((available + gap) / (minCardWidth + gap)).floor().clamp(1, 6)
            : 3;
        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: 60,
          ),
          itemCount: hosts.length,
          itemBuilder: (context, index) {
            final host = _displayed(hosts[index]);
            return HostCard.grid(
              host: host,
              selected: _drawerOpen && _drawerHost?.id == host.id,
              onTap: () => _onCardTap(hosts[index]),
              onEdit: () => _onEditHost(hosts[index]),
            );
          },
        );
      },
    );
  }

  Widget _rowList(List<Host> hosts, {bool shrinkWrap = false}) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: hosts.length,
      itemBuilder: (context, index) {
        final host = _displayed(hosts[index]);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: HostCard.row(
            host: host,
            selected: _drawerOpen && _drawerHost?.id == host.id,
            onTap: () => _onCardTap(hosts[index]),
            onEdit: () => _onEditHost(hosts[index]),
          ),
        );
      },
    );
  }
}

class _HostSection {
  final String? name;
  final bool collapsed;
  final List<Host> hosts;

  const _HostSection({
    required this.name,
    required this.collapsed,
    required this.hosts,
  });
}

/// Folder header: chevron + folder glyph + name + count, with hover actions.
class _GroupHeader extends StatefulWidget {
  final String name;
  final int count;
  final bool collapsed;
  final ThemeData theme;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAdd;

  const _GroupHeader({
    super.key,
    required this.name,
    required this.count,
    required this.collapsed,
    required this.theme,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  State<_GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<_GroupHeader> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: Row(
            children: [
              AnimatedRotation(
                turns: widget.collapsed ? -0.25 : 0,
                duration: TermiusMotion.micro,
                curve: TermiusMotion.easeOut,
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                widget.collapsed ? LucideIcons.folder : LucideIcons.folderOpen,
                size: 16,
                color: const Color(0xFF8D91A5),
              ),
              const SizedBox(width: 8),
              Text(
                widget.name,
                style: theme.typography.semiBold.copyWith(
                  fontSize: 15,
                  color: theme.colorScheme.foreground,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.count}',
                style: theme.typography.normal.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: _hovering ? 1 : 0,
                duration: TermiusMotion.micro,
                child: Row(
                  children: [
                    _HeaderAction(
                      key: ValueKey('group-add-${widget.name}'),
                      icon: LucideIcons.plus,
                      tooltip: 'New host in ${widget.name}',
                      onTap: widget.onAdd,
                    ),
                    _HeaderAction(
                      key: ValueKey('group-rename-${widget.name}'),
                      icon: LucideIcons.pencil,
                      tooltip: 'Rename group',
                      onTap: widget.onRename,
                    ),
                    _HeaderAction(
                      key: ValueKey('group-delete-${widget.name}'),
                      icon: LucideIcons.trash2,
                      tooltip: 'Delete group',
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      tooltip: (_) => Text(tooltip),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(left: 2),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: theme.colorScheme.mutedForeground),
        ),
      ),
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
