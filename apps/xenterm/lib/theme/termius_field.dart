/// The one Termius input field used by every screen.
///
/// Filled `--main-form-bg` (#32364A), radius 10, 36px tall, no outline,
/// placeholder in `--text-secondary`. Wrapping the stock widget once keeps
/// search, host details, snippets, forwarding, serial and prompts from each
/// drifting into a slightly different shade, height or radius.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'termius_theme.dart';

class TermiusField extends StatelessWidget {
  final String placeholder;
  final String? initialValue;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;
  final bool autofocus;
  final bool enabled;
  final double fontSize;
  final double height;
  final Widget? leading;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final TextAlign? textAlign;
  final EdgeInsetsGeometry? padding;

  const TermiusField({
    super.key,
    required this.placeholder,
    this.initialValue,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.obscure = false,
    this.autofocus = false,
    this.enabled = true,
    this.fontSize = 13.5,
    this.height = 36,
    this.leading,
    this.trailing,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.textAlign,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multiline = (maxLines ?? 1) > 1;
    final field = TextField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      placeholder: Text(
        placeholder,
        style: TextStyle(
          fontSize: fontSize,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscure,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      textAlign: textAlign ?? TextAlign.start,
      padding:
          padding ??
          EdgeInsets.symmetric(horizontal: 10, vertical: multiline ? 9 : 8),
      border: Border.all(color: Colors.transparent),
      borderRadius: BorderRadius.circular(TermiusRadius.field),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      style: theme.typography.normal.copyWith(
        fontSize: fontSize,
        color: enabled
            ? theme.colorScheme.foreground
            : theme.colorScheme.mutedForeground,
      ),
    );
    if (leading == null && trailing == null && !multiline) {
      return SizedBox(height: height, child: field);
    }
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.only(
        left: leading == null ? 10 : 9,
        right: trailing == null ? 10 : 9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(TermiusRadius.field),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Expanded(child: field),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}
