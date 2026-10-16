import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'shell/root_shell.dart';
import 'theme/termius_theme.dart';

void main() {
  runApp(const XenTermApp());
}

class XenTermApp extends StatelessWidget {
  const XenTermApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The dark navy look is Termius's signature and the default here; the
    // light scheme is installed beside it for the theme switch to come.
    return ShadcnApp(
      title: 'XenTerm',
      theme: ThemeData(
        colorScheme: termiusDarkScheme(),
        // Termius's corner scale starts at the shadcn defaults' midpoint;
        // spec-exact radii (8/10) are applied at the call sites via
        // TermiusRadius, so the multiplier only styles library internals.
        radius: 0.5,
      ),
      home: const RootShell(),
    );
  }
}
