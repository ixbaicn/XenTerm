/// Stub host data, until the flutter_rust_bridge lands (docs/flutter-bridge.md).
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
  });

  String get detail =>
      username.isEmpty ? address : '$username@$address:$port';

  /// "ssh, root, 阿里云" — the card's second line.
  String get subtitle =>
      tags.isEmpty ? 'ssh, $username' : 'ssh, $username, ${tags.join(', ')}';
}

/// Sample data sized to exercise the layout: grouped cards, a long label,
/// a mixed-case group pill. OS + tags + order mirror the reference screenshot.
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
