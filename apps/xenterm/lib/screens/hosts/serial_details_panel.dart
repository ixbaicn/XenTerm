/// Serial connection details in the right-hand host drawer: pick a detected
/// port (or type one), set the line parameters, and optionally store the
/// console login some serial servers ask for. This is the same drawer the SSH
/// host editor uses — no modal — matching the original Termius flow.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../bridge/native_bridge.dart';
import '../../data/hosts.dart';
import '../../theme/termius_field.dart';
import '../../theme/termius_theme.dart';

/// The values the panel hands back; the screen owns persistence.
class SerialDraft {
  final String label;
  final String port;
  final String group;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final String parity;
  final String flowControl;
  final String username;
  final String password;

  const SerialDraft({
    required this.label,
    required this.port,
    required this.group,
    required this.baudRate,
    required this.dataBits,
    required this.stopBits,
    required this.parity,
    required this.flowControl,
    required this.username,
    required this.password,
  });
}

typedef SerialPortLoader = Future<List<SerialPortInfo>> Function();

class SerialDetailsPanel extends StatefulWidget {
  /// Existing serial host when editing; null creates a new session.
  final Host? host;
  final SerialPortLoader? loadPorts;
  final ValueChanged<SerialDraft> onSubmit;
  final VoidCallback onClose;

  /// Persistence error from the screen; shown in the panel so the typed
  /// values are not lost when a save fails.
  final String? error;

  const SerialDetailsPanel({
    super.key,
    this.host,
    this.loadPorts,
    required this.onSubmit,
    required this.onClose,
    this.error,
  });

  @override
  State<SerialDetailsPanel> createState() => _SerialDetailsPanelState();
}

class _SerialDetailsPanelState extends State<SerialDetailsPanel> {
  static const _baudRates = [
    1200,
    2400,
    4800,
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
    460800,
    921600,
  ];

  late final TextEditingController _label = TextEditingController(
    text: widget.host?.label ?? 'Serial',
  );
  late final TextEditingController _port = TextEditingController(
    text: widget.host?.address ?? '',
  );
  late final TextEditingController _user = TextEditingController(
    text: widget.host?.username ?? '',
  );
  final TextEditingController _password = TextEditingController();
  late int _baud = widget.host?.baudRate ?? 115200;
  late int _dataBits = widget.host?.dataBits ?? 8;
  late int _stopBits = widget.host?.stopBits ?? 1;
  late String _parity = widget.host?.parity ?? 'none';
  late String _flow = widget.host?.flowControl ?? 'none';
  bool _advanced = false;
  bool _loadingPorts = true;
  List<SerialPortInfo> _ports = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
  }

  @override
  void dispose() {
    _label.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _refreshPorts() async {
    setState(() => _loadingPorts = true);
    try {
      final ports = await (widget.loadPorts ?? loadSerialPortsFromCore)();
      if (!mounted) return;
      setState(() {
        _ports = ports;
        _loadingPorts = false;
        // A new serial session starts on the first attached device.
        if (_port.text.trim().isEmpty && ports.isNotEmpty) {
          _port.text = ports.first.name;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPorts = false;
        _ports = const [];
        _error = error is NativeBridgeError ? error.message : '$error';
      });
    }
  }

  void _submit() {
    final port = _port.text.trim();
    if (port.isEmpty) {
      setState(() => _error = 'Choose or type a serial port');
      return;
    }
    final label = _label.text.trim();
    widget.onSubmit(
      SerialDraft(
        label: label.isEmpty ? port : label,
        port: port,
        group: widget.host?.group ?? '',
        baudRate: _baud,
        dataBits: _dataBits,
        stopBits: _stopBits,
        parity: _parity,
        flowControl: _flow,
        username: _user.text.trim(),
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.host != null;
    return Container(
      color: const Color(0xFF1D2033),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.only(left: 15, right: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF282B3D),
              border: Border(bottom: BorderSide(color: Color(0xFF32364A))),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.usb, size: 16, color: Color(0xFF8D91A5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    editing ? 'Serial Details' : 'Serial Connection',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.semiBold.copyWith(
                      fontSize: 16,
                      color: const Color(0xFF8D91A5),
                    ),
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('serial-cancel'),
                  onTap: widget.onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      LucideIcons.arrowRightToLine,
                      size: 16,
                      color: Color(0xFF8D91A5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282B3D),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _labelText('NAME', theme),
                        const SizedBox(height: 6),
                        TermiusField(
                          key: const ValueKey('serial-label'),
                          controller: _label,
                          placeholder: 'Serial',
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _labelText('PORT', theme)),
                            GestureDetector(
                              key: const ValueKey('serial-refresh'),
                              onTap: _refreshPorts,
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.refreshCw,
                                    size: 12,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _loadingPorts ? 'Scanning…' : 'Refresh',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Dropdown + free input: picking a detected port fills
                        // the field, but any device path can still be typed.
                        _PortComboField(
                          controller: _port,
                          ports: _ports,
                          loading: _loadingPorts,
                          onRefresh: _refreshPorts,
                        ),
                        const SizedBox(height: 14),
                        _labelText('BAUD RATE', theme),
                        const SizedBox(height: 6),
                        _ChoiceField<int>(
                          key: const ValueKey('serial-baud'),
                          value: _baud,
                          options: {
                            for (final rate in _baudRates) rate: '$rate',
                          },
                          onChanged: (value) => setState(() => _baud = value),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          key: const ValueKey('serial-advanced'),
                          onTap: () => setState(() => _advanced = !_advanced),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              AnimatedRotation(
                                turns: _advanced ? 0.25 : 0,
                                duration: TermiusMotion.micro,
                                child: Icon(
                                  LucideIcons.chevronRight,
                                  size: 15,
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Advanced',
                                style: theme.typography.medium.copyWith(
                                  fontSize: 13,
                                  color: theme.colorScheme.foreground,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$_dataBits${_parityLetter(_parity)}$_stopBits',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_advanced) ...[
                          const SizedBox(height: 14),
                          _labelText('DATA BITS', theme),
                          const SizedBox(height: 6),
                          _ChoiceField<int>(
                            key: const ValueKey('serial-data-bits'),
                            value: _dataBits,
                            options: const {5: '5', 6: '6', 7: '7', 8: '8'},
                            onChanged: (value) =>
                                setState(() => _dataBits = value),
                          ),
                          const SizedBox(height: 12),
                          _labelText('STOP BITS', theme),
                          const SizedBox(height: 6),
                          _ChoiceField<int>(
                            key: const ValueKey('serial-stop-bits'),
                            value: _stopBits,
                            options: const {1: '1', 2: '2'},
                            onChanged: (value) =>
                                setState(() => _stopBits = value),
                          ),
                          const SizedBox(height: 12),
                          _labelText('PARITY', theme),
                          const SizedBox(height: 6),
                          _ChoiceField<String>(
                            key: const ValueKey('serial-parity'),
                            value: _parity,
                            options: const {
                              'none': 'None',
                              'even': 'Even',
                              'odd': 'Odd',
                            },
                            onChanged: (value) =>
                                setState(() => _parity = value),
                          ),
                          const SizedBox(height: 12),
                          _labelText('FLOW CONTROL', theme),
                          const SizedBox(height: 6),
                          _ChoiceField<String>(
                            key: const ValueKey('serial-flow'),
                            value: _flow,
                            options: const {
                              'none': 'None',
                              'hardware': 'RTS/CTS',
                              'software': 'XON/XOFF',
                            },
                            onChanged: (value) => setState(() => _flow = value),
                          ),
                          const SizedBox(height: 18),
                          _labelText('CONSOLE LOGIN (OPTIONAL)', theme),
                          const SizedBox(height: 6),
                          Text(
                            'Some serial servers ask for a login before the '
                            'shell. When set, the app answers those prompts.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TermiusField(
                            key: const ValueKey('serial-user'),
                            controller: _user,
                            placeholder: 'Username',
                            leading: const Icon(
                              LucideIcons.user,
                              size: 14,
                              color: Color(0xFF8D91A5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TermiusField(
                            key: const ValueKey('serial-password'),
                            controller: _password,
                            obscure: true,
                            placeholder: widget.host?.hasPassword == true
                                ? 'Password stored — leave blank to keep'
                                : 'Password (optional)',
                            leading: const Icon(
                              LucideIcons.keyRound,
                              size: 14,
                              color: Color(0xFF8D91A5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null || widget.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error ?? widget.error!,
                      style: theme.typography.normal.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.destructive,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: Button(
                key: const ValueKey('serial-connect'),
                style: const ButtonStyle.primary(),
                onPressed: _submit,
                child: Text(editing ? 'Save & connect' : 'Connect'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelText(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.mutedForeground,
      ),
    );
  }

  static String _parityLetter(String parity) => switch (parity) {
    'odd' => 'O',
    'even' => 'E',
    _ => 'N',
  };

}

/// Editable port field with a dropdown of detected devices.
///
/// The text stays editable (a serial server path is not always an enumerated
/// COM/tty device); the chevron lists what the OS reported and fills the field
/// on selection.
class _PortComboField extends StatefulWidget {
  final TextEditingController controller;
  final List<SerialPortInfo> ports;
  final bool loading;
  final VoidCallback onRefresh;

  const _PortComboField({
    required this.controller,
    required this.ports,
    required this.loading,
    required this.onRefresh,
  });

  @override
  State<_PortComboField> createState() => _PortComboFieldState();
}

class _PortComboFieldState extends State<_PortComboField> {
  final OverlayPortalController _menu = OverlayPortalController();
  final LayerLink _link = LayerLink();
  double _width = 0;

  void _toggle() {
    if (_menu.isShowing) {
      _menu.hide();
    } else {
      _menu.show();
    }
  }

  void _pick(SerialPortInfo port) {
    widget.controller.text = port.name;
    widget.controller.selection = TextSelection.collapsed(
      offset: port.name.length,
    );
    _menu.hide();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _menu,
      overlayChildBuilder: _overlay,
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth.isFinite) {
              _width = constraints.maxWidth;
            }
            return TermiusField(
              key: const ValueKey('serial-port'),
              controller: widget.controller,
              placeholder: 'COM3 or /dev/ttyUSB0',
              leading: const Icon(
                LucideIcons.usb,
                size: 14,
                color: Color(0xFF8D91A5),
              ),
              trailing: GestureDetector(
                key: const ValueKey('serial-port-toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(
                    child: widget.loading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : Icon(
                            _menu.isShowing
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 15,
                            color: Theme.of(context)
                                .colorScheme
                                .mutedForeground,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
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
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          showWhenUnlinked: false,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: _width > 0 ? _width : 320,
              constraints: const BoxConstraints(maxHeight: 260),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF282B3D),
                borderRadius: BorderRadius.circular(TermiusRadius.field),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.ports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 10,
                        ),
                        child: Text(
                          widget.loading
                              ? 'Scanning serial ports…'
                              : 'No serial ports detected — type a device path',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      )
                    else
                      for (final port in widget.ports)
                        GestureDetector(
                          key: ValueKey('serial-port-${port.name}'),
                          onTap: () => _pick(port),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: widget.controller.text == port.name
                                  ? theme.colorScheme.muted
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    port.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.foreground,
                                    ),
                                  ),
                                ),
                                if (widget.controller.text == port.name) ...[
                                  Icon(
                                    LucideIcons.check,
                                    size: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  port.kind,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    const Divider(height: 9, color: Color(0xFF3E4257)),
                    GestureDetector(
                      key: const ValueKey('serial-port-refresh'),
                      onTap: () {
                        _menu.hide();
                        widget.onRefresh();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.refreshCw,
                              size: 13,
                              color: theme.colorScheme.mutedForeground,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Refresh ports',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A 36px filled select with a dropdown, matching the Termius field metrics.
class _ChoiceField<T> extends StatefulWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _ChoiceField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_ChoiceField<T>> createState() => _ChoiceFieldState<T>();
}

class _ChoiceFieldState<T> extends State<_ChoiceField<T>> {
  final OverlayPortalController _menu = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.options[widget.value] ?? '${widget.value}';
    return OverlayPortal(
      controller: _menu,
      overlayChildBuilder: _overlay,
      child: CompositedTransformTarget(
        link: _link,
        child: GestureDetector(
          onTap: () => _menu.isShowing ? _menu.hide() : _menu.show(),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(TermiusRadius.field),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
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
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          showWhenUnlinked: false,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              constraints: const BoxConstraints(minWidth: 160, maxHeight: 260),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF282B3D),
                borderRadius: BorderRadius.circular(TermiusRadius.field),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in widget.options.entries)
                      GestureDetector(
                        onTap: () {
                          _menu.hide();
                          widget.onChanged(entry.key);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: entry.key == widget.value
                                ? theme.colorScheme.muted
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.foreground,
                                  ),
                                ),
                              ),
                              if (entry.key == widget.value)
                                Icon(
                                  LucideIcons.check,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
