import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenterm_app/main.dart';

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
    await tester.tap(find.byIcon(BootstrapIcons.x).first);
    await tester.pumpAndSettle();
    expect(find.text('新建主机'), findsWidgets);
  });
}
