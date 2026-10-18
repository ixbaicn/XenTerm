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
}
