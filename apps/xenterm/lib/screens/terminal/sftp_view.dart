/// The SFTP workspace: a real remote browser over the core's SFTP worker.
///
/// The view opens a dedicated SSH/SFTP connection for the host, polls the
/// core's snapshot, and performs real directory navigation, uploads, downloads,
/// folder creation and deletion. It is not a mock: every action is a command to
/// the Rust worker and every row comes from a live listing.
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../data/hosts.dart';
import '../../terminal/core_settings.dart';
import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';
import 'connection_prompt.dart';

class SftpView extends StatefulWidget {
  final Host host;
  final CoreSettingsController? settings;

  /// Test seam for the download directory picker.
  final Future<String?> Function()? pickDownloadDirectory;
  final Future<String?> Function()? pickUploadFile;

  const SftpView({
    super.key,
    required this.host,
    this.settings,
    this.pickDownloadDirectory,
    this.pickUploadFile,
  });

  @override
  State<SftpView> createState() => _SftpViewState();
}

class _SftpViewState extends State<SftpView> {
  NativeBridge? _bridge;
  int? _handle;
  Timer? _poll;
  SftpSnapshot _snapshot = const SftpSnapshot();
  String? _error;
  bool _starting = true;
  int _lastVersion = 0;

  /// The core seeds the root open, but its first listing can race that
  /// command; expand `/` once here so the tree never opens bare.
  bool _autoExpandedRoot = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.host.protocol != 'ssh') {
      setState(() {
        _starting = false;
        _error = 'SFTP needs an SSH host.';
      });
      return;
    }
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      setState(() {
        _starting = false;
        _error = 'xenterm_bridge library not found next to the app';
      });
      return;
    }
    _bridge = bridge;
    try {
      final handle = bridge.startSftp(widget.host.id);
      if (!mounted) {
        bridge.sftpClose(handle);
        return;
      }
      setState(() {
        _handle = handle;
        _starting = false;
      });
      _poll = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
      _tick();
    } catch (error) {
      setState(() {
        _starting = false;
        _error = error is NativeBridgeError ? error.message : '$error';
      });
    }
  }

  void _tick() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) return;
    final version = bridge.sftpVersion(handle);
    if (version == _lastVersion) return;
    _lastVersion = version;
    final raw = bridge.sftpSnapshot(handle);
    if (raw == null) return;
    final snapshot = SftpSnapshot.fromCoreJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    if (!_autoExpandedRoot && snapshot.tree.isNotEmpty) {
      _autoExpandedRoot = true;
      final root = snapshot.tree.firstWhere(
        (node) => node.path == '/',
        orElse: () => snapshot.tree.first,
      );
      if (!root.expanded) {
        bridge.sftpToggleTree(handle, root.path);
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    final handle = _handle;
    if (handle != null) _bridge?.sftpClose(handle);
    super.dispose();
  }

  void _retry() {
    _poll?.cancel();
    final handle = _handle;
    if (handle != null) _bridge?.sftpClose(handle);
    setState(() {
      _handle = null;
      _snapshot = const SftpSnapshot();
      _error = null;
      _starting = true;
      _lastVersion = 0;
      _autoExpandedRoot = false;
    });
    _start();
  }

  Future<String?> _downloadDirectory() async {
    final configured = widget.settings?.settings.downloadDir ?? '';
    if (configured.isNotEmpty) return configured;
    final picker = widget.pickDownloadDirectory ?? getDirectoryPath;
    return picker();
  }

  Future<void> _download(SftpEntry entry) async {
    final directory = await _downloadDirectory();
    if (directory == null || directory.isEmpty) return;
    _bridge?.sftpDownload(_handle!, entry.path, directory);
  }

  Future<void> _upload() async {
    final picker = widget.pickUploadFile;
    final file = picker != null ? await picker() : (await openFile())?.path;
    if (file == null || file.isEmpty) return;
    _bridge?.sftpUpload(_handle!, file);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF141729),
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF262A3D))),
            ),
            child: Row(
              children: [
                Text(
                  'SFTP · ${widget.host.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC7CBD6),
                  ),
                ),
                const Spacer(),
                if (_starting)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: SftpTree(
                    nodes: _snapshot.tree,
                    onOpen: (path) => _bridge?.sftpList(_handle!, path),
                    onToggle: (path) => _bridge?.sftpToggleTree(_handle!, path),
                  ),
                ),
                Container(width: 1, color: const Color(0xFF262A3D)),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'SFTP unavailable\n$_error',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF8D91A5),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Button(
                                        style: const ButtonStyle.outline(),
                                        onPressed: _retry,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SftpBrowser(
                                snapshot: _snapshot,
                                onOpenDirectory: (path) =>
                                    _bridge?.sftpList(_handle!, path),
                                onRefresh: () => _bridge?.sftpRefresh(_handle!),
                                onDownload: _download,
                                onUpload: _upload,
                                onCreateFolder: (name) =>
                                    _bridge?.sftpMkdir(_handle!, name),
                                onDelete: (entry) =>
                                    _bridge?.sftpDelete(_handle!, entry.path),
                              ),
                      ),
                      if (_snapshot.prompt != null && _error == null)
                        Positioned(
                          left: 12,
                          right: 12,
                          top: 12,
                          child: ConnectionPromptBanner(
                            prompt: _snapshot.prompt!,
                            onAnswer: (accept, {username, password, text}) {
                              final handle = _handle;
                              if (handle == null) return;
                              final promptId =
                                  (_snapshot.prompt?['id'] as num?)?.toInt() ??
                                  0;
                              _bridge?.answerSftpPrompt(
                                handle,
                                promptId,
                                accept: accept,
                                username: username,
                                password: password,
                                text: text,
                              );
                            },
                          ),
                        ),
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
}

/// The remote folder tree (directories only), rooted at "/".
class SftpTree extends StatelessWidget {
  final List<SftpTreeNode> nodes;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onToggle;

  const SftpTree({super.key, required this.nodes, this.onOpen, this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF161A2C),
      child: nodes.isEmpty
          ? const Center(
              child: Text(
                'Folders',
                style: TextStyle(fontSize: 11, color: Color(0xFF5A5F73)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: nodes.length,
              itemBuilder: (context, index) {
                final node = nodes[index];
                return _TreeRow(
                  key: ValueKey('sftp-tree-${node.path}'),
                  node: node,
                  onOpen: () => onOpen?.call(node.path),
                  onToggle: () => onToggle?.call(node.path),
                );
              },
            ),
    );
  }
}

class _TreeRow extends StatefulWidget {
  final SftpTreeNode node;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  const _TreeRow({
    super.key,
    required this.node,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Container(
          height: 28,
          color: _hover ? const Color(0xFF282B3D) : Colors.transparent,
          padding: EdgeInsets.only(left: 6.0 + node.depth * 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: node.hasChildren ? widget.onToggle : null,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: node.hasChildren
                      ? Icon(
                          node.expanded
                              ? LucideIcons.chevronDown
                              : LucideIcons.chevronRight,
                          size: 13,
                          color: const Color(0xFF8D91A5),
                        )
                      : null,
                ),
              ),
              const Icon(
                LucideIcons.folder,
                size: 14,
                color: Color(0xFFF8AA4B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFC7CBD6),
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

/// Presentational browser, kept separate so widget tests can drive it with a
/// snapshot without loading the native bridge.
class SftpBrowser extends StatefulWidget {
  final SftpSnapshot snapshot;
  final ValueChanged<String>? onOpenDirectory;
  final VoidCallback? onRefresh;
  final ValueChanged<SftpEntry>? onDownload;
  final VoidCallback? onUpload;
  final ValueChanged<String>? onCreateFolder;
  final ValueChanged<SftpEntry>? onDelete;

  const SftpBrowser({
    super.key,
    required this.snapshot,
    this.onOpenDirectory,
    this.onRefresh,
    this.onDownload,
    this.onUpload,
    this.onCreateFolder,
    this.onDelete,
  });

  @override
  State<SftpBrowser> createState() => _SftpBrowserState();
}

class _SftpBrowserState extends State<SftpBrowser> {
  SftpEntry? _selected;
  bool _creating = false;
  SftpEntry? _pendingDelete;
  final TextEditingController _folderName = TextEditingController();

  @override
  void dispose() {
    _folderName.dispose();
    super.dispose();
  }

  String get _path {
    final path = widget.snapshot.path;
    return path == '.' ? '~' : path;
  }

  String get _parent {
    final path = widget.snapshot.path;
    if (path == '.' || path == '/' || path.isEmpty) return '.';
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final cut = trimmed.lastIndexOf('/');
    return cut <= 0 ? '/' : trimmed.substring(0, cut);
  }

  void _open(SftpEntry entry) {
    if (entry.isDir) {
      widget.onOpenDirectory?.call(entry.path);
    } else {
      widget.onDownload?.call(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              _ToolAction(
                icon: LucideIcons.arrowUp,
                tooltip: 'Parent folder',
                onTap: () => widget.onOpenDirectory?.call(_parent),
              ),
              _ToolAction(
                icon: LucideIcons.refreshCw,
                tooltip: 'Refresh',
                onTap: widget.onRefresh,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _path,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontFamilyFallback: ['Menlo', 'Courier New'],
                    fontSize: 12.5,
                    color: Color(0xFFC7CBD6),
                  ),
                ),
              ),
              if (_selected != null && !_selected!.isDir) ...[
                _ToolAction(
                  icon: LucideIcons.download,
                  tooltip: 'Download ${_selected!.name}',
                  onTap: () => widget.onDownload?.call(_selected!),
                ),
                const SizedBox(width: 2),
              ],
              if (_selected != null)
                _ToolAction(
                  icon: LucideIcons.trash2,
                  tooltip: 'Delete ${_selected!.name}',
                  onTap: () => setState(() => _pendingDelete = _selected),
                ),
              _ToolAction(
                icon: LucideIcons.upload,
                tooltip: 'Upload a file here',
                onTap: widget.onUpload,
              ),
              _ToolAction(
                icon: LucideIcons.folderPlus,
                tooltip: 'New folder',
                onTap: () => setState(() {
                  _creating = true;
                  _folderName.clear();
                }),
              ),
            ],
          ),
        ),
        if (_creating)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: TermiusField(
                    key: const ValueKey('sftp-new-folder-name'),
                    controller: _folderName,
                    autofocus: true,
                    placeholder: 'Folder name',
                  ),
                ),
                const SizedBox(width: 8),
                Button(
                  style: const ButtonStyle.primary(),
                  onPressed: () {
                    final name = _folderName.text.trim();
                    if (name.isEmpty) return;
                    widget.onCreateFolder?.call(name);
                    setState(() => _creating = false);
                  },
                  child: const Text('Create'),
                ),
                const SizedBox(width: 6),
                Button(
                  style: const ButtonStyle.outline(),
                  onPressed: () => setState(() => _creating = false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        if (_pendingDelete != null)
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x33E5484D),
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Delete “${_pendingDelete!.name}”? This cannot be undone.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFFF8A8D),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _pendingDelete = null),
                  child: const Text('Cancel'),
                ),
                Button(
                  style: const ButtonStyle.destructive(),
                  onPressed: () {
                    widget.onDelete?.call(_pendingDelete!);
                    setState(() {
                      _pendingDelete = null;
                      _selected = null;
                    });
                  },
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
        if (snapshot.error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x33E5484D),
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            child: Text(
              snapshot.error!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFFF8A8D)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: const [
              Expanded(child: _Header('Name')),
              SizedBox(width: 90, child: _Header('Size')),
              SizedBox(width: 140, child: _Header('Modified')),
              SizedBox(width: 90, child: _Header('Mode')),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: snapshot.loading && snapshot.entries.isEmpty
              ? const Center(
                  child: Text(
                    'Loading folder…',
                    style: TextStyle(color: Color(0xFF8D91A5)),
                  ),
                )
              : snapshot.entries.isEmpty && snapshot.error != null
              ? const SizedBox.shrink()
              : snapshot.entries.isEmpty
              ? const Center(
                  child: Text(
                    'This folder is empty',
                    style: TextStyle(color: Color(0xFF8D91A5)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: snapshot.entries.length,
                  itemBuilder: (context, index) {
                    final entry = snapshot.entries[index];
                    return _EntryRow(
                      key: ValueKey('sftp-${entry.path}'),
                      entry: entry,
                      selected: _selected?.path == entry.path,
                      onTap: () {
                        setState(() => _selected = entry);
                        // Folders navigate on a single click; files select and
                        // download on double click.
                        if (entry.isDir) _open(entry);
                      },
                      onOpen: () => _open(entry),
                    );
                  },
                ),
        ),
        if (snapshot.transfers.isNotEmpty)
          _TransferStrip(transfers: snapshot.transfers),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, color: Color(0xFF6E7388)),
    );
  }
}

class _ToolAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToolAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: (_) => Text(tooltip),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(right: 2),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 15,
            color: onTap == null
                ? const Color(0xFF5A5F73)
                : const Color(0xFFC7CBD6),
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  final SftpEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const _EntryRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final background = widget.selected
        ? const Color(0xFF2C3046)
        : _hover
        ? const Color(0xFF282B3D)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onOpen,
        child: Container(
          height: 38,
          color: background,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      entry.isDir ? LucideIcons.folder : LucideIcons.file,
                      size: 15,
                      color: entry.isDir
                          ? const Color(0xFFF8AA4B)
                          : const Color(0xFF8D91A5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFC7CBD6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  entry.isDir ? '—' : _formatSize(entry.size),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D91A5),
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  _formatDate(entry.modified),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D91A5),
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  entry.permissions,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontFamilyFallback: ['Menlo', 'Courier New'],
                    fontSize: 11.5,
                    color: Color(0xFF8D91A5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _formatDate(int seconds) {
    if (seconds <= 0) return '—';
    final value = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _TransferStrip extends StatelessWidget {
  final List<SftpTransfer> transfers;
  const _TransferStrip({required this.transfers});

  @override
  Widget build(BuildContext context) {
    final active = transfers.where((t) => t.state == 0).length;
    final failed = transfers.where((t) => t.state == 2).length;
    final latest = transfers.last;
    final fraction = latest.total == 0
        ? 0.0
        : (latest.transferred / latest.total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF262A3D))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                latest.upload ? LucideIcons.upload : LucideIcons.download,
                size: 14,
                color: latest.state == 2
                    ? const Color(0xFFE5484D)
                    : const Color(0xFF21B568),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  latest.state == 2
                      ? '${latest.name}: ${latest.message}'
                      : latest.state == 1
                      ? '${latest.name} ${latest.upload ? 'uploaded' : 'downloaded'}'
                      : '${latest.name} · ${(fraction * 100).round()}%',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFC7CBD6),
                  ),
                ),
              ),
              if (active > 0)
                Text(
                  '$active active',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8D91A5),
                  ),
                ),
              if (failed > 0)
                Text(
                  '  $failed failed',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE5484D),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: latest.state == 0 ? fraction : 1,
              minHeight: 3,
              color: latest.state == 2
                  ? const Color(0xFFE5484D)
                  : const Color(0xFF21B568),
              backgroundColor: const Color(0xFF282B3D),
            ),
          ),
        ],
      ),
    );
  }
}
