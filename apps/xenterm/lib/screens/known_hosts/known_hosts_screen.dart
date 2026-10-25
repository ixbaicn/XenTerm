/// Known Hosts — the core's TOFU `known_hosts` store. Lists the real remembered
/// keys (host:port, algorithm, SHA256 fingerprint) and removes entries; no
/// fixture rows.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/lucide_extra_icons.dart';
import '../../widgets/toolbar.dart';

typedef KnownHostLoader = Future<List<KnownHost>> Function();
typedef KnownHostDeleter = Future<CoreWriteResult> Function(String id);

class KnownHostsScreen extends StatefulWidget {
  final KnownHostLoader? loadHosts;
  final KnownHostDeleter? deleteHost;

  const KnownHostsScreen({super.key, this.loadHosts, this.deleteHost});

  @override
  State<KnownHostsScreen> createState() => _KnownHostsScreenState();
}

class _KnownHostsScreenState extends State<KnownHostsScreen> {
  List<KnownHost> _hosts = const [];
  bool _loading = true;
  String? _error;
  bool _searching = false;
  String _query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final hosts = await (widget.loadHosts ?? loadKnownHostsFromCore)();
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is NativeBridgeError ? error.message : '$error';
      });
    }
  }

  Future<void> _remove(KnownHost host) async {
    try {
      final result = await (widget.deleteHost ?? deleteKnownHostFromCore)(
        host.id,
      );
      if (!result.ok) {
        if (!mounted) return;
        setState(() => _error = result.error ?? 'Could not remove the key');
        return;
      }
      await _reload(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  List<KnownHost> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _hosts;
    return _hosts
        .where(
          (h) =>
              h.id.toLowerCase().contains(query) ||
              h.keyType.toLowerCase().contains(query) ||
              h.fingerprint.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Spacer(),
              Row(
                children: [
                  IconToggleButton(
                    icon: LucideIcons.search,
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _search.clear();
                        _query = '';
                      }
                    }),
                  ),
                  const SizedBox(width: 6),
                  IconToggleButton(
                    icon: LucideIcons.refreshCw,
                    onPressed: () => _reload(),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TermiusField(
              key: const ValueKey('known-host-search'),
              controller: _search,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              placeholder: 'Search known hosts',
            ),
          ),
        const SectionTitle(text: 'Known Hosts'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _body(theme),
          ),
        ),
      ],
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Loading known hosts…',
            style: TextStyle(color: Color(0xFFA6A6A6)),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFA6A6A6)),
            ),
            const SizedBox(height: 12),
            Button(
              style: const ButtonStyle.outline(),
              onPressed: () => _reload(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final hosts = _filtered;
    if (hosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            FingerprintPatternIcon(
              size: 30,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(
              _hosts.isEmpty ? 'No known hosts yet' : 'No matches',
              style: theme.typography.semiBold.copyWith(
                fontSize: 15,
                color: theme.colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _hosts.isEmpty
                  ? 'Host keys are remembered after you accept them on connect.'
                  : 'Try a different search.',
              textAlign: TextAlign.center,
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final host in hosts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KnownHostCard(host: host, onRemove: () => _remove(host)),
          ),
      ],
    );
  }
}

class KnownHostCard extends StatefulWidget {
  final KnownHost host;
  final VoidCallback onRemove;

  const KnownHostCard({super.key, required this.host, required this.onRemove});

  @override
  State<KnownHostCard> createState() => _KnownHostCardState();
}

class _KnownHostCardState extends State<KnownHostCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fingerprint = widget.host.fingerprint.isEmpty
        ? 'unreadable key entry'
        : widget.host.fingerprint;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        key: ValueKey('known-host-${widget.host.id}'),
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFF2E2E2E) : const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(TermiusRadius.cardLarge),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(TermiusRadius.menu),
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                size: 20,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.host.id,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.semiBold.copyWith(
                            fontSize: 15,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _algorithmLabel(widget.host.keyType),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFA6A6A6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fingerprint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontFamilyFallback: ['Menlo', 'Courier New'],
                      fontSize: 12,
                      color: Color(0xFFA6A6A6),
                    ),
                  ),
                ],
              ),
            ),
            if (_hover)
              Tooltip(
                tooltip: (_) => const Text('Forget this key'),
                child: GestureDetector(
                  key: ValueKey('known-host-remove-${widget.host.id}'),
                  onTap: widget.onRemove,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(TermiusRadius.menu),
                    ),
                    child: const Icon(
                      LucideIcons.trash2,
                      size: 14,
                      color: Color(0xFFE5484D),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _algorithmLabel(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('ed25519')) return 'ED25519';
    if (lower.contains('rsa')) return 'RSA';
    if (lower.contains('ecdsa')) return 'ECDSA';
    return type.isEmpty ? 'KEY' : type.toUpperCase();
  }
}
