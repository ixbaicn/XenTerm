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
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../data/hosts.dart';

typedef _PtrFnC = Pointer<Utf8> Function();
typedef _PtrFn = Pointer<Utf8> Function();
typedef _FreeFnC = Void Function(Pointer<Utf8>);
typedef _FreeFn = void Function(Pointer<Utf8>);
typedef _StrFnC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _StrFn = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _StartC = Pointer<Utf8> Function(Pointer<Utf8>, Uint32, Uint32);
typedef _Start = Pointer<Utf8> Function(Pointer<Utf8>, int, int);
typedef _VersionC = Uint64 Function(Uint64);
typedef _Version = int Function(int);
typedef _SnapC = Pointer<Utf8> Function(Uint64);
typedef _Snap = Pointer<Utf8> Function(int);
typedef _InputC = Int32 Function(Uint64, Pointer<Uint8>, UintPtr);
typedef _Input = int Function(int, Pointer<Uint8>, int);
typedef _ResizeC = Int32 Function(Uint64, Uint32, Uint32);
typedef _Resize = int Function(int, int, int);
typedef _CloseC = Int32 Function(Uint64);
typedef _Close = int Function(int);
typedef _IndexDeleteC = Pointer<Utf8> Function(Int64);
typedef _IndexDelete = Pointer<Utf8> Function(int);
typedef _AnswerC = Int32 Function(
  Uint64,
  Uint64,
  Int32,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
);
typedef _Answer = int Function(
  int,
  int,
  int,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
);

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

  late final _PtrFn _version = _lib.lookupFunction<_PtrFnC, _PtrFn>(
    'xenterm_core_version',
  );
  late final _PtrFn _sessions = _lib.lookupFunction<_PtrFnC, _PtrFn>(
    'xenterm_sessions_json',
  );
  late final _FreeFn _free = _lib.lookupFunction<_FreeFnC, _FreeFn>(
    'xenterm_string_free',
  );
  late final _StrFn _upsert = _lib.lookupFunction<_StrFnC, _StrFn>(
    'xenterm_session_upsert',
  );
  late final _StrFn _delete = _lib.lookupFunction<_StrFnC, _StrFn>(
    'xenterm_session_delete',
  );
  late final _Start _start = _lib.lookupFunction<_StartC, _Start>(
    'xenterm_session_start',
  );
  late final _Version _terminalVersion = _lib
      .lookupFunction<_VersionC, _Version>('xenterm_session_version');
  late final _Snap _snapshot = _lib.lookupFunction<_SnapC, _Snap>(
    'xenterm_session_snapshot',
  );
  late final _Input _input = _lib.lookupFunction<_InputC, _Input>(
    'xenterm_session_input',
  );
  late final _Resize _resize = _lib.lookupFunction<_ResizeC, _Resize>(
    'xenterm_session_resize',
  );
  late final _Close _close = _lib.lookupFunction<_CloseC, _Close>(
    'xenterm_session_close',
  );
  late final _Answer _answer = _lib.lookupFunction<_AnswerC, _Answer>(
    'xenterm_session_answer_prompt',
  );
  late final _PtrFn _quickCommands = _lib.lookupFunction<_PtrFnC, _PtrFn>(
    'xenterm_quick_commands_json',
  );
  late final _StrFn _quickUpsert = _lib.lookupFunction<_StrFnC, _StrFn>(
    'xenterm_quick_command_upsert',
  );
  late final _PtrFn _knownHosts = _lib.lookupFunction<_PtrFnC, _PtrFn>(
    'xenterm_known_hosts_json',
  );
  late final _StrFn _knownHostDelete = _lib.lookupFunction<_StrFnC, _StrFn>(
    'xenterm_known_host_delete',
  );
  late final _PtrFn _forwards = _lib.lookupFunction<_PtrFnC, _PtrFn>(
    'xenterm_forwards_json',
  );
  late final _StrFn _forwardUpsert = _lib.lookupFunction<_StrFnC, _StrFn>(
    'xenterm_forward_upsert',
  );
  late final _StrFn _forwardDelete = _lib.lookupFunction<_StrFnC, _StrFn>(
    'xenterm_forward_delete',
  );
  late final _PtrFn _keys = _lib.lookupFunction<_PtrFnC, _PtrFn>(
    'xenterm_keys_json',
  );
  late final _IndexDelete _quickDelete = _lib
      .lookupFunction<_IndexDeleteC, _IndexDelete>(
        'xenterm_quick_command_delete',
      );

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

  /// Calls one string-in/string-out core entry point and releases the request.
  String _callWith(_StrFn fn, String payload) {
    final pointer = payload.toNativeUtf8();
    try {
      return _take(fn(pointer));
    } finally {
      malloc.free(pointer);
    }
  }

  Map<String, dynamic> upsertSession(Map<String, dynamic> payload) =>
      jsonDecode(_callWith(_upsert, jsonEncode(payload)))
          as Map<String, dynamic>;

  Map<String, dynamic> deleteSession(String id) =>
      jsonDecode(_callWith(_delete, id)) as Map<String, dynamic>;

  // ── Terminal sessions ──────────────────────────────────────────────────

  /// Starts a saved session; returns its bridge handle or throws.
  int startSession(String id, int cols, int rows) {
    final pointer = id.toNativeUtf8();
    try {
      final raw = _take(_start(pointer, cols, rows));
      final result = jsonDecode(raw) as Map<String, dynamic>;
      if (result['ok'] != true) {
        throw NativeBridgeError(
          (result['error'] as String?) ?? 'Could not start the session',
        );
      }
      return (result['handle'] as num).toInt();
    } finally {
      malloc.free(pointer);
    }
  }

  int sessionVersion(int handle) => _terminalVersion(handle);

  String? sessionSnapshot(int handle) {
    final pointer = _snapshot(handle);
    if (pointer == nullptr) return null;
    return _take(pointer);
  }

  bool sendInput(int handle, Uint8List bytes) {
    if (bytes.isEmpty) return true;
    final pointer = malloc.allocate<Uint8>(bytes.length);
    try {
      pointer.asTypedList(bytes.length).setAll(0, bytes);
      return _input(handle, pointer, bytes.length) == 1;
    } finally {
      malloc.free(pointer);
    }
  }

  bool resizeSession(int handle, int cols, int rows) =>
      _resize(handle, cols, rows) == 1;

  bool closeSession(int handle) => _close(handle) == 1;

  // ── SSH keys ──────────────────────────────────────────────────────────

  String? keysJson() {
    final pointer = _keys();
    if (pointer == nullptr) return null;
    return _take(pointer);
  }

  // ── Port forwarding ───────────────────────────────────────────────────

  String? forwardsJson() {
    final pointer = _forwards();
    if (pointer == nullptr) return null;
    return _take(pointer);
  }

  Map<String, dynamic> upsertForward(Map<String, dynamic> payload) =>
      jsonDecode(_callWith(_forwardUpsert, jsonEncode(payload)))
          as Map<String, dynamic>;

  Map<String, dynamic> deleteForward(Map<String, dynamic> payload) =>
      jsonDecode(_callWith(_forwardDelete, jsonEncode(payload)))
          as Map<String, dynamic>;

  // ── Known hosts ───────────────────────────────────────────────────────

  String? knownHostsJson() {
    final pointer = _knownHosts();
    if (pointer == nullptr) return null;
    return _take(pointer);
  }

  Map<String, dynamic> deleteKnownHost(String id) =>
      jsonDecode(_callWith(_knownHostDelete, id)) as Map<String, dynamic>;

  // ── Snippets (quick commands) ──────────────────────────────────────────

  String? quickCommandsJson() {
    final pointer = _quickCommands();
    if (pointer == nullptr) return null;
    return _take(pointer);
  }

  Map<String, dynamic> upsertQuickCommand(Map<String, dynamic> payload) =>
      jsonDecode(_callWith(_quickUpsert, jsonEncode(payload)))
          as Map<String, dynamic>;

  Map<String, dynamic> deleteQuickCommand(int index) =>
      jsonDecode(_take(_quickDelete(index))) as Map<String, dynamic>;

  /// Answers the current prompt: host-key uses [accept], credentials use
  /// [username]/[password], MFA uses [text].
  bool answerPrompt(
    int handle,
    int promptId, {
    required bool accept,
    String? username,
    String? password,
    String? text,
  }) {
    final userPtr = username?.toNativeUtf8() ?? nullptr;
    final passPtr = password?.toNativeUtf8() ?? nullptr;
    final textPtr = text?.toNativeUtf8() ?? nullptr;
    try {
      return _answer(
            handle,
            promptId,
            accept ? 1 : 0,
            userPtr,
            passPtr,
            textPtr,
          ) ==
          1;
    } finally {
      if (userPtr != nullptr) malloc.free(userPtr);
      if (passPtr != nullptr) malloc.free(passPtr);
      if (textPtr != nullptr) malloc.free(textPtr);
    }
  }
}

/// Result of a core write: `ok`, the affected session id, or the error text.
class CoreWriteResult {
  final bool ok;
  final String? id;
  final String? error;

  const CoreWriteResult({required this.ok, this.id, this.error});
}

/// One saved quick command (Snippets screen).
class QuickCommand {
  final int index;
  final String name;
  final String command;
  final String group;
  final bool sendEnter;

  const QuickCommand({
    required this.index,
    required this.name,
    required this.command,
    this.group = '',
    this.sendEnter = true,
  });

  factory QuickCommand.fromCoreJson(Map<String, dynamic> json) => QuickCommand(
    index: (json['index'] as num?)?.toInt() ?? -1,
    name: (json['name'] as String?) ?? '',
    command: (json['command'] as String?) ?? '',
    group: (json['group'] as String?) ?? '',
    sendEnter: json['send_enter'] as bool? ?? true,
  );
}

/// Reads the saved quick commands from the core off the UI thread.
Future<List<QuickCommand>> loadQuickCommandsFromCore() {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final raw = bridge.quickCommandsJson();
    if (raw == null) {
      throw const NativeBridgeError(
        'The core could not load the quick commands',
      );
    }
    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(QuickCommand.fromCoreJson)
        .toList();
  });
}

/// Creates ([index] < 0) or updates one quick command in the core.
Future<CoreWriteResult> saveQuickCommandToCore({
  required int index,
  required String name,
  required String command,
  required String group,
  required bool sendEnter,
}) {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final result = bridge.upsertQuickCommand({
      'index': index,
      'name': name,
      'command': command,
      'group': group,
      'send_enter': sendEnter,
    });
    if (result['ok'] != true) {
      return CoreWriteResult(
        ok: false,
        error: (result['error'] as String?) ?? 'Could not save the snippet',
      );
    }
    return CoreWriteResult(
      ok: true,
      id: (result['index'] as num?)?.toInt().toString(),
    );
  });
}

/// Deletes one quick command by its current index.
Future<CoreWriteResult> deleteQuickCommandFromCore(int index) {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final result = bridge.deleteQuickCommand(index);
    if (result['ok'] != true) {
      return CoreWriteResult(
        ok: false,
        error: (result['error'] as String?) ?? 'Could not delete the snippet',
      );
    }
    return const CoreWriteResult(ok: true);
  });
}

/// One SSH key credential referenced by a saved session. Key material never
/// crosses the bridge — only its path, algorithm, fingerprint and usage.
class KeyInfo {
  final String sessionId;
  final String sessionName;
  final String host;
  final String user;
  final String source; // file | inline
  final String path; // file name only
  final String keyType;
  final String fingerprint;
  final String status; // available | locked | missing

  const KeyInfo({
    required this.sessionId,
    required this.sessionName,
    required this.host,
    required this.user,
    required this.source,
    required this.path,
    required this.keyType,
    required this.fingerprint,
    required this.status,
  });

  factory KeyInfo.fromCoreJson(Map<String, dynamic> json) => KeyInfo(
    sessionId: (json['session_id'] as String?) ?? '',
    sessionName: (json['session_name'] as String?) ?? '',
    host: (json['host'] as String?) ?? '',
    user: (json['user'] as String?) ?? '',
    source: (json['source'] as String?) ?? 'file',
    path: (json['path'] as String?) ?? '',
    keyType: (json['key_type'] as String?) ?? '',
    fingerprint: (json['fingerprint'] as String?) ?? '',
    status: (json['status'] as String?) ?? 'available',
  );

  String get title =>
      source == 'inline' ? 'Pasted key' : (path.isEmpty ? 'Key file' : path);

  String get usage => user.isEmpty ? host : '$user@$host';
}

Future<List<KeyInfo>> loadKeysFromCore() {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final raw = bridge.keysJson();
    if (raw == null) {
      throw const NativeBridgeError('The core could not load keys');
    }
    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(KeyInfo.fromCoreJson)
        .toList();
  });
}

/// One saved port-forward rule and the session that owns it.
class ForwardRule {
  final String sessionId;
  final String sessionName;
  final String sessionKind;
  final int index;
  final String kind;
  final String name;
  final String bindAddr;
  final int bindPort;
  final String host;
  final int hostPort;

  const ForwardRule({
    required this.sessionId,
    required this.sessionName,
    required this.sessionKind,
    required this.index,
    required this.kind,
    required this.name,
    required this.bindAddr,
    required this.bindPort,
    required this.host,
    required this.hostPort,
  });

  factory ForwardRule.fromCoreJson(Map<String, dynamic> json) => ForwardRule(
    sessionId: (json['session_id'] as String?) ?? '',
    sessionName: (json['session_name'] as String?) ?? '',
    sessionKind: (json['session_kind'] as String?) ?? 'ssh',
    index: (json['index'] as num?)?.toInt() ?? 0,
    kind: (json['kind'] as String?) ?? 'local',
    name: (json['name'] as String?) ?? '',
    bindAddr: (json['bind_addr'] as String?) ?? '',
    bindPort: (json['bind_port'] as num?)?.toInt() ?? 0,
    host: (json['host'] as String?) ?? '',
    hostPort: (json['host_port'] as num?)?.toInt() ?? 0,
  );

  String get bind => '$bindAddr:$bindPort';
  String get target => kind == 'dynamic'
      ? 'SOCKS5'
      : host.isEmpty || hostPort == 0
      ? ''
      : '$host:$hostPort';
}

Future<List<ForwardRule>> loadForwardsFromCore() {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final raw = bridge.forwardsJson();
    if (raw == null) {
      throw const NativeBridgeError('The core could not load port forwards');
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded['__error'] != null) {
      throw NativeBridgeError('${decoded['__error']}');
    }
    return (decoded as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ForwardRule.fromCoreJson)
        .toList();
  });
}

Future<CoreWriteResult> saveForwardToCore({
  required String sessionId,
  required int index,
  required String kind,
  required String name,
  required String bindAddr,
  required String bindPort,
  required String host,
  required String hostPort,
}) {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final result = bridge.upsertForward({
      'session_id': sessionId,
      'index': index,
      'kind': kind,
      'name': name,
      'bind_addr': bindAddr,
      'bind_port': bindPort,
      'host': host,
      'host_port': hostPort,
    });
    if (result['ok'] != true) {
      return CoreWriteResult(
        ok: false,
        error: (result['error'] as String?) ?? 'Could not save the rule',
      );
    }
    return CoreWriteResult(
      ok: true,
      id: (result['index'] as num?)?.toInt().toString(),
    );
  });
}

Future<CoreWriteResult> deleteForwardFromCore({
  required String sessionId,
  required int index,
}) {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final result = bridge.deleteForward({
      'session_id': sessionId,
      'index': index,
    });
    if (result['ok'] != true) {
      return CoreWriteResult(
        ok: false,
        error: (result['error'] as String?) ?? 'Could not delete the rule',
      );
    }
    return const CoreWriteResult(ok: true);
  });
}

/// One remembered SSH host key (`known_hosts`, TOFU).
class KnownHost {
  final String id;
  final String keyType;
  final String fingerprint;

  const KnownHost({
    required this.id,
    required this.keyType,
    required this.fingerprint,
  });

  factory KnownHost.fromCoreJson(Map<String, dynamic> json) => KnownHost(
    id: (json['id'] as String?) ?? '',
    keyType: (json['key_type'] as String?) ?? '',
    fingerprint: (json['fingerprint'] as String?) ?? '',
  );

  String get host {
    final at = id.lastIndexOf(':');
    return at > 0 ? id.substring(0, at) : id;
  }

  String get port =>
      id.lastIndexOf(':') > 0 ? id.substring(id.lastIndexOf(':') + 1) : '';
}

/// Reads the remembered host keys from the core off the UI thread.
Future<List<KnownHost>> loadKnownHostsFromCore() {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final raw = bridge.knownHostsJson();
    if (raw == null) {
      throw const NativeBridgeError('The core could not load known hosts');
    }
    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(KnownHost.fromCoreJson)
        .toList();
  });
}

/// Forgets one `host:port` entry in the core's TOFU store.
Future<CoreWriteResult> deleteKnownHostFromCore(String id) {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final result = bridge.deleteKnownHost(id);
    if (result['ok'] != true) {
      return CoreWriteResult(
        ok: false,
        error: (result['error'] as String?) ?? 'Could not remove the host key',
      );
    }
    return CoreWriteResult(ok: true, id: id);
  });
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

/// Creates or updates a session in the core's store. Ids are generated by the
/// core; an empty id creates. Runs off the UI thread (store save touches the
/// keyring-protected SQLite file).
Future<CoreWriteResult> saveSessionToCore({
  required String id,
  required String label,
  required String address,
  required int port,
  required String username,
  required String group,
  required String kind,
  String keyPath = '',
}) {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final result = bridge.upsertSession({
      'id': id,
      'label': label,
      'address': address,
      'port': port,
      'username': username,
      'group': group,
      'kind': kind,
    });
    return CoreWriteResult(
      ok: result['ok'] == true,
      id: result['id'] as String?,
      error: result['error'] as String?,
    );
  });
}

/// Deletes one saved session from the core's store.
Future<CoreWriteResult> deleteSessionFromCore(String id) {
  return Isolate.run(() {
    final bridge = NativeBridge.tryLoad();
    if (bridge == null) {
      throw const NativeBridgeError(
        'xenterm_bridge library not found next to the app',
      );
    }
    final result = bridge.deleteSession(id);
    return CoreWriteResult(
      ok: result['ok'] == true,
      error: result['error'] as String?,
    );
  });
}

/// Synchronous variant for diagnostics (e.g. the core version line).
String? coreVersionSync() => NativeBridge.tryLoad()?.version();
