import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xenterm_app/bridge/native_bridge.dart';

void main() {
  test('bridge library is resolved alongside the executable, not the cwd', () {
    final executable = File.fromUri(
      Directory.systemTemp.uri.resolve('XenTerm%20build/bundle/xenterm_app'),
    ).path;
    final expected =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'XenTerm build${Platform.pathSeparator}bundle${Platform.pathSeparator}'
        'libxenterm_bridge.so';

    expect(
      NativeBridge.libraryPathForExecutable(executable, 'libxenterm_bridge.so'),
      expected,
    );
    expect(expected, isNot('libxenterm_bridge.so'));
  });
}
