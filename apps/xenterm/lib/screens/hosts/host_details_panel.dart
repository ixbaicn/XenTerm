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
import '../../theme/termius_theme.dart';
import 'host_card.dart';

const _cardSurface = Color(0xFF282B3D); // --dark-grey-3 / --card-a
const _divider = Color(0xFF3E4257); // --dark-grey-5
const _textDisabled = Color(0xFF5A5E73); // --dark-grey-6
const _titleGrey = Color(0xFF8D91A5); // --dark-grey-7
const _headerBorder = Color(0xFF32364A); // --dark-grey-4

class HostDetailsPanel extends StatelessWidget {
  final Host host;
  final VoidCallback onClose;
  final VoidCallback onConnect;

  const HostDetailsPanel({
    super.key,
    required this.host,
    required this.onClose,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.background, // --dark-grey-2
      child: Column(
        children: [
          _Header(onClose: onClose),
          Expanded(
            child: SingleChildScrollView(
              // formPaddings: 15px calc(15px - scrollbar) 85px 15px; gap 15.
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FormCard(
                    children: [
                      const _SectionTitle('Address'),
                      Row(
                        children: [
                          _OsChip(host: host),
                          Expanded(
                            child: _PanelField(
                              initialValue: host.address,
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
                      _PanelField(initialValue: host.label, placeholder: 'Label'),
                      _PanelField(
                        placeholder: 'Parent Group',
                        leading: LucideIcons.folder,
                      ),
                      _PanelField(
                        placeholder: 'Tags',
                        leading: LucideIcons.tag,
                      ),
                      const _BackspaceRow(),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _FormCard(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
                    children: [
                      _PortRow(port: host.port),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionTitle('Credentials'),
                          const SizedBox(height: 10),
                          _PanelField(
                            initialValue: host.username,
                            placeholder: 'Username',
                            leading: LucideIcons.user,
                          ),
                          const SizedBox(height: 10),
                          const _PanelField(
                            placeholder: 'Password',
                            leading: LucideIcons.keyRound,
                            obscure: true,
                          ),
                        ],
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
                onPressed: onConnect,
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

/// The 56px header: title in --dark-grey-7 16px/600, saved check, ⋯, →|.
class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

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
          // savingStatus: an 18px slot with a 14px check.
          const SizedBox(
            width: 18,
            child: Icon(LucideIcons.check, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 5),
          _HeaderIcon(
            onPressed: () {},
            child: const Icon(LucideIcons.ellipsis,
                size: 15, color: _titleGrey),
          ),
          _HeaderIcon(
            onPressed: onClose,
            child: const Icon(LucideIcons.arrowRightToLine,
                size: 16, color: _titleGrey),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final VoidCallback onPressed;
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
  final String? initialValue;
  final IconData? leading;
  final bool obscure;
  final double height;

  const _PanelField({
    required this.placeholder,
    this.initialValue,
    this.leading,
    this.obscure = false,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      padding: leading == null
          ? const EdgeInsets.symmetric(horizontal: 10)
          : const EdgeInsets.only(left: 9, right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TermiusRadius.field),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 14, color: _textDisabled),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: TextField(
              initialValue: initialValue,
              obscureText: obscure,
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(TermiusRadius.field),
              ),
              placeholder: Text(
                placeholder,
                style: theme.typography.normal.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              style: theme.typography.normal.copyWith(
                fontSize: 14,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backspace selector row: outlined, keyboard icon, label and value both in
/// --dark-grey-6 (the disabled tone), value right-aligned.
class _BackspaceRow extends StatelessWidget {
  const _BackspaceRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TermiusRadius.field),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.keyboard, size: 14, color: _textDisabled),
          const SizedBox(width: 5),
          Text(
            'Backspace',
            style: theme.typography.normal.copyWith(
              fontSize: 16,
              color: _textDisabled,
            ),
          ),
          const Spacer(),
          Text(
            'Default',
            style: theme.typography.normal.copyWith(
              fontSize: 16,
              color: _textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}



/// "SSH on [22] port" with a 1px --dark-grey-5 divider underneath.
class _PortRow extends StatelessWidget {
  final int port;

  const _PortRow({required this.port});

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
              initialValue: '$port',
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
