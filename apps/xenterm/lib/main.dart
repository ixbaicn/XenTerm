import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'shell/root_shell.dart';
import 'theme/termius_theme.dart';
import 'theme/app_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fonts = AppFonts();
  await fonts.load();
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

  runApp(XenTermApp(fonts: fonts));
}

class XenTermApp extends StatefulWidget {
  final AppFonts? fonts;
  const XenTermApp({super.key, this.fonts});

  @override
  State<XenTermApp> createState() => _XenTermAppState();
}

class _XenTermAppState extends State<XenTermApp> {
  bool _lightTheme = false;
  late final AppFonts _fonts = widget.fonts ?? AppFonts();

  @override
  void initState() {
    super.initState();
    _fonts.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _fonts.removeListener(_changed);
    if (widget.fonts == null) _fonts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'XenTerm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: _lightTheme ? termiusLightScheme() : termiusDarkScheme(),
        typography: const Typography.geist().scale(_fonts.uiSize / 14),
        // Termius's corner scale starts at the shadcn defaults' midpoint;
        // spec-exact radii (8/10/15) are applied at the call sites via
        // TermiusRadius, so the multiplier only styles library internals.
        radius: 0.5,
      ),
      home: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: _fonts.uiFamily.isEmpty ? null : _fonts.uiFamily,
          fontSize: _fonts.uiSize,
        ),
        child: RootShell(
          lightTheme: _lightTheme,
          onThemeChanged: (light) => setState(() => _lightTheme = light),
          fonts: _fonts,
        ),
      ),
    );
  }
}
