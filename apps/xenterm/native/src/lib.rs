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

use std::ffi::{c_char, CString};
use std::sync::OnceLock;

/// The core, initialized exactly once per process (the bridge outlives
/// individual screens; ConfigStore::load is cheap after the first).
static STORE: OnceLock<Result<xenterm::config::ConfigStore, String>> = OnceLock::new();

fn store() -> Result<&'static xenterm::config::ConfigStore, String> {
    match STORE.get_or_init(|| {
        xenterm::config::ConfigStore::load().map_err(|e| e.to_string())
    }) {
        Ok(store) => Ok(store),
        Err(error) => Err(error.clone()),
    }
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

/// Release a string this bridge returned.
#[no_mangle]
pub extern "C" fn xenterm_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(unsafe { CString::from_raw(ptr) });
    }
}
