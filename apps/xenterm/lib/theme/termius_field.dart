/// The Termius input field: borderless, filled --main-form-bg
/// (--dark-grey-4 #32364a), radius 10, placeholder dark-grey-6 — the look
/// every input on the hosts screen shares, wrapped once so the screens don't
/// each restyle the stock widget (whose default border/fill reads wrong).
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'termius_theme.dart';

class TermiusField extends StatelessWidget {
  final String placeholder;
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final double fontSize;
  final Widget? leading;

  const TermiusField({
    super.key,
    required this.placeholder,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.obscure = false,
    this.fontSize = 14,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget field = TextField(
      controller: controller,
      initialValue: initialValue,
      placeholder: Text(
        placeholder,
        style: TextStyle(
            fontSize: fontSize - 1, color: const Color(0xFF5A5E73)), // dg-6
      ),
      onChanged: onChanged,
      obscureText: obscure,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary, // --main-form-bg dg-4
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      style: theme.typography.normal.copyWith(
          fontSize: fontSize, color: theme.colorScheme.foreground),
    );
    if (leading != null) {
      field = Row(
        children: [
          leading!,
          const SizedBox(width: 10),
          Expanded(child: field),
        ],
      );
    }
    return field;
  }
}
