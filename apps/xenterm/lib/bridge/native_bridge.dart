/// The Dart side of the FFI bridge onto the Rust service core
/// (docs/flutter-bridge.md, step 1).
///
/// Strings cross as UTF-8 C pointers owned by the caller; the native side
/// frees them through `xenterm_string_free`. `ConfigStore::load` touches the
/// OS keyring and SQLite, so loading runs on a worker isolate, never on the
/// UI thread.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../data/hosts.dart';

typedef _PtrFnC = Pointer<Utf8> Function();
typedef _PtrFn = Pointer<Utf8> Function();
typedef _FreeFnC = Void Function(Pointer<Utf8>);
typedef _FreeFn = void Function(Pointer<Utf8>);

class NativeBridgeError implements Exception {
  final String message;
  const NativeBridgeError(this.message);

  @override
  String toString() => message;
}

/// Owns the loaded library and the three step-1 entry points.
class NativeBridge {
  final DynamicLibrary _lib;

  NativeBridge._(this._lib);

  static NativeBridge? _instance;
  static bool _attempted = false;

  /// Loads the bridge library next to the executable (or from
  /// `XENTERM_BRIDGE_PATH`). Returns null when it is not present so the UI can
  /// show a clear error instead of crashing at startup.
  static NativeBridge? tryLoad() {
    if (_attempted) return _instance;
    _attempted = true;
    try {
      final override = Platform.environment['XENTERM_BRIDGE_PATH'];
      final lib = override != null && override.isNotEmpty
          ? DynamicLibrary.open(override)
          : DynamicLibrary.open(_defaultName());
      _instance = NativeBridge._(lib);
    } catch (_) {
      _instance = null;
    }
    return _instance;
  }

  static String _defaultName() {
    if (Platform.isWindows) return 'xenterm_bridge.dll';
    if (Platform.isMacOS) return 'libxenterm_bridge.dylib';
    return 'libxenterm_bridge.so';
  }

  late final _PtrFn _version =
      _lib.lookupFunction<_PtrFnC, _PtrFn>('xenterm_core_version');
  late final _PtrFn _sessions =
      _lib.lookupFunction<_PtrFnC, _PtrFn>('xenterm_sessions_json');
  late final _FreeFn _free =
      _lib.lookupFunction<_FreeFnC, _FreeFn>('xenterm_string_free');

  String _take(Pointer<Utf8> pointer) {
    try {
      return pointer.toDartString();
    } finally {
      _free(pointer);
    }
  }

  /// The core's version string (版本号规范 v1: `xt-…`).
  String version() => _take(_version());

  /// The saved sessions as JSON, or null when the core failed to load the
  /// store (the caller surfaces an error).
  String? sessionsJson() {
    final pointer = _sessions();
    if (pointer == nullptr) return null;
    return _take(pointer);
  }
}

/// Loads the saved sessions from the core off the UI thread and maps them to
/// the hosts-screen model. Throws [NativeBridgeError] with a user-facing
/// message when the bridge or the store is unavailable.
Future<List<Host>> loadHostsFromCore() {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final raw = bridge.sessionsJson();
    if (raw == null) {
      throw const NativeBridgeError(
        'The core could not load the session store',
      );
    }
    final rows = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return rows.map(Host.fromCoreJson).toList();
  });
}

/// Synchronous variant for diagnostics (e.g. the core version line).
String? coreVersionSync() => NativeBridge.tryLoad()?.version();
