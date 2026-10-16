import 'package:flutter_test/flutter_test.dart';
import 'package:xenterm_app/main.dart';

void main() {
  testWidgets('the shell mounts with the hosts screen showing',
      (tester) async {
    await tester.pumpWidget(const XenTermApp());
    expect(find.text('主机'), findsWidgets);
    // The toolbar's button and the grid's tail card both say it.
    expect(find.text('新建主机'), findsWidgets);
  });
}
