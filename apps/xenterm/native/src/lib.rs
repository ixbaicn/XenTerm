//! The Flutter frontend's bridge onto the xenterm service core
//! (docs/flutter-bridge.md).
//!
//! Step 1 of the API ladder: a minimal C ABI the Dart side loads with
//! `dart:ffi` — no flutter_rust_bridge codegen yet, so the first real
//! Rust↔Flutter link stays easy to audit. Strings cross as UTF-8 C pointers;
//! every returned string is owned by the caller and released through
//! [`xenterm_string_free`].
//!
//! Secrets never cross this surface: the session projection deliberately
//! carries only the fields the hosts list draws (docs/features.md §1 —
//! reveal-permission policy lives in the core's editor, not here).

use std::collections::HashMap;
use std::ffi::{c_char, CStr, CString};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use xenterm::frontend::TerminalSession;

/// The core, initialized exactly once per process (the bridge outlives
/// individual screens; ConfigStore::load is cheap after the first). The
/// mutex guards the store's save path (`upsert_and_save`/`remove`).
static STORE: OnceLock<Result<Mutex<xenterm::config::ConfigStore>, String>> = OnceLock::new();

fn store() -> Result<&'static Mutex<xenterm::config::ConfigStore>, String> {
    match STORE.get_or_init(|| {
        xenterm::config::ConfigStore::load()
            .map(Mutex::new)
            .map_err(|e| e.to_string())
    }) {
        Ok(store) => Ok(store),
        Err(error) => Err(error.clone()),
    }
}

/// The tokio runtime the session workers run on (same crate/version as the
/// core's dependency; Cargo unifies it).
static RUNTIME: OnceLock<Result<tokio::runtime::Runtime, String>> = OnceLock::new();

fn runtime() -> Result<&'static tokio::runtime::Runtime, String> {
    match RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .map_err(|e| e.to_string())
    }) {
        Ok(runtime) => Ok(runtime),
        Err(error) => Err(error.clone()),
    }
}

/// Live terminal sessions, keyed by the handle returned to Dart.
static SESSIONS: OnceLock<Arc<Mutex<HashMap<u64, Arc<TerminalSession>>>>> = OnceLock::new();
static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);

fn sessions() -> &'static Arc<Mutex<HashMap<u64, Arc<TerminalSession>>>> {
    SESSIONS.get_or_init(|| Arc::new(Mutex::new(HashMap::new())))
}

fn session(handle: u64) -> Option<Arc<TerminalSession>> {
    sessions()
        .lock()
        .ok()
        .and_then(|map| map.get(&handle).cloned())
}

/// SAFETY (callers): `ptr` must have come from Dart's `toNativeUtf8`.
unsafe fn take_c(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(ptr) }.to_string_lossy().into_owned()
}

fn to_c(s: String) -> *mut c_char {
    // A failed allocation aborts; a NUL inside `s` cannot occur in the JSON
    // we produce (serde escapes it), so unwrap is honest here.
    CString::new(s).expect("interior NUL in bridge string").into_raw()
}

/// The service core's version string (版本号规范 v1: `xt-…`).
#[no_mangle]
pub extern "C" fn xenterm_core_version() -> *mut c_char {
    to_c(xenterm::version::VERSION.to_string())
}

/// The saved sessions as a JSON array, projected to the fields the hosts
/// screen draws. `null` on store failure (the Dart side surfaces the error).
#[no_mangle]
pub extern "C" fn xenterm_sessions_json() -> *mut c_char {
    let json = (|| -> Result<String, String> {
        let store = store()?;
        let store = store.lock().unwrap_or_else(|p| p.into_inner());
        let rows: Vec<serde_json::Value> = store
            .sessions()
            .iter()
            .map(|s| {
                serde_json::json!({
                    "id": s.id,
                    "label": if s.name.is_empty() { &s.host } else { &s.name },
                    "address": if s.kind == xenterm::config::SessionKind::Serial {
                        &s.serial_port
                    } else {
                        &s.host
                    },
                    "port": s.port,
                    "username": s.user,
                    "group": s.group,
                    "kind": match s.kind {
                        xenterm::config::SessionKind::Ssh => "ssh",
                        xenterm::config::SessionKind::Serial => "serial",
                        xenterm::config::SessionKind::Telnet => "telnet",
                        xenterm::config::SessionKind::Local => "local",
                    },
                    "last_used": s.last_used,
                    "auth": s.auth.as_str(),
                    "private_key_path": s.private_key_path,
                    "serial": !s.serial_port.is_empty(),
                })
            })
            .collect();
        serde_json::to_string(&rows).map_err(|e| e.to_string())
    })();
    match json {
        Ok(json) => to_c(json),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Create or update one session from the JSON the drawer/editor sends
/// (`id` empty = create). Returns `{"ok":true,"id":"…"}` on success or
/// `{"ok":false,"error":"…"}`.
#[no_mangle]
pub extern "C" fn xenterm_session_upsert(json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let raw = unsafe { take_c(json) };
        let value: serde_json::Value =
            serde_json::from_str(&raw).map_err(|e| format!("invalid payload: {e}"))?;
        let id = value.get("id").and_then(|v| v.as_str()).unwrap_or_default();
        let label = value.get("label").and_then(|v| v.as_str()).unwrap_or_default();
        let address = value
            .get("address")
            .and_then(|v| v.as_str())
            .unwrap_or_default();
        let port = value.get("port").and_then(|v| v.as_u64()).unwrap_or(22) as u16;
        let username = value
            .get("username")
            .and_then(|v| v.as_str())
            .unwrap_or_default();
        let group = value
            .get("group")
            .and_then(|v| v.as_str())
            .unwrap_or_default();
        let kind = value.get("kind").and_then(|v| v.as_str()).unwrap_or("ssh");
        let key_path = value
            .get("private_key_path")
            .and_then(|v| v.as_str())
            .unwrap_or_default();

        let store = store()?;
        let mut store = store.lock().unwrap_or_else(|p| p.into_inner());
        let mut session = store
            .sessions()
            .iter()
            .find(|s| !id.is_empty() && s.id == id)
            .cloned()
            .unwrap_or_else(xenterm::config::Session::new_empty);

        session.name = label.to_string();
        session.host = address.to_string();
        session.port = port;
        session.user = username.to_string();
        session.group = group.to_string();
        session.kind = xenterm::config::SessionKind::from_str(kind);
        session.private_key_path = key_path.trim().to_string();
        session.auth = if session.private_key_path.is_empty() {
            xenterm::config::AuthMethod::Password
        } else {
            xenterm::config::AuthMethod::Key
        };
        if session.kind == xenterm::config::SessionKind::Serial {
            session.serial_port = address.to_string();
        }
        let id = session.id.clone();
        store
            .upsert_and_save(session)
            .map_err(|e| format!("save failed: {e}"))?;
        Ok(id)
    })();
    match result {
        Ok(id) => to_c(serde_json::json!({"ok": true, "id": id}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// Remove one saved session. Returns `{"ok":true}` or `{"ok":false,"error"}`.
#[no_mangle]
pub extern "C" fn xenterm_session_delete(id: *const c_char) -> *mut c_char {
    let result = (|| -> Result<(), String> {
        let id = unsafe { take_c(id) };
        if id.is_empty() {
            return Err("empty session id".into());
        }
        let store = store()?;
        let mut store = store.lock().unwrap_or_else(|p| p.into_inner());
        store.remove(&id);
        store.save().map_err(|e| format!("save failed: {e}"))
    })();
    match result {
        Ok(()) => to_c(serde_json::json!({"ok": true}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// Starts a saved session and returns `{"ok":true,"handle":N}` or
/// `{"ok":false,"error":"…"}`.
#[no_mangle]
pub extern "C" fn xenterm_session_start(
    id: *const c_char,
    cols: u32,
    rows: u32,
) -> *mut c_char {
    let result = (|| -> Result<u64, String> {
        let id = unsafe { take_c(id) };
        if id.is_empty() {
            return Err("empty session id".into());
        }
        let store = store()?;
        let store = store.lock().unwrap_or_else(|p| p.into_inner());
        let runtime = runtime()?;
        let terminal = TerminalSession::start(
            runtime.handle(),
            &store,
            &id,
            cols.clamp(1, 1000) as u16,
            rows.clamp(1, 1000) as u16,
            4000,
        )?;
        let handle = NEXT_HANDLE.fetch_add(1, Ordering::SeqCst);
        if let Ok(mut map) = sessions().lock() {
            map.insert(handle, terminal);
        }
        Ok(handle)
    })();
    match result {
        Ok(handle) => to_c(serde_json::json!({"ok": true, "handle": handle}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// Cheap change counter for a running terminal; 0 when the handle is unknown.
#[no_mangle]
pub extern "C" fn xenterm_session_version(handle: u64) -> u64 {
    session(handle).map(|s| s.version()).unwrap_or(0)
}

/// Compact JSON screen snapshot (rows/runs/cursor/modes/prompt), or null when
/// the handle is unknown.
#[no_mangle]
pub extern "C" fn xenterm_session_snapshot(handle: u64) -> *mut c_char {
    match session(handle) {
        Some(session) => to_c(session.snapshot_json()),
        None => std::ptr::null_mut(),
    }
}

/// Sends raw bytes (encoded keys/paste) to the session PTY.
#[no_mangle]
pub extern "C" fn xenterm_session_input(
    handle: u64,
    bytes: *const u8,
    len: usize,
) -> i32 {
    if bytes.is_null() || len == 0 {
        return 0;
    }
    let slice = unsafe { std::slice::from_raw_parts(bytes, len) };
    match session(handle) {
        Some(session) => {
            session.send_input(slice);
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_session_resize(handle: u64, cols: u32, rows: u32) -> i32 {
    match session(handle) {
        Some(session) => {
            session.resize(cols.clamp(1, 1000) as u16, rows.clamp(1, 1000) as u16);
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_session_close(handle: u64) -> i32 {
    match sessions().lock() {
        Ok(mut map) => match map.remove(&handle) {
            Some(session) => {
                session.close();
                1
            }
            None => 0,
        },
        Err(_) => 0,
    }
}

/// Answers the session's current prompt. Returns 1 when it was delivered.
#[no_mangle]
pub extern "C" fn xenterm_session_answer_prompt(
    handle: u64,
    prompt_id: u64,
    accept: i32,
    username: *const c_char,
    password: *const c_char,
    text: *const c_char,
) -> i32 {
    let opt = |ptr: *const c_char| -> Option<String> {
        if ptr.is_null() {
            None
        } else {
            Some(unsafe { take_c(ptr) })
        }
    };
    let user = opt(username);
    let pass = opt(password);
    let text = opt(text);
    match session(handle) {
        Some(session) => {
            session.answer_prompt(prompt_id, accept != 0, user, pass, text);
            1
        }
        None => 0,
    }
}

/// Saved quick commands (Snippets) as a JSON array.
#[no_mangle]
pub extern "C" fn xenterm_quick_commands_json() -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let store = store()?;
        let store = store.lock().unwrap_or_else(|p| p.into_inner());
        let rows: Vec<serde_json::Value> = store
            .quick_commands()
            .iter()
            .enumerate()
            .map(|(index, cmd)| {
                serde_json::json!({
                    "index": index,
                    "name": cmd.name,
                    "command": cmd.command,
                    "group": cmd.group,
                    "send_enter": cmd.send_enter,
                })
            })
            .collect();
        serde_json::to_string(&rows).map_err(|e| e.to_string())
    })();
    match result {
        Ok(json) => to_c(json),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Create (`index` < 0 or out of range) or update one quick command.
/// Returns `{"ok":true,"index":N}` or `{"ok":false,"error"}`.
#[no_mangle]
pub extern "C" fn xenterm_quick_command_upsert(json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<usize, String> {
        let raw = unsafe { take_c(json) };
        let value: serde_json::Value =
            serde_json::from_str(&raw).map_err(|e| format!("invalid payload: {e}"))?;
        let index = value.get("index").and_then(|v| v.as_i64()).unwrap_or(-1);
        let name = value
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .trim()
            .to_string();
        let command = value
            .get("command")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .trim()
            .to_string();
        let group = value
            .get("group")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .trim()
            .to_string();
        let send_enter = value
            .get("send_enter")
            .and_then(|v| v.as_bool())
            .unwrap_or(true);
        if command.is_empty() {
            return Err("the command cannot be empty".into());
        }
        let name = if name.is_empty() {
            command.clone()
        } else {
            name
        };

        let store = store()?;
        let mut store = store.lock().unwrap_or_else(|p| p.into_inner());
        let mut commands = store.quick_commands().to_vec();
        let command = xenterm::config::QuickCommand {
            name,
            command,
            group,
            send_enter,
        };
        let position = if index >= 0 && (index as usize) < commands.len() {
            commands[index as usize] = command;
            index as usize
        } else {
            commands.push(command);
            commands.len() - 1
        };
        store.set_quick_commands(commands);
        store.save().map_err(|e| format!("save failed: {e}"))?;
        Ok(position)
    })();
    match result {
        Ok(index) => to_c(serde_json::json!({"ok": true, "index": index}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// Remove one quick command by its current index.
#[no_mangle]
pub extern "C" fn xenterm_quick_command_delete(index: i64) -> *mut c_char {
    let result = (|| -> Result<(), String> {
        if index < 0 {
            return Err("invalid index".into());
        }
        let store = store()?;
        let mut store = store.lock().unwrap_or_else(|p| p.into_inner());
        let mut commands = store.quick_commands().to_vec();
        let at = index as usize;
        if at >= commands.len() {
            return Err("quick command no longer exists".into());
        }
        commands.remove(at);
        store.set_quick_commands(commands);
        store.save().map_err(|e| format!("save failed: {e}"))?;
        Ok(())
    })();
    match result {
        Ok(()) => to_c(serde_json::json!({"ok": true}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// Remembered SSH host keys (TOFU store) as a JSON array.
#[no_mangle]
pub extern "C" fn xenterm_known_hosts_json() -> *mut c_char {
    let rows: Vec<serde_json::Value> = xenterm::frontend::known_hosts()
        .into_iter()
        .map(|entry| {
            serde_json::json!({
                "id": entry.id,
                "key_type": entry.key_type,
                "fingerprint": entry.fingerprint,
            })
        })
        .collect();
    match serde_json::to_string(&rows) {
        Ok(json) => to_c(json),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Forgets one known-host entry by its `host:port` id.
#[no_mangle]
pub extern "C" fn xenterm_known_host_delete(id: *const c_char) -> *mut c_char {
    let id = unsafe { take_c(id) };
    match xenterm::frontend::forget_known_host(&id) {
        Ok(removed) => to_c(serde_json::json!({"ok": true, "removed": removed}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// Every saved SSH port-forward rule, annotated with its owning session.
#[no_mangle]
pub extern "C" fn xenterm_forwards_json() -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let store = store()?;
        let store = store.lock().unwrap_or_else(|p| p.into_inner());
        let mut rows = Vec::new();
        for session in store.sessions() {
            for (index, forward) in session.forwards.iter().enumerate() {
                rows.push(serde_json::json!({
                    "session_id": session.id,
                    "session_name": if session.name.is_empty() { &session.host } else { &session.name },
                    "session_kind": match session.kind {
                        xenterm::config::SessionKind::Ssh => "ssh",
                        xenterm::config::SessionKind::Serial => "serial",
                        xenterm::config::SessionKind::Telnet => "telnet",
                        xenterm::config::SessionKind::Local => "local",
                    },
                    "index": index,
                    "kind": forward.kind,
                    "name": forward.name,
                    "bind_addr": forward.bind_addr,
                    "bind_port": forward.bind_port,
                    "host": forward.host,
                    "host_port": forward.host_port,
                }));
            }
        }
        serde_json::to_string(&rows).map_err(|e| e.to_string())
    })();
    match result {
        Ok(json) => to_c(json),
        Err(error) => to_c(serde_json::json!({"__error": error}).to_string()),
    }
}

fn json_port(value: &serde_json::Value, key: &str) -> String {
    match value.get(key) {
        Some(serde_json::Value::Number(number)) => number.to_string(),
        Some(serde_json::Value::String(text)) => text.clone(),
        _ => String::new(),
    }
}

/// Create (`index` < 0) or update one port-forward rule on its session.
/// Validation is the same rule set the desktop editor uses.
#[no_mangle]
pub extern "C" fn xenterm_forward_upsert(json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let raw = unsafe { take_c(json) };
        let value: serde_json::Value =
            serde_json::from_str(&raw).map_err(|e| format!("invalid payload: {e}"))?;
        let session_id = value
            .get("session_id")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        if session_id.is_empty() {
            return Err("no host selected".into());
        }
        let index = value.get("index").and_then(|v| v.as_i64()).unwrap_or(-1);
        let draft = xenterm::core::tunnel::TunnelDraft {
            kind: value
                .get("kind")
                .and_then(|v| v.as_str())
                .unwrap_or("local")
                .to_string(),
            name: value
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string(),
            bind_addr: value
                .get("bind_addr")
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string(),
            bind_port: json_port(&value, "bind_port"),
            host: value
                .get("host")
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string(),
            host_port: json_port(&value, "host_port"),
        };
        let rule = xenterm::core::tunnel::validate(&[draft])
            .map_err(|error| error)?
            .into_iter()
            .next()
            .ok_or_else(|| "the rule is empty".to_string())?;

        let store = store()?;
        let mut store = store.lock().unwrap_or_else(|p| p.into_inner());
        let mut session = store
            .sessions()
            .iter()
            .find(|s| s.id == session_id)
            .cloned()
            .ok_or_else(|| "host no longer exists".to_string())?;
        let position = if index >= 0 && (index as usize) < session.forwards.len() {
            session.forwards[index as usize] = rule;
            index as usize
        } else {
            session.forwards.push(rule);
            session.forwards.len() - 1
        };
        store
            .upsert_and_save(session)
            .map_err(|e| format!("save failed: {e}"))?;
        Ok(serde_json::json!({"ok": true, "index": position, "session_id": session_id})
            .to_string())
    })();
    match result {
        Ok(json) => to_c(json),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// Delete one port-forward rule from its session.
#[no_mangle]
pub extern "C" fn xenterm_forward_delete(json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<(), String> {
        let raw = unsafe { take_c(json) };
        let value: serde_json::Value =
            serde_json::from_str(&raw).map_err(|e| format!("invalid payload: {e}"))?;
        let session_id = value
            .get("session_id")
            .and_then(|v| v.as_str())
            .unwrap_or_default();
        let index = value.get("index").and_then(|v| v.as_i64()).unwrap_or(-1);
        if session_id.is_empty() || index < 0 {
            return Err("invalid rule reference".into());
        }
        let store = store()?;
        let mut store = store.lock().unwrap_or_else(|p| p.into_inner());
        let mut session = store
            .sessions()
            .iter()
            .find(|s| s.id == session_id)
            .cloned()
            .ok_or_else(|| "host no longer exists".to_string())?;
        let at = index as usize;
        if at >= session.forwards.len() {
            return Err("the rule no longer exists".into());
        }
        session.forwards.remove(at);
        store
            .upsert_and_save(session)
            .map_err(|e| format!("save failed: {e}"))?;
        Ok(())
    })();
    match result {
        Ok(()) => to_c(serde_json::json!({"ok": true}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// SSH key credentials referenced by saved sessions (metadata only).
#[no_mangle]
pub extern "C" fn xenterm_keys_json() -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let store = store()?;
        let store = store.lock().unwrap_or_else(|p| p.into_inner());
        let rows: Vec<serde_json::Value> = xenterm::frontend::key_inventory(&store)
            .into_iter()
            .map(|key| {
                serde_json::json!({
                    "session_id": key.session_id,
                    "session_name": key.session_name,
                    "host": key.host,
                    "user": key.user,
                    "source": key.source,
                    "path": key.path,
                    "key_type": key.key_type,
                    "fingerprint": key.fingerprint,
                    "status": key.status,
                })
            })
            .collect();
        serde_json::to_string(&rows).map_err(|e| e.to_string())
    })();
    match result {
        Ok(json) => to_c(json),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Saved session transcripts (metadata only) as a JSON array.
#[no_mangle]
pub extern "C" fn xenterm_logs_json() -> *mut c_char {
    let rows: Vec<serde_json::Value> = xenterm::frontend::session_logs()
        .into_iter()
        .map(|log| {
            serde_json::json!({
                "file": log.file,
                "session_id": log.session_id,
                "name": log.name,
                "host": log.host,
                "user": log.user,
                "started_ms": log.started_ms,
                "size": log.size,
            })
        })
        .collect();
    match serde_json::to_string(&rows) {
        Ok(json) => to_c(json),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Reads one transcript: `{"ok":true,"text":"…","meta":{…},"ended_ms":…}`.
#[no_mangle]
pub extern "C" fn xenterm_log_read(name: *const c_char) -> *mut c_char {
    let name = unsafe { take_c(name) };
    match xenterm::frontend::read_session_log(&name) {
        Ok(value) => {
            let mut result = value;
            result["ok"] = serde_json::Value::Bool(true);
            to_c(result.to_string())
        }
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// Deletes one transcript.
#[no_mangle]
pub extern "C" fn xenterm_log_delete(name: *const c_char) -> *mut c_char {
    let name = unsafe { take_c(name) };
    match xenterm::frontend::delete_session_log(&name) {
        Ok(removed) => to_c(serde_json::json!({"ok": true, "removed": removed}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

/// The settings the Flutter UI can change, read from the core config.
#[no_mangle]
pub extern "C" fn xenterm_settings_json() -> *mut c_char {
    let result = (|| -> Result<String, String> {
        let store = store()?;
        let store = store.lock().unwrap_or_else(|p| p.into_inner());
        Ok(serde_json::json!({
            "session_logs": store.session_logs(),
            "cursor_style": store.terminal_cursor_style(),
            "line_spacing": store.terminal_line_spacing(),
            "padding": store.terminal_padding(),
            "bold": store.terminal_bold(),
            "sftp_follow_cd": store.sftp_follow_cd(),
            "download_dir": store.download_dir(),
        })
        .to_string())
    })();
    match result {
        Ok(json) => to_c(json),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Applies any subset of the settings above and saves the store.
#[no_mangle]
pub extern "C" fn xenterm_settings_set(json: *const c_char) -> *mut c_char {
    let result = (|| -> Result<(), String> {
        let raw = unsafe { take_c(json) };
        let value: serde_json::Value =
            serde_json::from_str(&raw).map_err(|e| format!("invalid payload: {e}"))?;
        let store = store()?;
        let mut store = store.lock().unwrap_or_else(|p| p.into_inner());
        if let Some(enabled) = value.get("session_logs").and_then(|v| v.as_bool()) {
            store.set_session_logs(enabled);
        }
        if let Some(style) = value.get("cursor_style").and_then(|v| v.as_str()) {
            store.set_terminal_cursor_style(style.to_string());
        }
        if let Some(spacing) = value.get("line_spacing").and_then(|v| v.as_f64()) {
            store.set_terminal_line_spacing(spacing as f32);
        }
        if let Some(padding) = value.get("padding").and_then(|v| v.as_bool()) {
            store.set_terminal_padding(padding);
        }
        if let Some(bold) = value.get("bold").and_then(|v| v.as_bool()) {
            store.set_terminal_bold(bold);
        }
        if let Some(follow) = value.get("sftp_follow_cd").and_then(|v| v.as_bool()) {
            store.set_sftp_follow_cd(follow);
        }
        if let Some(dir) = value.get("download_dir").and_then(|v| v.as_str()) {
            store.set_download_dir(dir.to_string());
        }
        store.save().map_err(|e| format!("save failed: {e}"))?;
        Ok(())
    })();
    match result {
        Ok(()) => to_c(serde_json::json!({"ok": true}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

static SFTP_SESSIONS: OnceLock<Mutex<HashMap<u64, Arc<xenterm::frontend::SftpSession>>>> =
    OnceLock::new();

fn sftp_sessions() -> &'static Mutex<HashMap<u64, Arc<xenterm::frontend::SftpSession>>> {
    SFTP_SESSIONS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn sftp(handle: u64) -> Option<Arc<xenterm::frontend::SftpSession>> {
    sftp_sessions().lock().ok()?.get(&handle).cloned()
}

/// Opens an SFTP channel for a saved session; returns `{"ok":true,"handle":N}`.
#[no_mangle]
pub extern "C" fn xenterm_sftp_start(id: *const c_char) -> *mut c_char {
    let result = (|| -> Result<u64, String> {
        let id = unsafe { take_c(id) };
        if id.is_empty() {
            return Err("empty session id".into());
        }
        let store = store()?;
        let store = store.lock().unwrap_or_else(|p| p.into_inner());
        let runtime = runtime()?;
        let session = xenterm::frontend::SftpSession::start(runtime.handle(), &store, &id)?;
        let handle = NEXT_HANDLE.fetch_add(1, Ordering::SeqCst);
        if let Ok(mut map) = sftp_sessions().lock() {
            map.insert(handle, session);
        }
        Ok(handle)
    })();
    match result {
        Ok(handle) => to_c(serde_json::json!({"ok": true, "handle": handle}).to_string()),
        Err(error) => to_c(serde_json::json!({"ok": false, "error": error}).to_string()),
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_version(handle: u64) -> u64 {
    sftp(handle).map(|s| s.version()).unwrap_or(0)
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_snapshot(handle: u64) -> *mut c_char {
    match sftp(handle) {
        Some(session) => to_c(session.snapshot_json()),
        None => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_list(handle: u64, path: *const c_char) -> i32 {
    match sftp(handle) {
        Some(session) => {
            session.list(unsafe { take_c(path) });
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_refresh(handle: u64) -> i32 {
    match sftp(handle) {
        Some(session) => {
            session.refresh();
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_download(
    handle: u64,
    remote: *const c_char,
    local_dir: *const c_char,
) -> i32 {
    match sftp(handle) {
        Some(session) => {
            session.download(unsafe { take_c(remote) }, unsafe { take_c(local_dir) });
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_upload(handle: u64, local: *const c_char) -> i32 {
    match sftp(handle) {
        Some(session) => {
            session.upload(unsafe { take_c(local) });
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_mkdir(handle: u64, name: *const c_char) -> i32 {
    match sftp(handle) {
        Some(session) => {
            session.mkdir(unsafe { take_c(name) });
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_delete(handle: u64, path: *const c_char) -> i32 {
    match sftp(handle) {
        Some(session) => {
            session.delete(unsafe { take_c(path) });
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_answer_prompt(
    handle: u64,
    prompt_id: u64,
    accept: i32,
    username: *const c_char,
    password: *const c_char,
    text: *const c_char,
) -> i32 {
    match sftp(handle) {
        Some(session) => {
            let username = unsafe { take_c(username) };
            let username = if username.is_empty() {
                None
            } else {
                Some(username)
            };
            let password = Some(unsafe { take_c(password) });
            let text = Some(unsafe { take_c(text) });
            session.answer_prompt(prompt_id, accept == 1, username, password, text);
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub extern "C" fn xenterm_sftp_close(handle: u64) -> i32 {
    match sftp_sessions().lock() {
        Ok(mut map) => match map.remove(&handle) {
            Some(session) => {
                session.close();
                1
            }
            None => 0,
        },
        Err(_) => 0,
    }
}

/// Release a string this bridge returned.
#[no_mangle]
pub extern "C" fn xenterm_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(unsafe { CString::from_raw(ptr) });
    }
}
