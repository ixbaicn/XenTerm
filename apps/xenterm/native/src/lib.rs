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

use std::ffi::{c_char, CStr, CString};
use std::sync::{Mutex, OnceLock};

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

/// Release a string this bridge returned.
#[no_mangle]
pub extern "C" fn xenterm_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(unsafe { CString::from_raw(ptr) });
    }
}
