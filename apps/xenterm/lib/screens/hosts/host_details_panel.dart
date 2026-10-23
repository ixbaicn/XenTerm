/// The host details drawer, rebuilt from Termius's own component source
/// (`HostFormContent` / `FormCard` / `InputField` / `RelativeSlider` in
/// reconnectSaga‑9aed66e2.js and hosts canvas):
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

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/hosts.dart';
import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/termius_choice.dart';
import 'host_card.dart';

const _cardSurface = Color(0xFF282B3D); // --dark-grey-3 / --card-a
const _divider = Color(0xFF3E4257); // --dark-grey-5
const _textDisabled = Color(0xFF5A5E73); // --dark-grey-6
const _titleGrey = Color(0xFF8D91A5); // --dark-grey-7
const _headerBorder = Color(0xFF32364A); // --dark-grey-4

class HostDetailsPanel extends StatefulWidget {
  final Host host;
  final VoidCallback onClose;
  final VoidCallback onConnect;

  /// Every saved host, for the jump-host selector.
  final List<Host> hosts;

  /// Persists the edited fields to the core; returns an error text or null.
  final Future<String?> Function(Host) onSave;

  /// Deletes the session from the core; returns an error text or null.
  final Future<String?> Function(Host) onDelete;

  const HostDetailsPanel({
    super.key,
    required this.host,
    required this.onClose,
    required this.onConnect,
    required this.onSave,
    required this.onDelete,
    this.hosts = const [],
  });

  @override
  State<HostDetailsPanel> createState() => _HostDetailsPanelState();
}

class _HostDetailsPanelState extends State<HostDetailsPanel> {
  late final TextEditingController _address = TextEditingController(
    text: widget.host.address,
  );
  late final TextEditingController _label = TextEditingController(
    text: widget.host.label,
  );
  late final TextEditingController _group = TextEditingController(
    text: widget.host.group,
  );
  late final TextEditingController _port = TextEditingController(
    text: '${widget.host.port}',
  );
  late final TextEditingController _username = TextEditingController(
    text: widget.host.username,
  );
  late final TextEditingController _keyPath = TextEditingController(
    text: widget.host.keyPath,
  );
  late String _jumpId = widget.host.jumpHostId;
  late List<SessionTriggerRule> _triggers = List.of(widget.host.triggers);
  bool _saving = false;
  String? _saveError;

  @override
  void didUpdateWidget(HostDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host.id != widget.host.id) {
      _address.text = widget.host.address;
      _label.text = widget.host.label;
      _group.text = widget.host.group;
      _port.text = '${widget.host.port}';
      _username.text = widget.host.username;
      _keyPath.text = widget.host.keyPath;
      _jumpId = widget.host.jumpHostId;
      _triggers = List.of(widget.host.triggers);
      _saveError = null;
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _label.dispose();
    _group.dispose();
    _port.dispose();
    _username.dispose();
    _keyPath.dispose();
    super.dispose();
  }

  Host _edited() => Host(
    id: widget.host.id,
    label: _label.text,
    address: _address.text,
    port: int.tryParse(_port.text.trim()) ?? widget.host.port,
    username: _username.text,
    group: _group.text,
    protocol: widget.host.protocol,
    os: widget.host.os,
    tags: widget.host.tags,
    lastUsed: widget.host.lastUsed,
    keyPath: _keyPath.text.trim(),
    auth: _keyPath.text.trim().isEmpty ? 'password' : 'key',
    baudRate: widget.host.baudRate,
    dataBits: widget.host.dataBits,
    stopBits: widget.host.stopBits,
    parity: widget.host.parity,
    flowControl: widget.host.flowControl,
    hasPassword: widget.host.hasPassword,
    jumpHostId: _jumpId,
    triggers: List.unmodifiable(_triggers),
  );

  Future<void> _delete() async {
    final error = await widget.onDelete(widget.host);
    if (!mounted) return;
    if (error != null) setState(() => _saveError = error);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final error = await widget.onSave(_edited());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = error;
    });
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
                  _FormCard(
                    children: [
                      const _SectionTitle('Address'),
                      Row(
                        children: [
                          _OsChip(host: widget.host),
                          Expanded(
                            child: _PanelField(
                              controller: _address,
                              placeholder: 'IP or Hostname',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _FormCard(
                    children: [
                      const _SectionTitle('General'),
                      _PanelField(controller: _label, placeholder: 'Label'),
                      _PanelField(
                        controller: _group,
                        placeholder: 'Parent Group',
                        leading: LucideIcons.folder,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _FormCard(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
                    children: [
                      _PortRow(controller: _port),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionTitle('Credentials'),
                          const SizedBox(height: 10),
                          _PanelField(
                            controller: _username,
                            placeholder: 'Username',
                            leading: LucideIcons.user,
                          ),
                          const SizedBox(height: 10),
                          _PanelField(
                            key: const ValueKey('host-key-path'),
                            controller: _keyPath,
                            placeholder: 'Private key path (optional)',
                            leading: LucideIcons.keyRound,
                          ),
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
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _FormCard(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
                    children: [
                      const _SectionTitle('Triggers'),
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
                              color: _titleGrey,
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
        color: _cardSurface,
        border: Border(bottom: BorderSide(color: _headerBorder)),
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
                  color: _titleGrey,
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
              color: saving ? _textDisabled : Colors.white,
            ),
          ),
          const SizedBox(width: 5),
          _MoreButton(onDelete: onDelete),
          _HeaderIcon(
            onPressed: onClose,
            child: const Icon(
              LucideIcons.arrowRightToLine,
              size: 16,
              color: _titleGrey,
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
                color: _cardSurface,
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
          icon: const Icon(LucideIcons.ellipsis, size: 15, color: _titleGrey),
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

/// `FormCard`: --dark-grey-3, radius 10, padding 15 20 20, children 10 apart.
class _FormCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const _FormCard({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 15, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 10));
      spaced.add(children[i]);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced,
      ),
    );
  }
}

/// The section title: body1 16px, weight 500, primary text.
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.typography.medium.copyWith(
        fontSize: 16,
        color: theme.colorScheme.foreground,
      ),
    );
  }
}

/// MUI outlined InputField: 36px, 1px #8D91A540, radius 10, 14px/450 text,
/// placeholder --dark-grey-7; optional 14px leading icon in --dark-grey-6.
class _PanelField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final IconData? leading;
  final double height;

  const _PanelField({
    super.key,
    required this.placeholder,
    required this.controller,
    this.leading,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    return TermiusField(
      placeholder: placeholder,
      controller: controller,
      height: height,
      leading: leading == null
          ? null
          : Icon(leading, size: 14, color: _textDisabled),
    );
  }
}

/// "SSH on [22] port" with a 1px --dark-grey-5 divider underneath.
class _PortRow extends StatelessWidget {
  final TextEditingController controller;

  const _PortRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          Text(
            'SSH on',
            style: theme.typography.normal.copyWith(
              fontSize: 16,
              color: theme.colorScheme.foreground,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 79,
            child: _PanelField(
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
        color: _cardSurface,
        borderRadius: BorderRadius.circular(TermiusRadius.card),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelField(
            key: const ValueKey('trigger-expect'),
            controller: _expect,
            placeholder: 'Wait for (e.g. login:)',
            leading: LucideIcons.eye,
            height: 30,
          ),
          const SizedBox(height: 8),
          _PanelField(
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
