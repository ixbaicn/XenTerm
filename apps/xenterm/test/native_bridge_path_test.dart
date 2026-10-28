import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xenterm_app/bridge/native_bridge.dart';

void main() {
  final sep = Platform.pathSeparator;

  String tempPath(List<String> parts) =>
      [Directory.systemTemp.path, ...parts].join(sep);

  test('bridge library is resolved alongside the executable, not the cwd', () {
    final executable = tempPath(['XenTerm build', 'bundle', 'xenterm_app']);
    final expected = tempPath(['XenTerm build', 'bundle', 'libxenterm_bridge.so']);

    expect(
      NativeBridge.libraryPathForExecutable(executable, 'libxenterm_bridge.so'),
      expected,
    );
    expect(expected, isNot('libxenterm_bridge.so'));
  });

  test('macOS looks in Contents/Frameworks before Contents/MacOS', () {
    final executable = tempPath([
      'XenTerm.app',
      'Contents',
      'MacOS',
      'xenterm_app',
    ]);
    final paths = NativeBridge.librarySearchPaths(
      executable,
      'libxenterm_bridge.dylib',
      isMacOS: true,
      isLinux: false,
    );

    expect(paths, [
      tempPath([
        'XenTerm.app',
        'Contents',
        'Frameworks',
        'libxenterm_bridge.dylib',
      ]),
      tempPath(['XenTerm.app', 'Contents', 'MacOS', 'libxenterm_bridge.dylib']),
    ]);
  });

  test('Linux looks next to the executable and in the bundle lib directory', () {
    final executable = tempPath(['bundle', 'xenterm']);
    final paths = NativeBridge.librarySearchPaths(
      executable,
      'libxenterm_bridge.so',
      isMacOS: false,
      isLinux: true,
    );

    expect(paths, [
      tempPath(['bundle', 'libxenterm_bridge.so']),
      tempPath(['bundle', 'lib', 'libxenterm_bridge.so']),
    ]);
  });

  test('Windows only looks next to the executable', () {
    final executable = tempPath(['release', 'xenterm.exe']);
    final paths = NativeBridge.librarySearchPaths(
      executable,
      'xenterm_bridge.dll',
      isMacOS: false,
      isLinux: false,
    );

    expect(paths, [tempPath(['release', 'xenterm_bridge.dll'])]);
  });
}
