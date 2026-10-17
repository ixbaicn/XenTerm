import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'shell/root_shell.dart';
import 'theme/termius_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Termius draws its own titlebar (the tab pills live in it), so the native
  // frame is hidden; dragging is re-provided by the shell's drag region and
  // the platform's resize borders stay active.
  const options = WindowOptions(
    title: 'XenTerm',
    titleBarStyle: TitleBarStyle.hidden,
    minimumSize: Size(940, 600),
    backgroundColor: Colors.transparent,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

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
        // spec-exact radii (8/10/15) are applied at the call sites via
        // TermiusRadius, so the multiplier only styles library internals.
        radius: 0.5,
      ),
      home: const RootShell(),
    );
  }
}
