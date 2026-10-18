/// Keychain — the SSH key credentials actually referenced by saved hosts.
///
/// The core owns key material, so this screen only shows metadata (file name,
/// algorithm, SHA256 fingerprint, the host that uses it) and can copy a key's
/// file name; it never receives the private key itself.
library;

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';

typedef KeyLoader = Future<List<KeyInfo>> Function();

class KeychainScreen extends StatefulWidget {
  final KeyLoader? loadKeys;

  const KeychainScreen({super.key, this.loadKeys});

  @override
  State<KeychainScreen> createState() => _KeychainScreenState();
}

class _KeychainScreenState extends State<KeychainScreen> {
  List<KeyInfo> _keys = const [];
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
      final keys = await (widget.loadKeys ?? loadKeysFromCore)();
      if (!mounted) return;
      setState(() {
        _keys = keys;
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

  List<KeyInfo> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _keys;
    return _keys
        .where(
          (k) =>
              k.title.toLowerCase().contains(query) ||
              k.sessionName.toLowerCase().contains(query) ||
              k.fingerprint.toLowerCase().contains(query),
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
              key: const ValueKey('keychain-search'),
              controller: _search,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              placeholder: 'Search keys',
            ),
          ),
        const SectionTitle(text: 'Keychain'),
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
            'Loading keys…',
            style: TextStyle(color: Color(0xFF8D91A5)),
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
              style: const TextStyle(color: Color(0xFF8D91A5)),
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
    final keys = _filtered;
    if (keys.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              LucideIcons.keyRound,
              size: 30,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(
              _keys.isEmpty ? 'No SSH keys yet' : 'No matches',
              style: theme.typography.semiBold.copyWith(
                fontSize: 15,
                color: theme.colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _keys.isEmpty
                  ? 'Set a private key path on a host to see it here.'
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
        for (final key in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KeyCard(keyInfo: key),
          ),
      ],
    );
  }
}

class KeyCard extends StatefulWidget {
  final KeyInfo keyInfo;

  const KeyCard({super.key, required this.keyInfo});

  @override
  State<KeyCard> createState() => _KeyCardState();
}

class _KeyCardState extends State<KeyCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = widget.keyInfo;
    final statusLine = switch (key.status) {
      'missing' => 'Key file missing',
      'locked' => 'Encrypted key · unlocked on connect',
      _ => key.fingerprint.isEmpty ? 'Key' : key.fingerprint,
    };
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        key: ValueKey('key-${key.sessionId}'),
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFF32364A) : const Color(0xFF282B3D),
          borderRadius: BorderRadius.circular(TermiusRadius.cardLarge),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2091F6).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(TermiusRadius.menu),
              ),
              child: const Icon(
                LucideIcons.keyRound,
                size: 20,
                color: Color(0xFF2091F6),
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
                          key.title,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.semiBold.copyWith(
                            fontSize: 15,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                      ),
                      if (key.keyType.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF202436),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _algorithmLabel(key.keyType),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8D91A5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$statusLine  ·  ${key.sessionName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: key.status == 'available'
                          ? const Color(0xFF8D91A5)
                          : const Color(0xFFF8AA4B),
                    ),
                  ),
                ],
              ),
            ),
            if (_hover && key.source == 'file')
              Tooltip(
                tooltip: (_) => const Text('Copy key file name'),
                child: GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: key.path)),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF202436),
                      borderRadius: BorderRadius.circular(TermiusRadius.menu),
                    ),
                    child: const Icon(
                      LucideIcons.copy,
                      size: 14,
                      color: Color(0xFFC7CBD6),
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
    if (lower.contains('ppk')) return 'PPK';
    return type.toUpperCase();
  }
}
