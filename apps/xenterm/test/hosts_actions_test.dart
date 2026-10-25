import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:xenterm_app/bridge/native_bridge.dart';
import 'package:xenterm_app/data/hosts.dart';
import 'package:xenterm_app/screens/hosts/host_card.dart';
import 'package:xenterm_app/screens/hosts/host_details_panel.dart';
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
                keyInline = '',
                bool? clearKey,
                String? encoding,
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
    var saveCalls = 0;
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
                keyInline = '',
                bool? clearKey,
                String? encoding,
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
                saveCalls++;
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
    // The drawer opens on an unsaved draft: nothing hit the store yet (no
    // empty "New Host" shell), and the connection type is still choosable.
    expect(saveCalls, 0);
    expect(find.text('Host Details'), findsOneWidget);
    expect(find.byKey(const ValueKey('host-kind')), findsOneWidget);
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
                keyInline = '',
                bool? clearKey,
                String? encoding,
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
                keyInline = '',
                bool? clearKey,
                String? encoding,
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
                keyInline = '',
                bool? clearKey,
                String? encoding,
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


  testWidgets('a new host draft blocks empty and duplicate saves', (
    tester,
  ) async {
    final alpha = Host(id: 'a', label: 'alpha', address: '10.0.0.1');
    var hosts = <Host>[alpha];
    final request = ValueNotifier<int>(0);
    addTearDown(request.dispose);
    var saveCalls = 0;
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
                keyInline = '',
                bool? clearKey,
                String? encoding,
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
                saveCalls++;
                savedLabel = label;
                hosts = [
                  alpha,
                  Host(id: 'new9', label: label, address: address),
                ];
                return const CoreWriteResult(ok: true, id: 'new9');
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    request.value++;
    await tester.pumpAndSettle();

    // Empty draft: the address is required — no store write.
    await tester.ensureVisible(find.byIcon(LucideIcons.check));
    await tester.tap(find.byIcon(LucideIcons.check));
    await tester.pumpAndSettle();
    expect(saveCalls, 0);
    expect(find.text('The address is required.'), findsOneWidget);

    // Valid fields but a name another host already uses.
    await tester.enterText(
      find.byKey(const ValueKey('host-address')),
      '10.0.0.5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-username')),
      'root',
    );
    await tester.enterText(find.byKey(const ValueKey('label-field')), 'alpha');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(LucideIcons.check));
    await tester.tap(find.byIcon(LucideIcons.check));
    await tester.pumpAndSettle();
    expect(saveCalls, 0);
    expect(
      find.text('A host named "alpha" already exists — pick a different name.'),
      findsOneWidget,
    );

    // A distinct name saves and the create drawer closes.
    await tester.enterText(find.byKey(const ValueKey('label-field')), 'beta');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(LucideIcons.check));
    await tester.tap(find.byIcon(LucideIcons.check));
    await tester.pumpAndSettle();
    expect(saveCalls, 1);
    expect(savedLabel, 'beta');
    // The drawer slid shut (its content stays mounted at width 0, so look
    // through it): the saved host now shows as a card on Home.
    expect(find.text('beta'), findsWidgets);
  });

  testWidgets('the host panel auth switch stores a pasted key inline', (
    tester,
  ) async {
    // Pumped flat (not inside HostsScreen): overlay dropdowns hit-test
    // reliably in a shallow tree; the surrounding flow is covered by the
    // other tests.
    String? savedKeyInline;
    String? savedPassword;
    await tester.pumpWidget(
      _app(
        HostDetailsPanel(
          host: Host(id: '', label: '', address: '', ephemeral: true),
          hosts: const [],
          onClose: () {},
          onConnect: () {},
          onSwitchToSerial: () {},
          onKindChanged: (_) {},
          onDelete: (_) async => null,
          onSave: (host, password, clearPassword, keyInline, clearKey) async {
            savedPassword = password;
            savedKeyInline = keyInline;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A creating draft offers the connection type.
    expect(find.byKey(const ValueKey('host-kind')), findsOneWidget);

    // Password is the default auth; the typed secret rides the payload.
    await tester.enterText(
      find.byKey(const ValueKey('host-address')),
      '10.0.0.7',
    );
    expect(find.byKey(const ValueKey('host-password')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('host-password')),
      'pw-typed',
    );
    await tester.ensureVisible(find.byIcon(LucideIcons.check));
    await tester.tap(find.byIcon(LucideIcons.check));
    await tester.pumpAndSettle();
    expect(savedPassword, 'pw-typed');

    // Switch to key auth: the import button + paste area replace the path
    // field, and the pasted material crosses as inline key content.
    await tester.ensureVisible(find.byKey(const ValueKey('host-auth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('host-auth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private key').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('host-key-import')), findsOneWidget);
    expect(find.byKey(const ValueKey('host-key-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('host-password')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('host-key-content')),
      '-----BEGIN OPENSSH PRIVATE KEY-----abcEND OF TEST KEY-----',
    );
    await tester.ensureVisible(find.byIcon(LucideIcons.check));
    await tester.tap(find.byIcon(LucideIcons.check));
    await tester.pumpAndSettle();
    expect(savedKeyInline, contains('BEGIN OPENSSH PRIVATE KEY'));
    // Key auth does not resend the password.
    expect(savedPassword ?? '', isEmpty);
  });
  testWidgets('the New host draft switches to serial and saves the session', (
    tester,
  ) async {
    var hosts = <Host>[];
    final request = ValueNotifier<int>(0);
    addTearDown(request.dispose);
    Map<String, Object?>? saved;
    var connected = false;
    await tester.pumpWidget(
      _app(
        HostsScreen(
          loadHosts: () async => hosts,
          loadSerialPorts: () async => const [
            SerialPortInfo(name: 'COM3', kind: 'USB'),
          ],
          newHostRequest: request,
          onConnect: (_) => connected = true,
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
                keyInline = '',
                bool? clearKey,
                String? encoding,
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
                };
                hosts = [
                  Host(
                    id: 's9',
                    label: label,
                    address: address,
                    protocol: kind,
                    baudRate: baudRate ?? 115200,
                  ),
                ];
                return const CoreWriteResult(ok: true, id: 's9');
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    request.value++;
    await tester.pumpAndSettle();

    // Connection type: SSH → Serial hands the draft to the serial editor.
    await tester.ensureVisible(find.byKey(const ValueKey('host-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('host-kind')));
    await tester.pumpAndSettle();
    // The overlay option list hangs off the anchor; in the test's layer tree
    // the follower link is not hit-testable, so tap by computed position:
    // first option sits just below the anchor's bottom edge.
    final anchor = tester.getRect(find.byKey(const ValueKey('host-kind')));
    // Third option row ('Serial' — SSH then Telnet come first): the list
    // hangs bottomLeft+6 with 5px padding and ~32px rows.
    await tester.tapAt(
      Offset(
        anchor.left + anchor.width / 2,
        anchor.bottom + 6 + 5 + 32 * 2 + 16,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Serial Connection'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('serial-label')),
      'console',
    );
    await tester.enterText(find.byKey(const ValueKey('serial-port')), 'COM3');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('serial-connect')));
    await tester.pumpAndSettle();

    // Saved as a serial host (not opened as a temporary tab).
    expect(saved!['kind'], 'serial');
    expect(saved!['address'], 'COM3');
    expect(saved!['label'], 'console');
    expect(connected, isFalse);
    expect(find.text('Serial Connection'), findsNothing);
  });

  testWidgets('telnet drafts drop credentials; encoding dropdown persists', (
    tester,
  ) async {
    // Flat panel: overlay dropdowns hit-test reliably in a shallow tree.
    String? savedEncoding;
    String? savedKind;
    var draft = Host(id: '', label: '', address: '', ephemeral: true);
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => HostDetailsPanel(
            host: draft,
            hosts: const [],
            onClose: () {},
            onConnect: () {},
            onSwitchToSerial: () {},
            onKindChanged: (kind) => setState(() {
              savedKind = kind;
              draft = Host(
                id: draft.id,
                label: draft.label,
                address: draft.address,
                username: draft.username,
                protocol: kind,
                ephemeral: true,
              );
            }),
            onDelete: (_) async => null,
            onSave: (host, password, clearPassword, keyInline, clearKey) async {
              savedEncoding = host.encoding;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The type selector offers Telnet; picking it flips the draft in place.
    expect(find.byKey(const ValueKey('host-username')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('host-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Telnet').last);
    await tester.pumpAndSettle();
    expect(savedKind, 'telnet');
    expect(find.text('Telnet on'), findsOneWidget);

    // Telnet has no credentials: the username and auth dropdowns are gone.
    expect(find.byKey(const ValueKey('host-username')), findsNothing);
    expect(find.byKey(const ValueKey('host-auth')), findsNothing);
    expect(find.byKey(const ValueKey('host-encoding')), findsOneWidget);

    // The encoding dropdown exists with the CJK charsets and rides the save.
    await tester.ensureVisible(find.byKey(const ValueKey('host-encoding')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('host-encoding')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GBK / 简体中文').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('host-address')),
      '10.0.0.9',
    );
    await tester.ensureVisible(find.byIcon(LucideIcons.check));
    await tester.tap(find.byIcon(LucideIcons.check));
    await tester.pumpAndSettle();
    expect(savedEncoding, 'gbk');
  });

}
