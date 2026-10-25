import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'data/hosts.dart';
import 'shell/root_shell.dart';
import 'terminal/core_settings.dart';
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
  /// Overrides the hosts loader (widget tests use the sample fixture; the app
  /// loads the real sessions from the Rust core).
  final Future<List<Host>> Function()? hostsLoader;
  final CoreSettingsController? settings;
  const XenTermApp({
    super.key,
    this.fonts,
    this.hostsLoader,
    this.settings,
  });

  @override
  State<XenTermApp> createState() => _XenTermAppState();
}

class _XenTermAppState extends State<XenTermApp> {
  static const _themeKey = 'xenterm.theme.light';
  bool _lightTheme = false;
  late final AppFonts _fonts = widget.fonts ?? AppFonts();
  late final CoreSettingsController _settings =
      widget.settings ?? CoreSettingsController();

  @override
  void initState() {
    super.initState();
    _fonts.addListener(_changed);
    if (widget.settings == null) _settings.load();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final light = prefs.getBool(_themeKey);
    if (light != null && mounted) setState(() => _lightTheme = light);
  }

  void _setTheme(bool light) {
    setState(() => _lightTheme = light);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_themeKey, light),
    );
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _fonts.removeListener(_changed);
    if (widget.fonts == null) _fonts.dispose();
    if (widget.settings == null) _settings.dispose();
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
      home: DefaultTextEditingShortcuts(
        child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: _fonts.uiFamily.isEmpty ? null : _fonts.uiFamily,
          fontSize: _fonts.uiSize,
        ),
          child: RootShell(
            lightTheme: _lightTheme,
            onThemeChanged: _setTheme,
            fonts: _fonts,
            settings: _settings,
            hostsLoader: widget.hostsLoader,
          ),
        ),
      ),
    );
  }
}
