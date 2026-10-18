/// Host model shared by the hosts screen; rows arrive from the Rust core via
/// the FFI bridge (lib/bridge/native_bridge.dart).
///
/// The shapes mirror the Rust side's `Session` projection the bridge will
/// expose — same field names where they carry over — so replacing the
/// repository with generated bindings touches screens, not models.
library;

/// The OS a host runs — drives the colored brand chip on cards and in the
/// details drawer, the way the original shows the real Debian/Ubuntu logos.
enum HostOs { debian, ubuntu, arch, linux, windows, apple, android }

class Host {
  final String id;
  final String label;
  final String address;
  final int port;
  final String username;
  final String group;
  final List<String> tags;
  final HostOs os;
  final String? lastUsed;

  /// "ssh" / "serial" / "telnet" / "local" — the first part of the card line.
  final String protocol;

  /// "password" / "key" / "keyboard-interactive".
  final String auth;

  /// Non-secret private key path; empty when the host uses a password.
  final String keyPath;

  // Serial-line settings (kind == 'serial').
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final String parity;
  final String flowControl;

  /// Whether the core has a stored login password for this serial session.
  final bool hasPassword;

  /// Another saved SSH host used as this session's jump host (empty = none).
  final String jumpHostId;

  /// Temporary session (local/serial quick connect) that must not be stored.
  final bool ephemeral;

  /// One-shot credential for a temporary serial console login. Lives only in
  /// memory; saved hosts pass the secret through the core store instead.
  final String adhocPassword;

  const Host({
    required this.id,
    required this.label,
    required this.address,
    this.port = 22,
    this.username = 'root',
    this.group = '',
    this.tags = const [],
    this.os = HostOs.debian,
    this.lastUsed,
    this.protocol = 'ssh',
    this.auth = 'password',
    this.keyPath = '',
    this.baudRate = 115200,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = 'none',
    this.flowControl = 'none',
    this.hasPassword = false,
    this.jumpHostId = '',
    this.ephemeral = false,
    this.adhocPassword = '',
  });

  /// Maps one `xenterm_sessions_json` row (native bridge) onto the UI model.
  factory Host.fromCoreJson(Map<String, dynamic> json) {
    final kind = (json['kind'] as String?) ?? 'ssh';
    final address = (json['address'] as String?) ?? '';
    final label = (json['label'] as String?) ?? '';
    return Host(
      id: (json['id'] ?? '').toString(),
      label: label.isEmpty ? address : label,
      address: address,
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: (json['username'] as String?) ?? '',
      group: (json['group'] as String?) ?? '',
      protocol: kind,
      os: kind == 'serial' ? HostOs.linux : HostOs.debian,
      lastUsed: json['last_used'] as String?,
      auth: (json['auth'] as String?) ?? 'password',
      keyPath: (json['private_key_path'] as String?) ?? '',
      baudRate: (json['baud_rate'] as num?)?.toInt() ?? 115200,
      dataBits: (json['data_bits'] as num?)?.toInt() ?? 8,
      stopBits: (json['stop_bits'] as num?)?.toInt() ?? 1,
      parity: (json['parity'] as String?) ?? 'none',
      flowControl: (json['flow_control'] as String?) ?? 'none',
      hasPassword: json['has_password'] == true,
      jumpHostId: (json['jump_session_id'] as String?) ?? '',
    );
  }

  /// Payload for the core's ad-hoc starter (temporary tabs).
  Map<String, dynamic> toAdhocPayload() => {
    'label': label,
    'address': address,
    'port': port,
    'username': username,
    'kind': protocol,
    'password': adhocPassword,
    'serial_port': isSerial ? address : '',
    'baud_rate': baudRate,
    'data_bits': dataBits,
    'stop_bits': stopBits,
    'parity': parity,
    'flow_control': flowControl,
  };

  Host copyWith({HostOs? os, bool? hasPassword}) => Host(
    id: id,
    label: label,
    address: address,
    port: port,
    username: username,
    group: group,
    tags: tags,
    os: os ?? this.os,
    lastUsed: lastUsed,
    protocol: protocol,
    auth: auth,
    keyPath: keyPath,
    baudRate: baudRate,
    dataBits: dataBits,
    stopBits: stopBits,
    parity: parity,
    flowControl: flowControl,
    hasPassword: hasPassword ?? this.hasPassword,
    jumpHostId: jumpHostId,
    ephemeral: ephemeral,
    adhocPassword: adhocPassword,
  );

  bool get isSerial => protocol == 'serial';

  /// "8N1" for a serial line.
  String get serialFrame {
    final parityLetter = switch (parity) {
      'odd' => 'O',
      'even' => 'E',
      _ => 'N',
    };
    return '$dataBits$parityLetter$stopBits';
  }

  String get detail => isSerial
      ? '$address · $baudRate ${serialFrame.toUpperCase()}'
      : username.isEmpty
      ? address
      : '$username@$address:$port';

  /// "ssh, root, 阿里云" — the card's second line.
  String get subtitle {
    final parts = <String>[
      protocol,
      if (isSerial)
        '$baudRate ${serialFrame.toUpperCase()}'
      else if (username.isNotEmpty)
        username,
      if (tags.isNotEmpty) ...tags else if (group.isNotEmpty) group,
    ];
    return parts.join(', ');
  }
}

/// Sample fixture used by widget tests (the app itself loads the core's real
/// sessions). OS + tags + order mirror the reference screenshot.
const kSampleHosts = <Host>[
  Host(
    id: 'sz-ali',
    label: '小白的深圳服务器（阿里云）',
    address: 'sz.example.cn',
    group: '生产',
    tags: ['阿里云'],
    os: HostOs.debian,
  ),
  Host(
    id: 'nb-yy',
    label: '小白的宁波服务器(雨云)',
    address: 'nb.example.cn',
    group: '生产',
    tags: ['雨云'],
    os: HostOs.ubuntu,
    lastUsed: '2026-10-14 09:32',
  ),
  Host(
    id: 'nat-zz',
    label: '小白的枣庄NAT服务器（小兔互联）',
    address: 'nat.example.cn',
    port: 22022,
    group: '生产',
    os: HostOs.debian,
    lastUsed: '2026-10-15 21:04',
  ),
  Host(
    id: 'gw2',
    label: 'gateway-test02',
    address: '10.0.0.2',
    group: '内网',
    os: HostOs.ubuntu,
  ),
  Host(
    id: 'nanopi',
    label: 'NanoPi-R3S（物联网小主机）',
    address: '192.168.2.10',
    username: 'pi',
    group: '内网',
    os: HostOs.ubuntu,
  ),
  Host(
    id: 'dev-box',
    label: '开发机',
    address: '10.8.0.3',
    username: 'dev',
    os: HostOs.debian,
  ),
];
