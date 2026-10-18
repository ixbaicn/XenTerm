//! Key inventory projection: only sessions with key material are listed, and a
//! missing file is reported as such instead of leaking an error.

use std::ffi::{CStr, CString};

fn take(ptr: *mut std::ffi::c_char) -> String {
    assert!(!ptr.is_null(), "bridge returned null");
    let text = unsafe { CStr::from_ptr(ptr) }
        .to_string_lossy()
        .into_owned();
    xenterm_bridge::xenterm_string_free(ptr);
    text
}

fn json(ptr: *mut std::ffi::c_char) -> serde_json::Value {
    serde_json::from_str(&take(ptr)).unwrap()
}

#[test]
fn key_inventory_lists_key_sessions_only() {
    let dir = std::env::temp_dir().join(format!(
        "xenterm-bridge-keys-{}",
        std::process::id()
    ));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    std::env::set_var("XENTERM_DATA_DIR", &dir);
    let mut args = vec!["xenterm-bridge-test".to_string()];
    xenterm::config::configure_profile(&mut args).unwrap();

    let with_key = CString::new(
        r#"{"id":"","label":"keyhost","address":"10.0.0.2","port":22,"username":"root","group":"","kind":"ssh","private_key_path":"C:/definitely/missing/id_ed25519"}"#,
    )
    .unwrap();
    let created = json(xenterm_bridge::xenterm_session_upsert(
        with_key.as_ptr(),
    ));
    assert_eq!(created["ok"], true);

    let without = CString::new(
        r#"{"id":"","label":"plain","address":"10.0.0.3","port":22,"username":"root","group":"","kind":"ssh"}"#,
    )
    .unwrap();
    let created = json(xenterm_bridge::xenterm_session_upsert(without.as_ptr()));
    assert_eq!(created["ok"], true);

    let rows = json(xenterm_bridge::xenterm_keys_json());
    let rows = rows.as_array().unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0]["session_name"], "keyhost");
    assert_eq!(rows[0]["source"], "file");
    assert_eq!(rows[0]["path"], "id_ed25519");
    assert_eq!(rows[0]["status"], "missing");

    let _ = std::fs::remove_dir_all(dir);
}
