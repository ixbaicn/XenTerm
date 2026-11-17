import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:xenterm_app/data/hosts.dart';
import 'package:xenterm_app/shell/title_bar.dart';
import 'package:xenterm_app/theme/app_theme.dart';

Widget _app(Widget child) => ShadcnApp(
  theme: ThemeData(colorScheme: xtDarkScheme()),
  home: Scaffold(child: SizedBox(width: 900, height: 50, child: child)),
);

void main() {

  testWidgets(
    'macOS leaves the native traffic lights clear and hides duplicate controls',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const TitleBar(
            macOS: true,
            openHosts: [
              Host(id: 'mac-1', label: 'alpha', address: '10.0.0.1'),
            ],
            activeHostId: 'mac-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // macOS draws close/minimize/zoom itself; our content must start after
      // them instead of drawing the hamburger underneath the buttons.
      final toggle = tester.getRect(
        find.byKey(const ValueKey('toggle-sidebar')),
      );
      expect(toggle.left, greaterThanOrEqualTo(80));

      // The Windows-style trio would duplicate the native buttons.
      expect(find.byKey(const ValueKey('window-minimize')), findsNothing);
      expect(find.byKey(const ValueKey('window-maximize')), findsNothing);
      expect(find.byKey(const ValueKey('window-close')), findsNothing);
    },
  );

  testWidgets('Windows keeps its custom window controls', (tester) async {
    await tester.pumpWidget(
      _app(
        const TitleBar(
          macOS: false,
          openHosts: [
            Host(id: 'win-1', label: 'alpha', address: '10.0.0.1'),
          ],
          activeHostId: 'win-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = tester.getRect(find.byKey(const ValueKey('toggle-sidebar')));
    expect(toggle.left, lessThan(20));
    expect(find.byKey(const ValueKey('window-minimize')), findsOneWidget);
    expect(find.byKey(const ValueKey('window-maximize')), findsOneWidget);
    expect(find.byKey(const ValueKey('window-close')), findsOneWidget);
  });
}
