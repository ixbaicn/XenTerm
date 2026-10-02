//! Synthetic-only fixtures. No real host, credential, OS keyring or user profile.
use super::super::SessionTrigger;
use super::*;

fn temp_store() -> ConfigStore {
    ConfigStore {
        path: std::env::temp_dir().join(format!("xenterm-import-{}.db", Uuid::new_v4())),
        backup_dir: None,
        cache: ConfigFile::default(),
        key: [7; 32],
        keyring_enabled: false,
        saved_state: std::sync::Mutex::new(SavedState::default()),
    }
}
fn session(id: &str) -> Session {
    Session {
        id: id.into(),
        name: format!("Synthetic {id}"),
        host: format!("{id}.example.invalid"),
        user: "fixture-user".into(),
        ..Session::new_empty()
    }
}
fn native(sessions: Vec<Session>) -> String {
    serde_json::json!({"sessions": sessions}).to_string()
}
fn snapshot(store: &ConfigStore) -> serde_json::Value {
    serde_json::to_value(&store.cache).unwrap()
}
fn disk(store: &ConfigStore) -> serde_json::Value {
    let conn = rusqlite::Connection::open(&store.path).unwrap();
    let (settings, sessions, history) = ConfigStore::read_disk_store(&conn).unwrap().unwrap();
    serde_json::json!({"settings": settings, "sessions": sessions, "history": history})
}
fn disk_session(store: &ConfigStore, index: usize) -> Session {
    serde_json::from_value(disk(store)["sessions"][index].clone()).unwrap()
}
fn cleanup(store: &ConfigStore) {
    for suffix in ["", "-wal", "-shm"] {
        let _ = fs::remove_file(format!("{}{suffix}", store.path.display()));
    }
}

#[test]
fn portable_roundtrip_retains_meatshell_format_credentials_fields_and_jump_references() {
    let mut source = temp_store();
    let outer = session("outer");
    let mut inner = session("inner");
    inner.jump_session_id = outer.id.clone();
    let mut target = session("target");
    target.jump_session_id = inner.id.clone();
    target.jump_session_ids = vec![outer.id.clone(), inner.id.clone()];
    target.password = Secret::new("synthetic-password");
    target.private_key_inline = Secret::new("synthetic-inline-key");
    target.private_key_path = "C:\\synthetic\\key-path".into();
    target.proxy = "socks5://fixture:synthetic-proxy-password@127.0.0.1:1080".into();
    target.triggers.push(SessionTrigger {
        expect: "synthetic prompt".into(),
        response: Secret::new("synthetic-trigger-response"),
        ..Default::default()
    });
    target.group = "Synthetic Group".into();
    target.note = "Synthetic note".into();
    source.cache.sessions = vec![target.clone(), inner, outer];
    let (export, count) = source.export_json().unwrap();
    assert_eq!(count, 3);
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&export).unwrap()["meatshell_export"],
        1
    );
    assert!(export.contains("enc:exp:v1:"));
    for secret in [
        "synthetic-password",
        "synthetic-inline-key",
        "synthetic-trigger-response",
        "synthetic-proxy-password",
    ] {
        assert!(!export.contains(secret));
    }
    let mut destination = temp_store();
    destination.key = [9; 32];
    assert_eq!(destination.import_json(&export).unwrap(), (3, 0));
    let imported = &destination.cache.sessions;
    assert_ne!(imported[0].id, target.id);
    assert_eq!(imported[0].jump_session_id, imported[1].id);
    assert_eq!(
        imported[0].jump_session_ids,
        [imported[2].id.clone(), imported[1].id.clone()]
    );
    assert_eq!(imported[1].jump_session_id, imported[2].id);
    assert_eq!(
        destination.resolve_jump_chain(&imported[0]).unwrap().len(),
        2
    );
    let mut comparable = imported[0].clone();
    comparable.id = target.id.clone();
    comparable.jump_session_id = target.jump_session_id.clone();
    comparable.jump_session_ids = target.jump_session_ids.clone();
    assert_eq!(
        serde_json::to_value(comparable).unwrap(),
        serde_json::to_value(target).unwrap()
    );
    let stored = disk_session(&destination, 0);
    for (secret, plaintext) in [
        (&stored.password, "synthetic-password"),
        (&stored.private_key_inline, "synthetic-inline-key"),
        (&stored.triggers[0].response, "synthetic-trigger-response"),
    ] {
        assert_eq!(
            ConfigStore::try_decrypt(&destination.key, secret.as_str()).as_deref(),
            Some(plaintext)
        );
    }
    assert!(!disk(&destination)
        .to_string()
        .contains("synthetic-proxy-password"));
    assert_eq!(destination.import_json(&export).unwrap(), (0, 3));
    cleanup(&destination);
}

#[test]
fn public_meatshell_v1_fixture_imports_without_reencoding_the_source() {
    // Produced by the public MeatShell CLI/MCP regression fixture, fixed nonce.
    let mut imported = session("legacy");
    imported.password = Secret::new(
        "enc:exp:v1:AAAAAAAAAAAAAAAAFeRqZmIDNa2U57LDoinkeMgDVXvorTTv3qrwXh1pSN4M7bdXvSrE",
    );
    let raw = serde_json::json!({"meatshell_export": 1, "sessions": [imported]}).to_string();
    let mut store = temp_store();
    assert_eq!(store.import_json(&raw).unwrap(), (1, 0));
    assert!(!store.sessions()[0].password.is_empty());
    assert!(!store.sessions()[0].password.as_str().starts_with("enc:"));
    cleanup(&store);
}

#[test]
fn duplicate_hops_are_remapped_and_distinct_aliases_never_overwrite() {
    let mut store = temp_store();
    let existing = session("existing");
    store.cache.sessions.push(existing.clone());
    store.save().unwrap();
    let original_row = disk(&store)["sessions"][0].clone();
    let mut duplicate = existing.clone();
    duplicate.id = "source-hop".into();
    let mut target = session("target");
    target.jump_session_id = duplicate.id.clone();
    target.jump_session_ids = vec![duplicate.id.clone()];
    let mut alias = existing.clone();
    alias.name = "Intentional alias".into();
    alias.password = Secret::new("synthetic-other-password");
    let raw = native(vec![target, duplicate, alias]);
    assert_eq!(store.import_json(&raw).unwrap(), (2, 1));
    assert_eq!(disk(&store)["sessions"][0], original_row);
    assert_eq!(store.sessions()[1].jump_session_id, "existing");
    assert_eq!(store.sessions()[1].jump_session_ids, ["existing"]);
    assert_ne!(store.sessions()[2].id, "existing");
    let before = disk(&store);
    assert_eq!(store.import_json(&raw).unwrap(), (0, 3));
    assert_eq!(disk(&store), before);
    cleanup(&store);
}

#[test]
fn intra_batch_equivalent_sessions_share_a_remapped_id() {
    let mut store = temp_store();
    let first = session("first");
    let mut duplicate = first.clone();
    duplicate.id = "duplicate".into();
    let mut target = session("target");
    target.jump_session_ids = vec![duplicate.id.clone()];
    assert_eq!(
        store
            .import_json(&native(vec![target, first, duplicate]))
            .unwrap(),
        (2, 1)
    );
    assert_eq!(
        store.sessions()[0].jump_session_ids,
        [store.sessions()[1].id.clone()]
    );
    cleanup(&store);
}

#[test]
fn native_import_ignores_global_settings_even_if_they_are_malformed() {
    let mut store = temp_store();
    store.cache.wallpaper = "synthetic-destination-wallpaper".into();
    store.cache.mcp_enabled = false;
    store.cache.mcp_allow_commands = false;
    store.cache.webdav_password = Secret::new("synthetic-existing-webdav-secret");
    store.cache.sessions.push(session("existing"));
    store.save().unwrap();
    let before = snapshot(&store);
    let disk_before = disk(&store);
    let raw = serde_json::json!({"sessions": [session("new")], "wallpaper": 42,
        "mcp_enabled": true, "mcp_allow_commands": true, "webdav_password": "enc:v1:foreign"})
    .to_string();
    assert_eq!(store.import_json(&raw).unwrap(), (1, 0));
    let mut after = snapshot(&store);
    after["sessions"] = before["sessions"].clone();
    assert_eq!(after, before);
    assert_eq!(disk(&store)["settings"], disk_before["settings"]);
    cleanup(&store);
}

#[test]
fn preview_is_repeatable_and_never_changes_cache_disk_or_saved_state() {
    let mut store = temp_store();
    store.cache.sessions.push(session("existing"));
    store.save().unwrap();
    let before = snapshot(&store);
    let disk_before = disk(&store);
    let saved_before = store.saved_state.lock().unwrap().sessions.clone();
    for _ in 0..2 {
        assert_eq!(
            store
                .import_json_preview(&native(vec![session("existing"), session("new")]), true)
                .unwrap(),
            ImportSummary {
                added: 1,
                skipped: 1
            }
        );
        assert_eq!(snapshot(&store), before);
        assert_eq!(disk(&store), disk_before);
        assert_eq!(store.saved_state.lock().unwrap().sessions, saved_before);
    }
    cleanup(&store);
    let mut fresh = temp_store();
    assert_eq!(
        fresh
            .import_json_preview(&native(vec![session("fresh")]), true)
            .unwrap()
            .added,
        1
    );
    assert!(!fresh.path.exists());
}

#[test]
fn invalid_secrets_reject_the_entire_batch_and_redact_error_chains() {
    for field in ["password", "private_key_inline", "trigger", "proxy"] {
        for secret in [
            "enc:v1:synthetic-corrupt",
            "enc:exp:v1:synthetic-corrupt",
            "enc:future:synthetic",
            "keyring:v1",
        ] {
            let mut store = temp_store();
            store.cache.sessions.push(session("existing"));
            store.save().unwrap();
            let before = snapshot(&store);
            let disk_before = disk(&store);
            let mut invalid = session("existing");
            match field {
                "password" => invalid.password = Secret::new(secret),
                "private_key_inline" => invalid.private_key_inline = Secret::new(secret),
                "proxy" => invalid.proxy = format!("socks5://fixture:{secret}@127.0.0.1:1080"),
                _ => invalid.triggers.push(SessionTrigger {
                    response: Secret::new(secret),
                    ..Default::default()
                }),
            }
            for dry_run in [true, false] {
                let error = store
                    .import_json_preview(&native(vec![session("valid"), invalid.clone()]), dry_run)
                    .unwrap_err();
                assert!(!format!("{error:#}").contains(secret));
                assert_eq!(snapshot(&store), before);
                assert_eq!(disk(&store), disk_before);
            }
            cleanup(&store);
        }
    }
}

#[test]
fn native_matching_key_works_and_foreign_key_is_rejected_atomically() {
    let mut store = temp_store();
    let mut imported = session("native");
    imported.password =
        Secret::new(ConfigStore::encrypt(&store.key, "synthetic-local-password").unwrap());
    assert_eq!(store.import_json(&native(vec![imported])).unwrap(), (1, 0));
    assert_eq!(
        store.sessions()[0].password.as_str(),
        "synthetic-local-password"
    );
    let before = disk(&store);
    let mut foreign = session("foreign");
    foreign.password =
        Secret::new(ConfigStore::encrypt(&[99; 32], "synthetic-foreign-password").unwrap());
    assert!(store.import_json(&native(vec![foreign])).is_err());
    assert_eq!(disk(&store), before);
    cleanup(&store);
}

#[test]
fn sqlite_failure_on_second_insert_rolls_back_every_imported_row_and_cache() {
    let mut store = temp_store();
    store.cache.sessions.push(session("existing"));
    store.save().unwrap();
    let before = snapshot(&store);
    let disk_before = disk(&store);
    let conn = rusqlite::Connection::open(&store.path).unwrap();
    conn.execute_batch("CREATE TRIGGER fail_second BEFORE INSERT ON sessions WHEN NEW.ordinal = 2 BEGIN SELECT RAISE(ABORT, 'synthetic transaction failure'); END;").unwrap();
    assert!(store
        .import_json(&native(vec![session("first"), session("second")]))
        .is_err());
    assert_eq!(snapshot(&store), before);
    assert_eq!(disk(&store), disk_before);
    cleanup(&store);
}

#[test]
fn external_writer_or_unsaved_edits_are_rejected_without_overwriting_either_side() {
    let mut store = temp_store();
    store.cache.sessions.push(session("existing"));
    store.save().unwrap();
    let before = snapshot(&store);
    let mut external = temp_store();
    external.path = store.path.clone();
    external.cache = store.cache.clone();
    external.cache.sessions.push(session("external"));
    external.save().unwrap();
    let externally_written = disk(&store);
    assert!(store
        .import_json(&native(vec![session("new")]))
        .unwrap_err()
        .to_string()
        .contains("changed"));
    assert_eq!(snapshot(&store), before);
    assert_eq!(disk(&store), externally_written);
    cleanup(&store);
    let mut store = temp_store();
    store.cache.sessions.push(session("existing"));
    store.save().unwrap();
    let disk_before = disk(&store);
    store.cache.wallpaper = "unsaved".into();
    assert!(store.import_json(&native(vec![session("new")])).is_err());
    assert_eq!(disk(&store), disk_before);
    assert_eq!(store.cache.wallpaper, "unsaved");
    cleanup(&store);
}

#[test]
fn invalid_graphs_ids_hosts_and_paths_are_rejected_before_writing() {
    let mut cases = Vec::new();
    let mut s = session("missing");
    s.jump_session_id = "absent".into();
    cases.push(vec![s]);
    let mut s = session("self");
    s.jump_session_ids = vec!["self".into()];
    cases.push(vec![s]);
    let mut a = session("a");
    let mut b = session("b");
    a.jump_session_id = b.id.clone();
    b.jump_session_id = a.id.clone();
    cases.push(vec![a, b]);
    cases.push(vec![session("duplicate"), session("duplicate")]);
    let mut s = session("empty");
    s.id.clear();
    cases.push(vec![s]);
    let mut nonssh = session("nonssh");
    nonssh.kind = SessionKind::Telnet;
    let mut target = session("target");
    target.jump_session_ids = vec![nonssh.id.clone()];
    cases.push(vec![target, nonssh]);
    let mut hops: Vec<Session> = (0..18).map(|n| session(&format!("hop-{n}"))).collect();
    hops[0].jump_session_ids = hops[1..].iter().map(|s| s.id.clone()).collect();
    cases.push(hops);
    for host in ["", "bad host", "host\r\ninjected", "https://not-a-host"] {
        let mut s = session("host");
        s.host = host.into();
        cases.push(vec![s]);
    }
    let mut s = session("port");
    s.port = 0;
    cases.push(vec![s]);
    let mut s = session("path");
    s.private_key_path = "synthetic\0path".into();
    cases.push(vec![s]);
    for batch in cases {
        let mut store = temp_store();
        let before = snapshot(&store);
        assert!(store.import_json(&native(batch)).is_err());
        assert_eq!(snapshot(&store), before);
        assert!(!store.path.exists());
    }
}

#[test]
fn parse_errors_never_repeat_untrusted_input_and_version_is_checked() {
    let sentinel = "SYNTHETIC_SECRET_MUST_NOT_APPEAR";
    let mut bad = serde_json::to_value(session("bad")).unwrap();
    bad["kind"] = serde_json::json!(sentinel);
    let inputs = [
        serde_json::json!({"meatshell_export":1,"sessions":[bad]}).to_string(),
        serde_json::json!({"meatshell_export":sentinel,"sessions":[]}).to_string(),
        format!("{{\"{sentinel}\": invalid-json}}"),
        r#"{"meatshell_export":2,"sessions":[]}"#.into(),
        r#"{"meatshell_export":1}"#.into(),
        "{}".into(),
        r#"{"sessions":null}"#.into(),
    ];
    for input in inputs {
        let mut store = temp_store();
        let e = store.import_json(&input).unwrap_err();
        assert!(!format!("{e:#}").contains(sentinel));
        assert!(!format!("{e:?}").contains(sentinel));
        assert!(!store.path.exists());
    }
    let mut store = temp_store();
    assert_eq!(store.import_json(r#"{"sessions":[]}"#).unwrap(), (0, 0));
    assert!(!store.path.exists());
}

#[test]
fn files_must_be_regular_bounded_utf8_json() {
    let mut store = temp_store();
    let path = store.path.with_extension("json");
    fs::write(&path, native(vec![session("file")])).unwrap();
    assert_eq!(store.import_from_preview(&path, true).unwrap().added, 1);
    let file = fs::OpenOptions::new().write(true).open(&path).unwrap();
    file.set_len((MAX_IMPORT_BYTES + 1) as u64).unwrap();
    drop(file);
    assert!(store
        .import_from(&path)
        .unwrap_err()
        .to_string()
        .contains("16 MiB"));
    assert!(store
        .import_json(&" ".repeat(MAX_IMPORT_BYTES + 1))
        .is_err());
    fs::write(&path, [0xff, 0xfe]).unwrap();
    assert!(store.import_from(&path).is_err());
    fs::remove_file(&path).unwrap();
    assert!(store.import_from(&path).is_err());
    fs::create_dir(&path).unwrap();
    assert!(store.import_from(&path).is_err());
    fs::remove_dir(&path).unwrap();
    assert!(!store.path.exists());
}

#[test]
fn invalid_finalshell_batch_is_atomic_and_redacted() {
    let mut store = temp_store();
    let raw = r#"[{"conection_type":100,"host":"valid.example.invalid","password":"AwcLDRETFx1OXQgZJNatCplesw+x/P04"},{"conection_type":100,"host":"SYNTHETIC_SECRET_IN_HOST","password":"not base64"}]"#;
    let e = store.import_json(raw).unwrap_err();
    assert!(!format!("{e:#}").contains("SYNTHETIC_SECRET"));
    assert!(store.sessions().is_empty());
    assert!(!store.path.exists());
}

#[test]
fn decoded_literal_prefixes_survive_import_reload_and_repeated_saves() {
    for literal in [
        "enc:v1:synthetic-literal",
        "enc:exp:v1:synthetic-literal",
        "keyring:v1",
    ] {
        let mut source = temp_store();
        let mut s = session("literal");
        s.password = Secret::new(literal);
        s.private_key_inline = Secret::new(literal);
        s.triggers.push(SessionTrigger {
            response: Secret::new(literal),
            ..Default::default()
        });
        s.proxy = format!("socks5://fixture:{literal}@127.0.0.1:1080");
        source.cache.sessions.push(s);
        let (raw, _) = source.export_json().unwrap();
        let mut destination = temp_store();
        destination.key = [9; 32];
        destination.import_json(&raw).unwrap();
        for _ in 0..2 {
            let mut stored = disk_session(&destination, 0);
            assert!(!disk(&destination).to_string().contains(literal));
            ConfigStore::session_from_disk_form(&mut stored, &destination.key);
            assert_eq!(stored.password.as_str(), literal);
            assert!(!stored.password.is_local_ciphertext());
            assert_eq!(stored.private_key_inline.as_str(), literal);
            assert_eq!(stored.triggers[0].response.as_str(), literal);
            assert!(stored.proxy.contains(literal));
            destination.cache.sessions[0] = stored;
            destination.cache.sessions[0].last_used = Some(Uuid::new_v4().to_string());
            destination.save().unwrap();
        }
        cleanup(&destination);
    }
}

#[test]
fn unrelated_existing_invalid_routes_do_not_prevent_valid_imports() {
    let mut store = temp_store();
    let mut existing = session("existing");
    existing.jump_session_id = "missing".into();
    store.cache.sessions.push(existing);
    store.save().unwrap();
    assert_eq!(
        store.import_json(&native(vec![session("new")])).unwrap(),
        (1, 0)
    );
    cleanup(&store);
}

#[test]
fn reserved_groups_match_editor_semantics_and_stay_idempotent() {
    let mut store = temp_store();
    let mut imported = session("group");
    imported.group = "system".into();
    let raw = native(vec![imported]);
    assert_eq!(store.import_json(&raw).unwrap(), (1, 0));
    assert!(store.sessions()[0].group.is_empty());
    assert_eq!(store.import_json(&raw).unwrap(), (0, 1));
    cleanup(&store);
}

#[test]
#[cfg(not(feature = "desktop"))]
fn headless_master_key_remains_file_backed_and_survives_restarts() {
    let dir = std::env::temp_dir().join(format!("xenterm-headless-key-{}", Uuid::new_v4()));
    fs::create_dir(&dir).unwrap();
    fs::write(dir.join("secret.key"), [42u8; 32]).unwrap();
    for portable in [false, true, false] {
        assert_eq!(
            ConfigStore::resolve_master_key(&dir, portable).unwrap(),
            [42u8; 32]
        );
        assert_eq!(fs::read(dir.join("secret.key")).unwrap(), [42u8; 32]);
    }
    let mut stored = session("keyring-placeholder");
    stored.password = Secret::new(ConfigStore::KEYRING_MARKER);
    ConfigStore::session_from_disk_form(&mut stored, &[42u8; 32]);
    assert!(stored.password.is_empty());
    fs::remove_dir_all(dir).unwrap();
}
