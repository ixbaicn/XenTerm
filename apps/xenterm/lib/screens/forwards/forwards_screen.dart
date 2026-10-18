/// The Port Forwarding screen — the original's toolbar ([+ New rule][▾],
/// ghost actions) over rule cards: type chip (Local/Remote/Dynamic) + name +
/// bind → target endpoints + enable switch, per the extracted
/// FiltersHeader/entity patterns.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';

class _Rule {
  final String name;
  final String kind; // Local / Remote / Dynamic
  final String bind;
  final String target;

  const _Rule(this.name, this.kind, this.bind, this.target);
}

const _rules = <_Rule>[
  _Rule('Web 本地转发', 'Local', '127.0.0.1:8080', '10.0.0.2:80'),
  _Rule('数据库远程映射', 'Remote', '0.0.0.0:15432', '127.0.0.1:5432'),
  _Rule('SOCKS 动态代理', 'Dynamic', '127.0.0.1:1080', '—'),
];

Color _kindColor(String kind) => switch (kind) {
      'Local' => const Color(0xFF21B568), // --green
      'Remote' => const Color(0xFF2091F6), // --blue
      _ => const Color(0xFFF8AA4B), // --orange
    };

class ForwardsScreen extends StatelessWidget {
  const ForwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const SplitButton(
                  label: '新建转发规则', icon: BootstrapIcons.plus),
              const SizedBox(width: 20),
              const GhostAction(
                  icon: BootstrapIcons.arrowLeftRight, label: '全部暂停'),
              const Spacer(),
              const Row(children: [
                IconToggleButton(icon: BootstrapIcons.search),
                SizedBox(width: 6),
                IconToggleButton(icon: BootstrapIcons.grid),
              ]),
            ],
          ),
        ),
        const SectionTitle(text: '端口转发'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              for (final rule in _rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RuleCard(rule: rule),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  final _Rule rule;

  const _RuleCard({required this.rule});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kindColor = _kindColor(rule.kind);
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kindColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(TermiusRadius.pill),
            ),
            child: Text(rule.kind,
                style: theme.typography.medium
                    .copyWith(fontSize: 12, color: kindColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.medium.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('${rule.bind} → ${rule.target}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.normal.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.mutedForeground)),
              ],
            ),
          ),
          Switch(value: true, onChanged: (_) {}),
        ],
      ),
    );
  }
}
