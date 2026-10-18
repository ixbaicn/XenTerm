/// The Known Hosts screen — the original's toolbar (search icon group) over
/// known-host entries: key-type chip + host pattern + SHA-256 fingerprint
/// (design-tokens.md entity patterns).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';

class _KnownHost {
  final String pattern;
  final String algo;
  final String fingerprint;

  const _KnownHost(this.pattern, this.algo, this.fingerprint);
}

const _hosts = <_KnownHost>[
  _KnownHost('192.168.2.10', 'ED25519',
      'SHA256:4f8k2Qw7rRv9mN1sT3uXyZ5aBcDeFgHiJkLmNoPqRsTu'),
  _KnownHost('nat.example.cn', 'RSA',
      'SHA256:9zYxWvUtSrQpOnMlKjIhGfEdCbA9876543210zyxwvutsrqpo'),
];

class KnownHostsScreen extends StatelessWidget {
  const KnownHostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Spacer(),
              const Row(children: [
                IconToggleButton(icon: BootstrapIcons.search),
                SizedBox(width: 6),
                IconToggleButton(icon: BootstrapIcons.trash),
              ]),
            ],
          ),
        ),
        const SectionTitle(text: '已知主机'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              for (final host in _hosts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _KnownHostCard(host: host),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KnownHostCard extends StatelessWidget {
  final _KnownHost host;

  const _KnownHostCard({required this.host});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.popover,
              borderRadius: BorderRadius.circular(TermiusRadius.card),
            ),
            child: Icon(BootstrapIcons.shieldCheck,
                size: 18, color: const Color(0xFF21B568)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(host.pattern,
                    style: theme.typography.medium.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('${host.algo} · ${host.fingerprint}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.normal.copyWith(
                        fontSize: 12,
                        fontFamily: 'GeistMono',
                        color: theme.colorScheme.mutedForeground)),
              ],
            ),
          ),
          Icon(BootstrapIcons.trash,
              size: 15, color: theme.colorScheme.mutedForeground),
        ],
      ),
    );
  }
}
