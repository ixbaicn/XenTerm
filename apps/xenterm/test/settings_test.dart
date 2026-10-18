import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:xenterm_app/bridge/native_bridge.dart';
import 'package:xenterm_app/screens/settings/settings_screen.dart';
import 'package:xenterm_app/terminal/core_settings.dart';
import 'package:xenterm_app/theme/app_fonts.dart';
import 'package:xenterm_app/theme/termius_theme.dart';

Widget _app(Widget child) => ShadcnApp(
  theme: ThemeData(colorScheme: termiusDarkScheme()),
  home: Scaffold(child: SizedBox(width: 1200, height: 900, child: child)),
);

void main() {
  testWidgets('renderer settings save through the core callback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final fonts = AppFonts();
    addTearDown(fonts.dispose);
    final controller = CoreSettingsController()
      ..settings = const CoreSettings()
      ..loaded = true;
    addTearDown(controller.dispose);
    final saved = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _app(
        SettingsScreen(
          lightTheme: false,
          onThemeChanged: (_) {},
          fonts: fonts,
          settings: controller,
          saveSettings: (values) async {
            saved.add(values);
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Terminal settings'), findsOneWidget);

    final paddingRow = tester.getRect(
      find.byKey(const ValueKey('setting-padding')),
    );
    await tester.tapAt(Offset(paddingRow.right - 20, paddingRow.center.dy));
    await tester.pumpAndSettle();
    expect(saved.last['padding'], false);

    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bar'));
    await tester.pumpAndSettle();
    expect(saved.last['cursor_style'], 'bar');

    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();
    expect(find.text('Session logs'), findsOneWidget);
    final logsRow = tester.getRect(
      find.byKey(const ValueKey('setting-session-logs')),
    );
    await tester.tapAt(Offset(logsRow.right - 20, logsRow.center.dy));
    await tester.pumpAndSettle();
    expect(saved.last['session_logs'], true);
    expect(find.textContaining('app data folder'), findsOneWidget);
  });
}
