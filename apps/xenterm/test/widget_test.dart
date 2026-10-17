import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenterm_app/main.dart';
import 'package:xenterm_app/theme/app_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the shell mounts with the hosts screen showing', (tester) async {
    await tester.pumpWidget(const XenTermApp());
    expect(find.text('主机'), findsWidgets);
    // The toolbar's button and the grid's tail card both say it.
    expect(find.text('新建主机'), findsWidgets);
  });

  testWidgets('a host opens the terminal preview and can be closed', (
    tester,
  ) async {
    await tester.pumpWidget(const XenTermApp());
    await tester.tap(find.text('gateway-test02'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接').first);
    await tester.pumpAndSettle();
    expect(find.text('SSH 连接预览 · 尚未连接到服务器'), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
    final keysList = find.byType(ListView).last;
    await tester.scrollUntilVisible(
      find.text('^P'),
      180,
      scrollable: find
          .descendant(of: keysList, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('^X'), findsOneWidget);
    expect(find.text('^P'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('terminal-snippets-tab')));
    await tester.pumpAndSettle();
    expect(find.text('apt update'), findsWidgets);
    await tester.tap(find.byIcon(material.Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('新建主机'), findsWidgets);
  });

  testWidgets(
    'SFTP preview opens once, switches tabs, and closes independently',
    (tester) async {
      await tester.pumpWidget(const XenTermApp());
      await tester.tap(find.text('gateway-test02'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接').first);
      await tester.pumpAndSettle();

      expect(find.text('SSH 连接预览 · 尚未连接到服务器'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-sftp')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sftp-tab')), findsOneWidget);
      expect(find.text('SFTP · gateway-test02'), findsOneWidget);
      expect(find.text('UI 预览 · 尚未连接到服务器'), findsOneWidget);
      expect(find.text('SSH 连接预览 · 尚未连接到服务器'), findsNothing);
      expect(
        find.byKey(const ValueKey('terminal-snippets-tab')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('open-sftp')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sftp-tab')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('terminal-tab')));
      await tester.pumpAndSettle();
      expect(find.text('SSH 连接预览 · 尚未连接到服务器'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sftp-tab')));
      await tester.pumpAndSettle();
      expect(find.text('UI 预览 · 尚未连接到服务器'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('sftp-tab')),
          matching: find.byIcon(material.Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sftp-tab')), findsNothing);
      expect(find.text('SSH 连接预览 · 尚未连接到服务器'), findsOneWidget);
      await tester.tap(find.byIcon(material.Icons.close).first);
      await tester.pumpAndSettle();
      expect(find.text('新建主机'), findsWidgets);
    },
  );

  testWidgets('font sizes are independent and survive navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final fonts = AppFonts();
    addTearDown(fonts.dispose);
    await tester.pumpWidget(XenTermApp(fonts: fonts));
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('界面字体'), findsOneWidget);
    expect(find.text('SSH 界面字体'), findsOneWidget);
    expect(find.text('导入字体（TTF/OTF）'), findsOneWidget);
    await tester.ensureVisible(find.text('SSH 界面字体'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+').last);
    await tester.pumpAndSettle();
    expect(fonts.terminalSize, 16);
    expect(fonts.uiSize, 14);
  });
}
