/// The host details drawer, laid out to match the reference client's host
/// drawer (form cards, relative slider, same geometry):
///
/// - drawer width 340px, animated over 200ms, surface --dark-grey-2 #1D2033
/// - header 56px, surface --dark-grey-3 #282B3D, bottom border --dark-grey-4,
///   title "Host Details" 16px/600 in --dark-grey-7, then saved-check, ⋯, →|
/// - body padding 15/15/85/15, 15px gap, cards --dark-grey-3 radius 10 with
///   padding 15 20 20 and 10px between rows
/// - field: 36px, 1px outline #8D91A540, radius 10, transparent fill,
///   14px/450 text, placeholders --dark-grey-7
/// - Address row: 36×36 OS chip (radius 8) then the field, no gap
/// - General: Label / Parent Group (folder) / Tags (tag) / Backspace (keyboard,
///   value "Default" right-aligned at --dark-grey-6)
/// - Share this host: 10px padded ghost button, accent text + people icon
/// - SSH card: "SSH on [22] port" over a 1px --dark-grey-5 divider, then
///   "Credentials" with Username (person) and Password (key) fields
/// - Connect bar: --dark-grey-2 band, 20/15 padding, full-width accent button
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/termius_choice.dart';
import 'host_card.dart';
import 'host_form_widgets.dart';


class HostDetailsPanel extends StatefulWidget {
  final Host host;
  final VoidCallback onClose;
  final VoidCallback onConnect;

  /// Every saved host, for the jump-host selector and name-uniqueness checks.
  final List<Host> hosts;

  /// Persists the edited fields to the core; returns an error text or null.
  /// The credential arguments follow the core's keep-unless-touched contract:
  /// a blank password/key keeps the stored secret, the clear flags drop it.
  final Future<String?> Function(
    Host host,
    String password,
    bool clearPassword,
    String keyInline,
    bool clearKey,
  ) onSave;

  /// Deletes the session from the core; returns an error text or null.
  final Future<String?> Function(Host) onDelete;

  /// Offered only while creating (draft host): switching the connection type
  /// to serial reopens the drawer with the serial editor.
  final VoidCallback? onSwitchToSerial;

  /// Offered only while creating: switches the draft's protocol in place
  /// (ssh ↔ telnet) without rebuilding the editor.
  final ValueChanged<String>? onKindChanged;

  const HostDetailsPanel({
    super.key,
    required this.host,
    required this.onClose,
    required this.onConnect,
    required this.onSave,
    required this.onDelete,
    this.hosts = const [],
    this.onSwitchToSerial,
    this.onKindChanged,
  });

  @override
  State<HostDetailsPanel> createState() => _HostDetailsPanelState();
}

class _HostDetailsPanelState extends State<HostDetailsPanel> {
  /// A draft with no id yet: the type selector is offered and a successful
  /// save closes the drawer (nothing was persisted to come back to).
  bool get _creating => widget.host.id.isEmpty;

  /// The port row's caption matches the dial kind ("Telnet on 23 port").
  String get _portLabel =>
      widget.host.protocol == 'telnet' ? 'Telnet on' : 'SSH on';

  /// Group names already in use — the Parent Group picker's options.
  List<String> get _existingGroups => {
    for (final host in widget.hosts)
      if (!host.ephemeral && host.group.trim().isNotEmpty)
        host.group.trim(),
  }.toList()..sort();

  late final TextEditingController _address = TextEditingController(
    text: widget.host.address,
  );
  late final TextEditingController _label = TextEditingController(
    text: widget.host.label,
  );
  late String _groupValue = widget.host.group;
  late final TextEditingController _port = TextEditingController(
    text: '${widget.host.port}',
  );
  late final TextEditingController _username = TextEditingController(
    text: widget.host.username,
  );
  final TextEditingController _password = TextEditingController();
  final TextEditingController _keyContent = TextEditingController();

  /// 'password' | 'key' — drives which credential fields render.
  late String _auth = widget.host.hasKey ? 'key' : 'password';
  bool _clearKey = false;
  bool _importingKey = false;
  late String _jumpId = widget.host.jumpHostId;
  late String _encoding = widget.host.encoding;
  late List<SessionTriggerRule> _triggers = List.of(widget.host.triggers);
  bool _saving = false;
  String? _saveError;

  @override
  void didUpdateWidget(HostDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host.id != widget.host.id) {
      _address.text = widget.host.address;
      _label.text = widget.host.label;
      _groupValue = widget.host.group;
      _port.text = '${widget.host.port}';
      _username.text = widget.host.username;
      _jumpId = widget.host.jumpHostId;
      _encoding = widget.host.encoding;
      _triggers = List.of(widget.host.triggers);
      _saveError = null;
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _label.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _keyContent.dispose();
    super.dispose();
  }

  Host _edited() => Host(
    id: widget.host.id,
    label: _label.text.trim().isEmpty ? _address.text.trim() : _label.text,
    address: _address.text,
    port: int.tryParse(_port.text.trim()) ?? widget.host.port,
    username: _username.text,
    group: _groupValue,
    protocol: widget.host.protocol,
    os: widget.host.os,
    tags: widget.host.tags,
    lastUsed: widget.host.lastUsed,
    keyPath: _clearKey ? '' : widget.host.keyPath,
    hasKeyInline: _clearKey ? false : widget.host.hasKeyInline,
    auth: _auth,
    encoding: _encoding,
    baudRate: widget.host.baudRate,
    dataBits: widget.host.dataBits,
    stopBits: widget.host.stopBits,
    parity: widget.host.parity,
    flowControl: widget.host.flowControl,
    hasPassword: widget.host.hasPassword,
    jumpHostId: _jumpId,
    triggers: List.unmodifiable(_triggers),
  );

  /// The credential payload for [widget.onSave], applying the
  /// keep-unless-touched contract:
  /// - password auth: switching away from a stored key clears it;
  /// - key auth: pasted/imported material replaces, blank keeps, Clear drops.
  (String, bool, String, bool) _credentials() {
    if (_auth == 'password') {
      return (_password.text, false, '', widget.host.hasKey);
    }
    final clear = _clearKey;
    return ('', false, _keyContent.text, clear);
  }

  Future<void> _delete() async {
    final error = await widget.onDelete(widget.host);
    if (!mounted) return;
    if (error != null) setState(() => _saveError = error);
  }

  Future<void> _save() async {
    // Captured before the await: a successful create swaps widget.host for
    // the saved row, which would flip _creating to false mid-save.
    final creating = _creating;
    final edited = _edited();
    final validation = validateHostDraft(
      label: edited.label,
      address: edited.address,
      username: edited.username,
      kind: edited.protocol,
      hosts: widget.hosts,
      editingId: widget.host.id,
    );
    if (validation != null) {
      setState(() => _saveError = validation);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final (password, clearPassword, keyInline, clearKey) = _credentials();
    final error = await widget.onSave(
      edited,
      password,
      clearPassword,
      keyInline,
      clearKey,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = error;
    });
    // Creating from a draft: a successful save has nothing left to edit.
    if (error == null && creating) widget.onClose();
  }

  /// Import key material from a file into the paste area (stored as inline
  /// content by the core — no path dependency on the user's machine). No
  /// extension filter: key files like `id_ed25519` have none.
  Future<void> _importKey() async {
    setState(() => _importingKey = true);
    try {
      final file = await openFile();
      if (file == null) return;
      final content = await File(file.path).readAsString();
      if (!mounted) return;
      setState(() {
        _keyContent.text = content;
        _clearKey = false;
      });
    } catch (error) {
      if (mounted) setState(() => _saveError = 'Could not read key: $error');
    } finally {
      if (mounted) setState(() => _importingKey = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.background, // --dark-grey-2
      child: Column(
        children: [
          _Header(
            onClose: widget.onClose,
            onSave: _save,
            onDelete: _delete,
            saving: _saving,
          ),
          Expanded(
            child: SingleChildScrollView(
              // formPaddings: 15px calc(15px - scrollbar) 85px 15px; gap 15.
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_saveError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.destructive.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(TermiusRadius.card),
                      ),
                      child: Text(
                        _saveError!,
                        style: theme.typography.normal.copyWith(
                          fontSize: 12,
                          color: theme.colorScheme.destructive,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                  if (_creating && widget.onKindChanged != null) ...[
                    HostFormCard(
                      children: [
                        const HostSectionTitle('Connection type'),
                        TermiusChoice<String>(
                          key: const ValueKey('host-kind'),
                          value: widget.host.protocol,
                          options: const {
                            'ssh': 'SSH',
                            'telnet': 'Telnet',
                            'serial': 'Serial',
                          },
                          onChanged: (value) {
                            if (value == 'serial') {
                              widget.onSwitchToSerial?.call();
                            } else if (value != widget.host.protocol) {
                              widget.onKindChanged!(value);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],
                  HostFormCard(
                    children: [
                      const HostSectionTitle('Address'),
                      Row(
                        children: [
                          _OsChip(host: widget.host),
                          Expanded(
                            child: HostPanelField(
                              key: const ValueKey('host-address'),
                              controller: _address,
                              placeholder: 'IP or Hostname',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  HostFormCard(
                    children: [
                      const HostSectionTitle('General'),
                      HostPanelField(
                        key: const ValueKey('label-field'),
                        controller: _label,
                        placeholder: 'Label',
                      ),
                      TermiusChoice<String>(
                        key: const ValueKey('host-group'),
                        value: _groupValue,
                        options: {
                          '': 'None',
                          for (final group in _existingGroups) group: group,
                        },
                        onChanged: (value) =>
                            setState(() => _groupValue = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  HostFormCard(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
                    children: [
                      _PortRow(controller: _port, label: _portLabel),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Telnet dials host:port only — the core's telnet
                          // session ignores credentials, so offering them
                          // would be a lie.
                          if (widget.host.protocol == 'ssh') ...[
                            const HostSectionTitle('Credentials'),
                            const SizedBox(height: 10),
                            HostPanelField(
                              key: const ValueKey('host-username'),
                              controller: _username,
                              placeholder: 'Username',
                              leading: LucideIcons.user,
                            ),
                            const SizedBox(height: 12),
                          const HostSectionTitle('Authentication'),
                          const SizedBox(height: 6),
                          TermiusChoice<String>(
                            key: const ValueKey('host-auth'),
                            value: _auth,
                            options: const {
                              'password': 'Password',
                              'key': 'Private key',
                            },
                            onChanged: (value) => setState(() {
                              _auth = value;
                              _clearKey = false;
                            }),
                          ),
                          if (_auth == 'password') ...[
                            const SizedBox(height: 10),
                            HostPanelField(
                              key: const ValueKey('host-password'),
                              controller: _password,
                              placeholder: widget.host.hasPassword
                                  ? 'Saved — leave blank to keep'
                                  : 'Password',
                              leading: LucideIcons.lock,
                              obscure: true,
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _ImportKeyButton(
                                    key: const ValueKey('host-key-import'),
                                    busy: _importingKey,
                                    onTap: _importKey,
                                  ),
                                ),
                                if (widget.host.hasKey &&
                                    _keyContent.text.trim().isEmpty &&
                                    !_clearKey) ...[
                                  const SizedBox(width: 8),
                                  _KeyClearChip(
                                    key: const ValueKey('host-key-clear'),
                                    onClear: () => setState(
                                      () => _clearKey = true,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_clearKey)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'The stored key will be removed on save.',
                                  key: const ValueKey('host-key-clear-note'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                              )
                            else if (widget.host.hasKey &&
                                _keyContent.text.trim().isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'A key is stored — import or paste below to '
                                  'replace it.',
                                  key: const ValueKey('host-key-stored'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                              ),
                            TermiusField(
                              key: const ValueKey('host-key-content'),
                              controller: _keyContent,
                              height: 110,
                              maxLines: 8,
                              minLines: 4,
                              placeholder:
                                  '…or paste the private key content here',
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                          ],
                          if (widget.host.protocol == 'ssh' &&
                              widget.hosts.any(
                                (h) =>
                                    h.protocol == 'ssh' &&
                                    h.id != widget.host.id &&
                                    !h.ephemeral,
                              )) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Jump host',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TermiusChoice<String>(
                              key: const ValueKey('host-jump'),
                              value: _jumpId,
                              options: {
                                '': 'None',
                                for (final candidate in widget.hosts)
                                  if (candidate.protocol == 'ssh' &&
                                      candidate.id != widget.host.id &&
                                      !candidate.ephemeral)
                                    candidate.id: candidate.label,
                              },
                              onChanged: (value) =>
                                  setState(() => _jumpId = value),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const HostSectionTitle('Encoding'),
                          const SizedBox(height: 6),
                          TermiusChoice<String>(
                            key: const ValueKey('host-encoding'),
                            value: _encoding,
                            options: const {
                              'utf-8': 'UTF-8 (auto)',
                              'gbk': 'GBK / 简体中文',
                              'gb18030': 'GB18030',
                              'big5': 'Big5 / 繁体中文',
                              'shift_jis': 'Shift_JIS / 日语',
                              'euc-kr': 'EUC-KR / 韩语',
                              'windows-1251': 'Windows-1251 / 西里尔',
                              'iso-8859-1': 'Latin-1',
                            },
                            onChanged: (value) =>
                                setState(() => _encoding = value),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  HostFormCard(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
                    children: [
                      const HostSectionTitle('Triggers'),
                      const SizedBox(height: 4),
                      Text(
                        'Wait for a prompt, answer automatically. Responses are '
                        'stored securely; a blank field keeps the saved value.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                      if (_triggers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'No triggers yet.',
                            key: const ValueKey('host-triggers-empty'),
                            style: TextStyle(
                              fontSize: 12,
                              color: hostTitleGrey,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < _triggers.length; i++)
                          _TriggerRow(
                            key: ValueKey('host-trigger-$i'),
                            rule: _triggers[i],
                            onChanged: (rule) => setState(() {
                              _triggers[i] = rule;
                            }),
                            onRemoved: () => setState(() {
                              _triggers.removeAt(i);
                            }),
                          ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: Button(
                          key: const ValueKey('host-trigger-add'),
                          style: const ButtonStyle.ghost(),
                          onPressed: () => setState(() {
                            _triggers.add(const SessionTriggerRule(expect: ''));
                          }),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.plus, size: 14),
                              SizedBox(width: 6),
                              Text('Add trigger'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // connectButton: --dark-grey-2 band, padding 20px 15px, full width.
          Container(
            color: theme.colorScheme.background,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: Button(
                onPressed: widget.onConnect,
                style: const ButtonStyle.primary(),
                child: const Text('Connect'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 56px header: title in --dark-grey-7 16px/600, save check, ⋯, →|.
class _Header extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final bool saving;

  const _Header({
    required this.onClose,
    required this.onSave,
    required this.onDelete,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 15, right: 10),
      decoration: const BoxDecoration(
        color: hostCardSurface,
        border: Border(bottom: BorderSide(color: hostHeaderBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text(
                'Host Details',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.semiBold.copyWith(
                  fontSize: 16,
                  color: hostTitleGrey,
                ),
              ),
            ),
          ),
          // The check persists the drawer's edits into the core store.
          _HeaderIcon(
            onPressed: saving ? null : onSave,
            child: Icon(
              LucideIcons.check,
              size: 15,
              color: saving ? hostTextDisabled : Colors.white,
            ),
          ),
          const SizedBox(width: 5),
          _MoreButton(onDelete: onDelete),
          _HeaderIcon(
            onPressed: onClose,
            child: const Icon(
              LucideIcons.arrowRightToLine,
              size: 16,
              color: hostTitleGrey,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ⋯ menu: currently just "Remove host" (a real store delete through the
/// bridge). Anchored under the button like the toolbar menus.
class _MoreButton extends StatefulWidget {
  final VoidCallback onDelete;

  const _MoreButton({required this.onDelete});

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton> {
  final OverlayPortalController _menu = OverlayPortalController();
  final LayerLink _link = LayerLink();

  Widget _menuChild(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _menu.hide,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 6),
          showWhenUnlinked: false,
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 180,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: hostCardSurface,
                borderRadius: BorderRadius.circular(TermiusRadius.field),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: _MoreItem(
                label: 'Remove host',
                onTap: () {
                  _menu.hide();
                  widget.onDelete();
                },
                theme: theme,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _menu,
      overlayChildBuilder: _menuChild,
      child: CompositedTransformTarget(
        link: _link,
        child: IconButton.ghost(
          onPressed: () => _menu.isShowing ? _menu.hide() : _menu.show(),
          icon: const Icon(LucideIcons.ellipsis, size: 15, color: hostTitleGrey),
          size: ButtonSize.small,
        ),
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;

  const _MoreItem({
    required this.label,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              LucideIcons.trash2,
              size: 15,
              color: theme.colorScheme.destructive,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.typography.normal.copyWith(
                fontSize: 13,
                color: theme.colorScheme.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _HeaderIcon({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return IconButton.ghost(
      onPressed: onPressed,
      icon: child,
      size: ButtonSize.small,
    );
  }
}

/// 36×36 OS chip, radius 8 — the entity icon block of the Address row.
class _OsChip extends StatelessWidget {
  final Host host;

  const _OsChip({required this.host});

  @override
  Widget build(BuildContext context) {
    final chip = osChipFor(host.os);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: chip.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(chip.glyph, size: 20, color: Colors.white),
    );
  }
}

/// The key-auth import control: looks like a field, acts like a button.
class _ImportKeyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _ImportKeyButton({super.key, this.busy = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(TermiusRadius.field),
        ),
        child: Row(
          children: [
            Icon(
              busy ? LucideIcons.loaderCircle : LucideIcons.fileUp,
              size: 14,
              color: hostTextDisabled,
            ),
            const SizedBox(width: 8),
            Text(
              busy ? 'Importing…' : 'Import key file…',
              style: theme.typography.normal.copyWith(
                fontSize: 13.5,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small destructive chip dropping a stored key on the next save.
class _KeyClearChip extends StatelessWidget {
  final VoidCallback onClear;

  const _KeyClearChip({super.key, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClear,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.destructive.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(TermiusRadius.field),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.trash2, size: 13, color: theme.colorScheme.destructive),
            const SizedBox(width: 6),
            Text(
              'Clear',
              style: theme.typography.normal.copyWith(
                fontSize: 12,
                color: theme.colorScheme.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "SSH on [22] port" with a 1px --dark-grey-5 divider underneath.
class _PortRow extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _PortRow({required this.controller, this.label = 'SSH on'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: hostDivider)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.typography.normal.copyWith(
              fontSize: 16,
              color: theme.colorScheme.foreground,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 79,
            child: HostPanelField(
              controller: controller,
              placeholder: '22',
              height: 28,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'port',
            style: theme.typography.normal.copyWith(
              fontSize: 16,
              color: theme.colorScheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// One expect/send rule inside the host drawer. The response field stays
/// blank-looking while a secret is stored ("Saved…"): only a typed value
/// replaces it, matching the password field's semantics.
class _TriggerRow extends StatefulWidget {
  final SessionTriggerRule rule;
  final ValueChanged<SessionTriggerRule> onChanged;
  final VoidCallback onRemoved;

  const _TriggerRow({
    super.key,
    required this.rule,
    required this.onChanged,
    required this.onRemoved,
  });

  @override
  State<_TriggerRow> createState() => _TriggerRowState();
}

class _TriggerRowState extends State<_TriggerRow> {
  late final TextEditingController _expect = TextEditingController(
    text: widget.rule.expect,
  );
  late final TextEditingController _response = TextEditingController(
    text: widget.rule.draftResponse,
  );

  @override
  void initState() {
    super.initState();
    // Typing must reach the parent's save payload immediately; the row keeps
    // no separate draft state.
    _expect.addListener(() => _push(expect: _expect.text));
    _response.addListener(() => _push(response: _response.text));
  }

  @override
  void dispose() {
    _expect.dispose();
    _response.dispose();
    super.dispose();
  }

  void _push({String? expect, String? response, bool? appendEnter, bool? repeat, bool? clear}) {
    widget.onChanged(
      widget.rule.copyWith(
        expect: expect,
        draftResponse: response,
        appendEnter: appendEnter,
        repeat: repeat,
        clearResponse: clear,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kept =
        widget.rule.hasResponse &&
        widget.rule.draftResponse.isEmpty &&
        !widget.rule.clearResponse;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hostCardSurface,
        borderRadius: BorderRadius.circular(TermiusRadius.card),
        border: Border.all(color: hostDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HostPanelField(
            key: const ValueKey('trigger-expect'),
            controller: _expect,
            placeholder: 'Wait for (e.g. login:)',
            leading: LucideIcons.eye,
            height: 30,
          ),
          const SizedBox(height: 8),
          HostPanelField(
            key: const ValueKey('trigger-response'),
            controller: _response,
            placeholder: kept ? 'Saved — leave blank to keep' : 'Response',
            leading: LucideIcons.messageSquare,
            height: 30,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: widget.rule.appendEnter,
                      onChanged: (value) => _push(appendEnter: value),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Enter',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: widget.rule.repeat,
                      onChanged: (value) => _push(repeat: value),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Repeat',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Button(
                key: const ValueKey('trigger-remove'),
                style: const ButtonStyle.ghost(),
                onPressed: widget.onRemoved,
                child: const Icon(LucideIcons.trash2, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
