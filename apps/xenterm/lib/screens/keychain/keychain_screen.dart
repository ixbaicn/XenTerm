/// The Keychain screen — the original's toolbar ([+ New key][▾] split,
/// Certificate / Windows Hello / FIDO2 ghost buttons, search/grid/keyboard
/// icons at right), the bold "密钥" section title, and key cards (blue key
/// chip + filename + type).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/termius_theme.dart';
import '../../widgets/toolbar.dart';

class KeychainScreen extends StatelessWidget {
  const KeychainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Toolbar row ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const SplitButton(
                  label: '新建密钥', icon: BootstrapIcons.plus),
              const SizedBox(width: 20),
              const GhostAction(
                  icon: BootstrapIcons.fileEarmarkText, label: '证书'),
              const SizedBox(width: 20),
              const GhostAction(
                  icon: BootstrapIcons.personBadge, label: 'Windows Hello'),
              const SizedBox(width: 20),
              const GhostAction(
                  icon: BootstrapIcons.usbDrive, label: 'FIDO2'),
              const Spacer(),
              const Row(children: [
                IconToggleButton(icon: BootstrapIcons.search),
                SizedBox(width: 6),
                IconToggleButton(icon: BootstrapIcons.grid),
                SizedBox(width: 6),
                IconToggleButton(icon: BootstrapIcons.keyboard),
              ]),
            ],
          ),
        ),
        // ── Section title + keys ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 0, 12),
          child: Text('密钥',
              style: theme.typography.bold.copyWith(
                  fontSize: 18, color: theme.colorScheme.foreground)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _KeyCard(name: 'xiaobai.pem', type: 'RSA'),
          ),
        ),
      ],
    );
  }
}

/// One key card: a blue circular key chip + filename over the type line.
class _KeyCard extends StatelessWidget {
  final String name;
  final String type;

  const _KeyCard({required this.name, required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF282B3D), // --dark-grey-3 card
        borderRadius: BorderRadius.circular(TermiusRadius.cardLarge),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF1B6AA8),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(BootstrapIcons.key, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: theme.typography.medium.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('类型 $type',
                    style: theme.typography.normal.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.mutedForeground)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
