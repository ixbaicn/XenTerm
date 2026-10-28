// macOS release smoke test: proves the packaged dylib can be opened by the
// dynamic loader and that the C ABI version export works. CI sets
// XENTERM_BRIDGE_PATH to the dylib inside the freshly built app bundle; every
// other environment skips the test so it stays harmless locally.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xenterm_app/bridge/native_bridge.dart';

void main() {
  final path = Platform.environment['XENTERM_BRIDGE_PATH'];

  test(
    'the packaged macOS bridge loads and returns its version',
    () {
      final bridge = NativeBridge.tryLoad();
      expect(bridge, isNotNull, reason: NativeBridge.loadError);
      expect(bridge!.version(), isNotEmpty);
    },
    skip: Platform.isMacOS && path != null && path.isNotEmpty
        ? false
        : 'only runs on macOS CI with XENTERM_BRIDGE_PATH set',
  );
}
