import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:xenterm_app/bridge/native_bridge.dart';
import 'package:xenterm_app/data/hosts.dart';
import 'package:xenterm_app/screens/hosts/host_card.dart';
import 'package:xenterm_app/screens/hosts/hosts_screen.dart';
import 'package:xenterm_app/theme/termius_field.dart';
import 'package:xenterm_app/theme/termius_theme.dart';

Widget _app(Widget child) => ShadcnApp(
  theme: ThemeData(colorScheme: termiusDarkScheme()),
  home: Scaffold(child: SizedBox(width: 1400, height: 900, child: child)),
);

void main() {
  testWidgets('quick connect parses user@host:port and opens the new session', (
    tester,
  ) async {
    var hosts = <Host>[];
    Map<String, Object?>? saved;
    Host? connected;
    await tester.pumpWidget(
      _app(
        HostsScreen(
          loadHosts: () async => hosts,
          onConnect: (host) => connected = host,
          saveSession:
              ({
                required id,
                required label,
                required address,
                required port,
                required username,
                required group,
                required kind,
                keyPath = '',
                int? baudRate,
                int? dataBits,
                int? stopBits,
                String? parity,
                String? flowControl,
                String? password,
                bool? clearPassword,
                String? jumpHostId,
                List<Map<String, dynamic>>? triggers,
              }) async {
                saved = {
                  'label': label,
                  'address': address,
                  'port': port,
                  'username': username,
                  'kind': kind,
                };
                hosts = [
                  Host(
                    id: 'new1',
                    label: label,
                    address: address,
                    port: port,
                    username: username,
                    group: group,
                    protocol: kind,
                  ),
                ];
                return const CoreWriteResult(ok: true, id: 'new1');
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('host-search')),
      'root@10.0.0.9:2222',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-connect')));
    await tester.pumpAndSettle();
    expect(saved?['label'], 'root@10.0.0.9:2222');
    expect(saved?['address'], '10.0.0.9');
    expect(saved?['port'], 2222);
    expect(saved?['username'], 'root');
    expect(saved?['kind'], 'ssh');
    expect(connected?.id, 'new1');
  });

  testWidgets('the title-bar request opens the New host drawer', (
    tester,
  ) async {
    final request = ValueNotifier<int>(0);
    addTearDown(request.dispose);
    var hosts = <Host>[];
    String? savedLabel;
    await tester.pumpWidget(
      _app(
        HostsScreen(
          loadHosts: () async => hosts,
          newHostRequest: request,
          saveSession:
              ({
                required id,
                required label,
                required address,
                required port,
                required username,
                required group,
                required kind,
                keyPath = '',
                int? baudRate,
                int? dataBits,
                int? stopBits,
                String? parity,
                String? flowControl,
                String? password,
                bool? clearPassword,
                String? jumpHostId,
                List<Map<String, dynamic>>? triggers,
              }) async {
                savedLabel = label;
                hosts = [
                  Host(
                    id: 'new2',
                    label: label,
                    address: address,
                    port: port,
                    username: username,
                    group: group,
                    protocol: kind,
                  ),
                ];
                return const CoreWriteResult(ok: true, id: 'new2');
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    request.value++;
    await tester.pumpAndSettle();
    expect(savedLabel, 'New Host');
    expect(find.text('Host Details'), findsOneWidget);
  });

  testWidgets('the Serial action opens the serial drawer and connects', (
    tester,
  ) async {
    var hosts = <Host>[];
    Host? connected;
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      _app(
        HostsScreen(
          loadHosts: () async => hosts,
          loadSerialPorts: () async => const [
            SerialPortInfo(name: 'COM3', kind: 'USB'),
          ],
          onConnect: (host) => connected = host,
          saveSession:
              ({
                required id,
                required label,
                required address,
                required port,
                required username,
                required group,
                required kind,
                keyPath = '',
                int? baudRate,
                int? dataBits,
                int? stopBits,
                String? parity,
                String? flowControl,
                String? password,
                bool? clearPassword,
                String? jumpHostId,
                List<Map<String, dynamic>>? triggers,
              }) async {
                saved = {
                  'label': label,
                  'address': address,
                  'kind': kind,
                  'baud': baudRate,
                  'parity': parity,
                  'password': password,
                };
                hosts = [
                  Host(
                    id: 'serial1',
                    label: label,
                    address: address,
                    port: port,
                    username: username,
                    group: group,
                    protocol: kind,
                    baudRate: baudRate ?? 115200,
                    dataBits: dataBits ?? 8,
                    stopBits: stopBits ?? 1,
                    parity: parity ?? 'none',
                    flowControl: flowControl ?? 'none',
                  ),
                ];
                return const CoreWriteResult(ok: true, id: 'serial1');
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Serial'));
    await tester.pumpAndSettle();
    expect(find.text('Serial Connection'), findsOne);
    expect(
      tester
          .widget<TermiusField>(find.byKey(const ValueKey('serial-port')))
          .controller
          ?.text,
      'COM3',
    );

    await tester.tap(find.byKey(const ValueKey('serial-connect')));
    await tester.pumpAndSettle();

    // The toolbar entry is a temporary tab: nothing is written to Home.
    expect(saved, isNull);
    expect(connected?.ephemeral, isTrue);
    expect(connected?.protocol, 'serial');
    expect(connected?.address, 'COM3');
    expect(connected?.baudRate, 115200);
  });

  testWidgets('cards keep a readable width when the window is narrow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadcnApp(
        theme: ThemeData(colorScheme: termiusDarkScheme()),
        home: Scaffold(
          child: SizedBox(
            width: 700,
            height: 600,
            child: HostsScreen(
              loadHosts: () async => const [
                Host(id: 'a', label: 'alpha', address: '10.0.0.1'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(HostCard).first);
    expect(size.width, greaterThanOrEqualTo(290));
  });

  testWidgets('the Terminal action opens a real local session', (tester) async {
    var hosts = <Host>[];
    Host? connected;
    await tester.pumpWidget(
      _app(
        HostsScreen(
          loadHosts: () async => hosts,
          onConnect: (host) => connected = host,
          saveSession:
              ({
                required id,
                required label,
                required address,
                required port,
                required username,
                required group,
                required kind,
                keyPath = '',
                int? baudRate,
                int? dataBits,
                int? stopBits,
                String? parity,
                String? flowControl,
                String? password,
                bool? clearPassword,
                String? jumpHostId,
                List<Map<String, dynamic>>? triggers,
              }) async {
                hosts = [
                  Host(
                    id: 'local1',
                    label: label,
                    address: address,
                    port: port,
                    username: username,
                    group: group,
                    protocol: kind,
                  ),
                ];
                return const CoreWriteResult(ok: true, id: 'local1');
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminal'));
    await tester.pumpAndSettle();
    expect(connected?.protocol, 'local');
    expect(connected?.label, 'Local terminal');
  });
  testWidgets('the host drawer edits expect/send triggers', (tester) async {
    final host = Host(
      id: 't1',
      label: 'triggered-host',
      address: '10.0.0.9',
      protocol: 'ssh',
      triggers: const [
        SessionTriggerRule(expect: 'login:', hasResponse: true),
      ],
    );
    var hosts = <Host>[host];
    List<Map<String, dynamic>>? savedTriggers;
    await tester.pumpWidget(
      _app(
        HostsScreen(
          loadHosts: () async => hosts,
          saveSession:
              ({
                required id,
                required label,
                required address,
                required port,
                required username,
                required group,
                required kind,
                keyPath = '',
                int? baudRate,
                int? dataBits,
                int? stopBits,
                String? parity,
                String? flowControl,
                String? password,
                bool? clearPassword,
                String? jumpHostId,
                List<Map<String, dynamic>>? triggers,
              }) async {
                savedTriggers = triggers;
                hosts = [
                  Host(
                    id: id.isEmpty ? 't1' : id,
                    label: label,
                    address: address,
                    port: port,
                    username: username,
                    group: group,
                    protocol: kind,
                    triggers: const [
                      SessionTriggerRule(expect: 'login:', hasResponse: true),
                    ],
                  ),
                ];
                return const CoreWriteResult(ok: true, id: 't1');
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The hover pencil opens the details drawer.
    await tester.tap(find.byKey(const ValueKey('edit-t1')));
    await tester.pumpAndSettle();
    expect(find.text('Host Details'), findsOneWidget);

    // The stored rule shows its expect text and keeps the secret masked.
    await tester.ensureVisible(find.byKey(const ValueKey('host-trigger-add')));
    expect(find.text('login:'), findsOneWidget);
    expect(find.text('Saved — leave blank to keep'), findsOneWidget);

    // Add a second rule: wait for the password prompt, answer it.
    await tester.tap(find.byKey(const ValueKey('host-trigger-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trigger-expect')).last,
      'Password:',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trigger-response')).last,
      's3cret-response',
    );
    await tester.pumpAndSettle();

    // Persist through the header check.
    await tester.ensureVisible(find.byIcon(LucideIcons.check));
    await tester.tap(find.byIcon(LucideIcons.check));
    await tester.pumpAndSettle();

    final rules = savedTriggers;
    expect(rules, isNotNull);
    expect(rules!.length, 2);
    // The stored secret is kept (blank response in the payload).
    expect(rules[0]['expect'], 'login:');
    expect(rules[0]['response'], '');
    // The new rule carries the typed response and the default flags.
    expect(rules[1]['expect'], 'Password:');
    expect(rules[1]['response'], 's3cret-response');
    expect(rules[1]['append_enter'], true);
    expect(rules[1]['repeat'], false);
  });
}

