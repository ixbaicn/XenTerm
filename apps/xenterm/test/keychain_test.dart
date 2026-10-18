import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:xenterm_app/bridge/native_bridge.dart';
import 'package:xenterm_app/screens/keychain/keychain_screen.dart';
import 'package:xenterm_app/theme/termius_theme.dart';

Widget _app(Widget child) => ShadcnApp(
  theme: ThemeData(colorScheme: termiusDarkScheme()),
  home: Scaffold(child: SizedBox(width: 1100, height: 760, child: child)),
);

void main() {
  testWidgets('keychain lists only metadata and its real state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        KeychainScreen(
          loadKeys: () async => const [
            KeyInfo(
              sessionId: 'h1',
              sessionName: 'gateway',
              host: '10.0.0.2',
              user: 'root',
              source: 'file',
              path: 'id_ed25519',
              keyType: 'ssh-ed25519',
              fingerprint: 'SHA256:abc',
              status: 'available',
            ),
            KeyInfo(
              sessionId: 'h2',
              sessionName: 'locked-host',
              host: '10.0.0.3',
              user: 'root',
              source: 'inline',
              path: '',
              keyType: '',
              fingerprint: '',
              status: 'locked',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('id_ed25519'), findsOneWidget);
    expect(find.text('ED25519'), findsOneWidget);
    expect(find.textContaining('SHA256:abc'), findsOneWidget);
    expect(find.text('Pasted key'), findsOneWidget);
    expect(find.textContaining('Encrypted key'), findsOneWidget);
  });

  testWidgets('the empty keychain explains how keys appear', (tester) async {
    await tester.pumpWidget(
      _app(KeychainScreen(loadKeys: () async => const [])),
    );
    await tester.pumpAndSettle();
    expect(find.text('No SSH keys yet'), findsOneWidget);
  });
}
