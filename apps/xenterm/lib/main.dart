import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'data/hosts.dart';
import 'l10n/app_language.dart';
import 'shell/root_shell.dart';
import 'terminal/core_settings.dart';
import 'theme/app_theme.dart';
import 'theme/app_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fonts = AppFonts();
  await fonts.load();
  await windowManager.ensureInitialized();

  // The shell draws its own titlebar (session tabs live in it), so the native
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
  static const _languageKey = 'xenterm.language';
  bool _lightTheme = false;
  String _language = 'en';
  late final AppFonts _fonts = widget.fonts ?? AppFonts();
  late final CoreSettingsController _settings =
      widget.settings ?? CoreSettingsController();

  @override
  void initState() {
    super.initState();
    _fonts.addListener(_changed);
    if (widget.settings == null) _settings.load();
    _restoreTheme();
    _restoreLanguage();
  }

  Future<void> _restoreTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final light = prefs.getBool(_themeKey);
    if (light != null && mounted) setState(() => _lightTheme = light);
  }

  Future<void> _restoreLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageKey);
    if (mounted && AppLanguage.supported.containsKey(code)) {
      setState(() => _language = code!);
    }
  }

  void _setLanguage(String code) {
    if (!AppLanguage.supported.containsKey(code)) return;
    setState(() => _language = code);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_languageKey, code),
    );
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
        colorScheme: _lightTheme ? xtLightScheme() : xtDarkScheme(),
        typography: const Typography.geist().scale(_fonts.uiSize / 14),
        // The app's own radii (8/10/15) are applied at the call sites via
        // XtRadius; the multiplier only styles library internals.
        radius: 0.5,
      ),
      home: AppLanguage(
        code: _language,
        onChanged: _setLanguage,
        child: DefaultTextEditingShortcuts(
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
      ),
    );
  }
}
