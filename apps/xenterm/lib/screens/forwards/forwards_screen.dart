/// Port Forwarding — the saved forwarding rules from every SSH session, with
/// real create/edit/delete through the core store. Rules are applied when the
/// owning session connects (the core's tunnel worker), so the list has no fake
/// global pause switch.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../data/hosts.dart';
import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';

typedef ForwardLoader = Future<List<ForwardRule>> Function();
typedef ForwardSaver = Future<CoreWriteResult> Function({
  required String sessionId,
  required int index,
  required String kind,
  required String name,
  required String bindAddr,
  required String bindPort,
  required String host,
  required String hostPort,
});
typedef ForwardDeleter = Future<CoreWriteResult> Function({
  required String sessionId,
  required int index,
});
typedef ForwardHostLoader = Future<List<Host>> Function();

class ForwardsScreen extends StatefulWidget {
  final ForwardLoader? loadForwards;
  final ForwardSaver? saveForward;
  final ForwardDeleter? deleteForward;
  final ForwardHostLoader? loadHosts;

  const ForwardsScreen({
    super.key,
    this.loadForwards,
    this.saveForward,
    this.deleteForward,
    this.loadHosts,
  });

  @override
  State<ForwardsScreen> createState() => _ForwardsScreenState();
}

class _ForwardsScreenState extends State<ForwardsScreen> {
  List<ForwardRule> _rules = const [];
  List<Host> _sshHosts = const [];
  bool _loading = true;
  String? _error;
  bool _searching = false;
  String _query = '';
  bool _drawerOpen = false;
  ForwardRule? _editing;
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
      final rules = await (widget.loadForwards ?? loadForwardsFromCore)();
      final hosts = await (widget.loadHosts ?? loadHostsFromCore)();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _sshHosts = hosts.where((h) => h.protocol == 'ssh').toList();
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

  Future<String?> _save({
    required String sessionId,
    required int index,
    required String kind,
    required String name,
    required String bindAddr,
    required String bindPort,
    required String host,
    required String hostPort,
  }) async {
    try {
      final result = await (widget.saveForward ?? saveForwardToCore)(
        sessionId: sessionId,
        index: index,
        kind: kind,
        name: name,
        bindAddr: bindAddr,
        bindPort: bindPort,
        host: host,
        hostPort: hostPort,
      );
      if (!result.ok) return result.error ?? 'Save failed';
      await _reload(silent: true);
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<String?> _delete(ForwardRule rule) async {
    try {
      final result = await (widget.deleteForward ?? deleteForwardFromCore)(
        sessionId: rule.sessionId,
        index: rule.index,
      );
      if (!result.ok) return result.error ?? 'Delete failed';
      _closeDrawer();
      await _reload(silent: true);
      return null;
    } catch (error) {
      return '$error';
    }
  }

  void _openNew() {
    if (_sshHosts.isEmpty) {
      setState(() => _error = 'Add an SSH host before creating a rule.');
      return;
    }
    setState(() {
      _editing = null;
      _drawerOpen = true;
    });
  }

  void _openEdit(ForwardRule rule) {
    setState(() {
      _editing = rule;
      _drawerOpen = true;
    });
  }

  void _closeDrawer() {
    setState(() {
      _drawerOpen = false;
      _editing = null;
    });
  }

  List<ForwardRule> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _rules;
    return _rules
        .where(
          (r) =>
              r.name.toLowerCase().contains(query) ||
              r.sessionName.toLowerCase().contains(query) ||
              r.bind.toLowerCase().contains(query) ||
              r.target.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    SplitButton(
                      label: 'New rule',
                      icon: LucideIcons.plus,
                      onPressed: _openNew,
                    ),
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
                  child: TextField(
                    key: const ValueKey('forward-search'),
                    controller: _search,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282B3D),
                      borderRadius: BorderRadius.circular(TermiusRadius.field),
                    ),
                    placeholder: const Text(
                      'Search rules',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8D91A5)),
                    ),
                  ),
                ),
              const SectionTitle(text: 'Port Forwarding'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _body(theme),
                ),
              ),
            ],
          ),
        ),
        ClipRect(
          child: AnimatedContainer(
            duration: TermiusMotion.micro,
            curve: TermiusMotion.easeOut,
            width: _drawerOpen ? 340 : 0,
            child: _drawerOpen
                ? OverflowBox(
                    alignment: Alignment.centerRight,
                    minWidth: 340,
                    maxWidth: 340,
                    child: ForwardEditor(
                      key: ValueKey(
                        '${_editing?.sessionId}-${_editing?.index}',
                      ),
                      rule: _editing,
                      hosts: _sshHosts,
                      onSave: _save,
                      onDelete: _editing == null ? null : _delete,
                      onClose: _closeDrawer,
                    ),
                  )
                : const SizedBox.shrink(),
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
            'Loading port forwards…',
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
    final rules = _filtered;
    if (rules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              LucideIcons.arrowLeftRight,
              size: 30,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(
              _rules.isEmpty ? 'No forwarding rules' : 'No matches',
              style: theme.typography.semiBold.copyWith(
                fontSize: 15,
                color: theme.colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _rules.isEmpty
                  ? 'Rules open their tunnels when the owning host connects.'
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
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RuleCard(
              rule: rule,
              onEdit: () => _openEdit(rule),
              onDelete: () => _delete(rule),
            ),
          ),
      ],
    );
  }

  static Color kindColor(String kind) => switch (kind) {
    'local' => const Color(0xFF21B568),
    'remote' => const Color(0xFF2091F6),
    _ => const Color(0xFFF8AA4B),
  };

  static String kindLabel(String kind) => switch (kind) {
    'local' => 'Local',
    'remote' => 'Remote',
    _ => 'Dynamic',
  };
}

class _RuleCard extends StatefulWidget {
  final ForwardRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleCard({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rule = widget.rule;
    final color = _ForwardsScreenState.kindColor(rule.kind);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        key: ValueKey('forward-${rule.sessionId}-${rule.index}'),
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
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(TermiusRadius.menu),
              ),
              child: Icon(LucideIcons.arrowLeftRight, size: 20, color: color),
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
                          rule.name.isEmpty ? rule.bind : rule.name,
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
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _ForwardsScreenState.kindLabel(rule.kind),
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rule.target.isEmpty
                        ? '${rule.bind}  ·  ${rule.sessionName}'
                        : '${rule.bind}  →  ${rule.target}  ·  ${rule.sessionName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8D91A5),
                    ),
                  ),
                ],
              ),
            ),
            if (_hover)
              Row(
                children: [
                  _CardAction(icon: LucideIcons.pencil, onTap: widget.onEdit),
                  _CardAction(
                    icon: LucideIcons.trash2,
                    destructive: true,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  const _CardAction({
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(left: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF202436),
          borderRadius: BorderRadius.circular(TermiusRadius.menu),
        ),
        child: Icon(
          icon,
          size: 14,
          color: destructive
              ? const Color(0xFFE5484D)
              : const Color(0xFFC7CBD6),
        ),
      ),
    );
  }
}

class ForwardEditor extends StatefulWidget {
  final ForwardRule? rule;
  final List<Host> hosts;
  final Future<String?> Function({
    required String sessionId,
    required int index,
    required String kind,
    required String name,
    required String bindAddr,
    required String bindPort,
    required String host,
    required String hostPort,
  })
  onSave;
  final Future<String?> Function(ForwardRule rule)? onDelete;
  final VoidCallback onClose;

  const ForwardEditor({
    super.key,
    required this.rule,
    required this.hosts,
    required this.onSave,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<ForwardEditor> createState() => _ForwardEditorState();
}

class _ForwardEditorState extends State<ForwardEditor> {
  late String _sessionId =
      widget.rule?.sessionId ??
      (widget.hosts.isEmpty ? '' : widget.hosts.first.id);
  late String _kind = widget.rule?.kind ?? 'local';
  late final TextEditingController _name = TextEditingController(
    text: widget.rule?.name ?? '',
  );
  late final TextEditingController _bindAddr = TextEditingController(
    text: widget.rule?.bindAddr ?? '127.0.0.1',
  );
  late final TextEditingController _bindPort = TextEditingController(
    text: widget.rule == null ? '' : '${widget.rule!.bindPort}',
  );
  late final TextEditingController _host = TextEditingController(
    text: widget.rule?.host ?? '',
  );
  late final TextEditingController _hostPort = TextEditingController(
    text: widget.rule == null || widget.rule!.hostPort == 0
        ? ''
        : '${widget.rule!.hostPort}',
  );
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bindAddr.dispose();
    _bindPort.dispose();
    _host.dispose();
    _hostPort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_bindPort.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = 'Enter a valid listen port (1-65535).');
      return;
    }
    if (_kind != 'dynamic') {
      final targetPort = int.tryParse(_hostPort.text.trim());
      if (_host.text.trim().isEmpty ||
          targetPort == null ||
          targetPort < 1 ||
          targetPort > 65535) {
        setState(() => _error = 'Enter a target host and a valid target port.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(
      sessionId: _sessionId,
      index: widget.rule?.index ?? -1,
      kind: _kind,
      name: _name.text.trim(),
      bindAddr: _bindAddr.text.trim(),
      bindPort: '$port',
      host: _kind == 'dynamic' ? '' : _host.text.trim(),
      hostPort: _kind == 'dynamic' ? '' : _hostPort.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      setState(() => _error = error);
    } else {
      widget.onClose();
    }
  }

  Future<void> _delete() async {
    final delete = widget.onDelete;
    if (delete == null) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final error = await delete(widget.rule!);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error != null) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF282B3D),
        borderRadius: BorderRadius.circular(TermiusRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF32364A))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.rule == null ? 'New rule' : 'Forwarding rule',
                    style: theme.typography.semiBold.copyWith(
                      fontSize: 16,
                      color: const Color(0xFF8D91A5),
                    ),
                  ),
                ),
                if (widget.rule != null)
                  _HeaderButton(
                    key: const ValueKey('forward-delete'),
                    icon: LucideIcons.trash2,
                    destructive: true,
                    busy: _deleting,
                    onTap: _delete,
                  ),
                const SizedBox(width: 6),
                _HeaderButton(
                  key: const ValueKey('forward-save'),
                  icon: LucideIcons.check,
                  busy: _saving,
                  onTap: _save,
                ),
                const SizedBox(width: 6),
                _HeaderButton(icon: LucideIcons.x, onTap: widget.onClose),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x33E5484D),
                      borderRadius: BorderRadius.circular(TermiusRadius.field),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF8A8D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _Choice(
                  key: const ValueKey('forward-host'),
                  label: 'Host',
                  value: _hostLabel(),
                  options: [for (final host in widget.hosts) host.id],
                  optionLabels: {
                    for (final host in widget.hosts)
                      host.id: '${host.label} · ${host.address}',
                  },
                  onSelected: (value) => setState(() => _sessionId = value),
                ),
                const SizedBox(height: 10),
                _Choice(
                  key: const ValueKey('forward-kind'),
                  label: 'Type',
                  value: _kind,
                  options: const ['local', 'remote', 'dynamic'],
                  optionLabels: const {
                    'local': 'Local',
                    'remote': 'Remote',
                    'dynamic': 'Dynamic (SOCKS5)',
                  },
                  onSelected: (value) => setState(() => _kind = value),
                ),
                const SizedBox(height: 10),
                _Field(
                  key: const ValueKey('forward-name'),
                  controller: _name,
                  placeholder: 'Name (optional)',
                ),
                const SizedBox(height: 10),
                _Field(
                  key: const ValueKey('forward-bind-addr'),
                  controller: _bindAddr,
                  placeholder: 'Listen address',
                ),
                const SizedBox(height: 10),
                _Field(
                  key: const ValueKey('forward-bind-port'),
                  controller: _bindPort,
                  placeholder: 'Listen port',
                  number: true,
                ),
                if (_kind != 'dynamic') ...[
                  const SizedBox(height: 10),
                  _Field(
                    key: const ValueKey('forward-target-host'),
                    controller: _host,
                    placeholder: 'Target host',
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    key: const ValueKey('forward-target-port'),
                    controller: _hostPort,
                    placeholder: 'Target port',
                    number: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hostLabel() {
    for (final host in widget.hosts) {
      if (host.id == _sessionId) return '${host.label} · ${host.address}';
    }
    return widget.hosts.isEmpty ? 'No SSH hosts' : widget.hosts.first.label;
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool number;

  const _Field({
    super.key,
    required this.controller,
    required this.placeholder,
    this.number = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF202436),
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      placeholder: Text(
        placeholder,
        style: const TextStyle(fontSize: 13, color: Color(0xFF6E7388)),
      ),
    );
  }
}

class _Choice extends StatefulWidget {
  final String label;
  final String value;
  final List<String> options;
  final Map<String, String> optionLabels;
  final ValueChanged<String> onSelected;

  const _Choice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabels,
    required this.onSelected,
  });

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> {
  final OverlayPortalController _menu = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6E7388)),
        ),
        const SizedBox(height: 6),
        CompositedTransformTarget(
          link: _link,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _menu.isShowing ? _menu.hide() : _menu.show(),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF202436),
                borderRadius: BorderRadius.circular(TermiusRadius.field),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.optionLabels[widget.value] ?? widget.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC7CBD6),
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 12,
                    color: Color(0xFF8D91A5),
                  ),
                ],
              ),
            ),
          ),
        ),
        OverlayPortal(controller: _menu, overlayChildBuilder: _overlay),
      ],
    );
  }

  Widget _overlay(BuildContext context) {
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
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          showWhenUnlinked: false,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF282B3D),
              borderRadius: BorderRadius.circular(TermiusRadius.field),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in widget.options)
                  GestureDetector(
                    onTap: () {
                      widget.onSelected(option);
                      _menu.hide();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        widget.optionLabels[option] ?? option,
                        style: TextStyle(
                          fontSize: 13,
                          color: option == widget.value
                              ? const Color(0xFF21B568)
                              : const Color(0xFFC7CBD6),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  final bool busy;

  const _HeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF32364A),
          borderRadius: BorderRadius.circular(TermiusRadius.menu),
        ),
        child: busy
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Icon(
                icon,
                size: 14,
                color: destructive
                    ? const Color(0xFFE5484D)
                    : const Color(0xFFC7CBD6),
              ),
      ),
    );
  }
}
