import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:xenterm_app/screens/terminal/terminal_tools_panel.dart';
import 'package:xenterm_app/theme/app_fonts.dart';
import 'package:xenterm_app/theme/termius_theme.dart';

Widget _app(Widget child) => ShadcnApp(
  theme: ThemeData(colorScheme: termiusDarkScheme()),
  home: Scaffold(child: SizedBox(width: 300, height: 900, child: child)),
);

Map<String, dynamic> _sample() => {
  'cpu_sampled': true,
  'cpu_percent': 0.42,
  'mem_used_kib': 1024 * 1024,
  'mem_total_kib': 2048 * 1024,
  'swap_used_kib': 0,
  'swap_total_kib': 0,
  'user': 'demo',
  'net': [
    {'name': 'eth0', 'rx': 4096, 'tx': 2048},
  ],
  'disks': [
    {'path': '/', 'available': 600000, 'total': 1000000},
  ],
  'gpus': [
    {
      'name': 'Test GPU',
      'util_percent': 35.0,
      'mem_used_mib': 1024,
      'mem_total_mib': 8192,
      'temp_c': 51,
    },
  ],
};

void main() {
  testWidgets('the system panel renders live resource samples', (tester) async {
    await tester.pumpWidget(
      _app(
        TerminalToolsPanel(
          fonts: AppFonts(),
          screen: {
            'resourceState': 'available',
            'resource': _sample(),
          },
          search: '',
          matchCount: 0,
          onSearch: (_) {},
          onClear: () {},
          onCopy: () {},
          onReconnect: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('terminal-resource-cpu')), findsOne);
    expect(find.text('42%'), findsOne);
    expect(find.text('1.0 GiB / 2.0 GiB'), findsOne);
    expect(find.text('40%'), findsOne);
    expect(find.text('35% · 51°C'), findsOne);
    expect(find.textContaining('matching'), findsNothing);
  });

  testWidgets('unsupported and waiting states are stated, not hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TerminalToolsPanel(
          fonts: AppFonts(),
          screen: {'resourceState': 'unsupported', 'resource': null},
          search: '',
          matchCount: 0,
          onSearch: (_) {},
          onClear: () {},
          onCopy: () {},
          onReconnect: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not available on this host'), findsOne);

    await tester.pumpWidget(
      _app(
        TerminalToolsPanel(
          fonts: AppFonts(),
          screen: {'resourceState': 'waiting', 'resource': null},
          search: '',
          matchCount: 0,
          onSearch: (_) {},
          onClear: () {},
          onCopy: () {},
          onReconnect: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Measuring…'), findsOne);
  });
}
