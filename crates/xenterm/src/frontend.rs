//! Public façade for in-process frontends (the Flutter bridge).
//!
//! This is the only public surface over the session runtime and the rio-vt
//! terminal engine: frontends start a session by id, read a compact screen
//! snapshot, send input, resize, answer connect-time prompts and close it.
//! Everything below stays private so the UI kit never leaks into the core.
//!
//! The pump thread owns the session's event receiver: output is fed straight
//! into the engine (rio-vt), and a version counter lets a frontend poll cheaply
//! and only pay for a snapshot when the screen actually changed.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use serde_json::{json, Value};

use crate::config::{ConfigStore, SessionKind};
use crate::session::protocol::{
    CredentialReply, CredentialResponder, HostKeyResponder, MfaResponder, SessionEvent,
    SessionHandle,
};
use crate::terminal::{TerminalCell, TerminalColor, TerminalEngine};

/// One pending blocking prompt (host key / credentials / MFA), answered by the
/// frontend through [`TerminalSession::answer_prompt`].
enum PendingPrompt {
    HostKey {
        host: String,
        port: u16,
        key_type: String,
        fingerprint: String,
        changed: bool,
        responder: HostKeyResponder,
    },
    Credential {
        host: String,
        user: String,
        need_user: bool,
        need_password: bool,
        responder: CredentialResponder,
    },
    Mfa {
        prompt: String,
        echo: bool,
        responder: MfaResponder,
    },
}

struct PromptEntry {
    id: u64,
    prompt: PendingPrompt,
}

pub struct TerminalSession {
    handle: SessionHandle,
    engine: Mutex<TerminalEngine>,
    version: AtomicU64,
    status: Mutex<String>,
    closed: Mutex<Option<String>>,
    prompt: Mutex<Option<PromptEntry>>,
    prompt_seq: AtomicU64,
}

fn color_json(color: TerminalColor) -> Value {
    match color {
        TerminalColor::Default => Value::Null,
        TerminalColor::Idx(index) => json!({ "idx": index }),
        TerminalColor::Rgb(r, g, b) => json!({ "rgb": [r, g, b] }),
    }
}

fn style_json(cell: &TerminalCell) -> Value {
    json!({
        "fg": color_json(cell.fgcolor()),
        "bg": color_json(cell.bgcolor()),
        "b": cell.bold(),
        "i": cell.inverse(),
    })
}

impl TerminalSession {
    /// Looks the session up in the store, spawns its transport and starts the
    /// pump thread that feeds rio-vt. `scrollback` is in lines.
    pub fn start(
        runtime: &tokio::runtime::Handle,
        store: &ConfigStore,
        session_id: &str,
        cols: u16,
        rows: u16,
        scrollback: usize,
    ) -> Result<Arc<TerminalSession>, String> {
        let session = store
            .sessions()
            .iter()
            .find(|s| s.id == session_id)
            .cloned()
            .ok_or_else(|| format!("session {session_id} not found"))?;
        let jump = store
            .resolve_jump_chain(&session)
            .map_err(|error| error.to_string())?;
        let tab_id = session.id.clone();
        let (handle, mut events) = match session.kind {
            SessionKind::Ssh => crate::ssh::spawn_session(
                runtime,
                tab_id,
                session,
                jump,
                cols as u32,
                rows as u32,
            ),
            SessionKind::Serial => crate::terminal::serial::spawn_serial_session(
                runtime,
                session.id.clone(),
                session,
            ),
            SessionKind::Telnet => crate::terminal::telnet::spawn_telnet_session(
                runtime,
                tab_id,
                session,
                cols as u32,
                rows as u32,
            ),
            SessionKind::Local => crate::terminal::local::spawn_local_session(
                runtime,
                tab_id,
                session,
                cols as u32,
                rows as u32,
            ),
        };

        let session = Arc::new(TerminalSession {
            handle,
            engine: Mutex::new(TerminalEngine::new(rows, cols, scrollback)),
            version: AtomicU64::new(1),
            status: Mutex::new(String::new()),
            closed: Mutex::new(None),
            prompt: Mutex::new(None),
            prompt_seq: AtomicU64::new(1),
        });

        let pump = session.clone();
        std::thread::Builder::new()
            .name("xenterm-terminal-pump".into())
            .spawn(move || {
                while let Some(event) = events.blocking_recv() {
                    match event {
                        SessionEvent::Output(text) => {
                            if let Ok(mut engine) = pump.engine.lock() {
                                engine.process(text.as_bytes());
                            }
                            pump.version.fetch_add(1, Ordering::SeqCst);
                        }
                        SessionEvent::Status(status) => {
                            if let Ok(mut slot) = pump.status.lock() {
                                *slot = status;
                            }
                            pump.version.fetch_add(1, Ordering::SeqCst);
                        }
                        SessionEvent::Connected => {
                            if let Ok(mut slot) = pump.status.lock() {
                                *slot = "Connected".into();
                            }
                            pump.version.fetch_add(1, Ordering::SeqCst);
                        }
                        SessionEvent::Closed(reason) => {
                            if let Ok(mut slot) = pump.closed.lock() {
                                *slot = Some(reason.clone());
                            }
                            pump.version.fetch_add(1, Ordering::SeqCst);
                            break;
                        }
                        SessionEvent::HostKeyPrompt {
                            host,
                            port,
                            key_type,
                            fingerprint,
                            changed,
                            responder,
                        } => {
                            pump.set_prompt(PendingPrompt::HostKey {
                                host,
                                port,
                                key_type,
                                fingerprint,
                                changed,
                                responder,
                            });
                        }
                        SessionEvent::CredentialPrompt {
                            host,
                            user,
                            need_user,
                            need_password,
                            responder,
                            ..
                        } => {
                            pump.set_prompt(PendingPrompt::Credential {
                                host,
                                user,
                                need_user,
                                need_password,
                                responder,
                            });
                        }
                        SessionEvent::MfaPrompt {
                            prompt,
                            echo,
                            responder,
                            ..
                        } => {
                            pump.set_prompt(PendingPrompt::Mfa {
                                prompt,
                                echo,
                                responder,
                            });
                        }
                        _ => {}
                    }
                }
            })
            .map_err(|error| error.to_string())?;

        Ok(session)
    }

    fn set_prompt(&self, prompt: PendingPrompt) {
        let id = self.prompt_seq.fetch_add(1, Ordering::SeqCst);
        if let Ok(mut slot) = self.prompt.lock() {
            *slot = Some(PromptEntry { id, prompt });
        }
        self.version.fetch_add(1, Ordering::SeqCst);
    }

    /// Cheap change counter: poll this, and only read the snapshot when it moves.
    pub fn version(&self) -> u64 {
        self.version.load(Ordering::SeqCst)
    }

    /// Compact JSON screen for the renderer: rows of styled runs plus cursor,
    /// modes, status, close reason and any pending prompt.
    pub fn snapshot_json(&self) -> String {
        let engine = match self.engine.lock() {
            Ok(engine) => engine,
            Err(poisoned) => poisoned.into_inner(),
        };
        let (rows, cols) = engine.size();
        let (cursor_row, cursor_col) = engine.cursor_position();
        let mut out_rows = Vec::with_capacity(rows as usize);
        for row in 0..rows {
            let mut text = String::new();
            let mut runs: Vec<Value> = Vec::new();
            let mut run_text = String::new();
            let mut run_cells = 0usize;
            let mut run_style: Option<Value> = None;
            for col in 0..cols {
                let cell = engine.cell(row, col);
                if let Some(ref cell) = cell {
                    if cell.is_wide_continuation() {
                        continue;
                    }
                }
                let style = cell.as_ref().map(style_json);
                let contents = cell
                    .as_ref()
                    .map(|cell| cell.contents())
                    .unwrap_or_else(|| " ".to_string());
                let cells = if cell.as_ref().map(|c| c.is_wide()).unwrap_or(false) {
                    2
                } else {
                    1
                };
                if run_style.as_ref() != style.as_ref() {
                    if let Some(previous) = run_style.take() {
                        runs.push(json!({ "t": run_text, "c": run_cells, "s": previous }));
                    }
                    run_style = style;
                    run_text = String::new();
                    run_cells = 0;
                }
                run_cells += cells;
                run_text.push_str(&contents);
                text.push_str(&contents);
            }
            if let Some(previous) = run_style.take() {
                runs.push(json!({ "t": run_text, "c": run_cells, "s": previous }));
            }
            out_rows.push(json!({ "text": text, "runs": runs }));
        }
        let prompt = self.prompt.lock().ok().and_then(|slot| {
            slot.as_ref().map(|entry| match &entry.prompt {
                PendingPrompt::HostKey {
                    host,
                    port,
                    key_type,
                    fingerprint,
                    changed,
                    ..
                } => json!({
                    "id": entry.id,
                    "kind": "host_key",
                    "host": host,
                    "port": port,
                    "key_type": key_type,
                    "fingerprint": fingerprint,
                    "changed": changed,
                }),
                PendingPrompt::Credential {
                    host,
                    user,
                    need_user,
                    need_password,
                    ..
                } => json!({
                    "id": entry.id,
                    "kind": "credential",
                    "host": host,
                    "user": user,
                    "need_user": need_user,
                    "need_password": need_password,
                }),
                PendingPrompt::Mfa { prompt, echo, .. } => json!({
                    "id": entry.id,
                    "kind": "mfa",
                    "prompt": prompt,
                    "echo": echo,
                }),
            })
        });
        let status = self
            .status
            .lock()
            .map(|slot| slot.clone())
            .unwrap_or_default();
        let closed = self.closed.lock().ok().and_then(|slot| slot.clone());
        json!({
            "rows": out_rows,
            "cols": cols,
            "rowCount": rows,
            "cursor": [cursor_row, cursor_col],
            "cursorHidden": engine.cursor_hidden(),
            "applicationCursor": engine.application_cursor(),
            "alternate": engine.alternate_screen(),
            "status": status,
            "closed": closed,
            "prompt": prompt,
        })
        .to_string()
    }

    pub fn send_input(&self, bytes: &[u8]) {
        self.handle.send_raw(bytes.to_vec());
    }

    pub fn resize(&self, cols: u16, rows: u16) {
        if let Ok(mut engine) = self.engine.lock() {
            engine.resize(rows, cols);
        }
        self.handle.resize(cols as u32, rows as u32);
        self.version.fetch_add(1, Ordering::SeqCst);
    }

    pub fn close(&self) {
        self.handle.close();
    }

    /// Answers the current prompt (no-op when the id no longer matches).
    /// Host-key prompts use `accept`; credentials use `username`/`password`;
    /// MFA uses `text`.
    pub fn answer_prompt(
        &self,
        id: u64,
        accept: bool,
        username: Option<String>,
        password: Option<String>,
        text: Option<String>,
    ) {
        let entry = self
            .prompt
            .lock()
            .ok()
            .and_then(|mut slot| match slot.as_ref() {
                Some(entry) if entry.id == id => slot.take(),
                _ => None,
            });
        let Some(entry) = entry else { return };
        match entry.prompt {
            PendingPrompt::HostKey { responder, .. } => responder.respond(accept),
            PendingPrompt::Credential {
                responder, user, ..
            } => {
                if accept {
                    let user = username.filter(|u| !u.is_empty()).unwrap_or(user);
                    let reply: CredentialReply =
                        (user, password.unwrap_or_default(), false);
                    responder.respond(Some(reply));
                } else {
                    responder.respond(None);
                }
            }
            PendingPrompt::Mfa { responder, .. } => {
                if accept {
                    responder.respond(text);
                } else {
                    responder.respond(None);
                }
            }
        }
        self.version.fetch_add(1, Ordering::SeqCst);
    }
}

/// One remembered SSH host key, projected for the frontend.
pub struct KnownHostInfo {
    pub id: String,
    pub key_type: String,
    pub fingerprint: String,
}

/// Every stored host key (TOFU `known_hosts`).
pub fn known_hosts() -> Vec<KnownHostInfo> {
    crate::ssh::known_hosts::entries()
        .into_iter()
        .map(|entry| KnownHostInfo {
            id: entry.id,
            key_type: entry.key_type,
            fingerprint: entry.fingerprint,
        })
        .collect()
}

/// Forgets one `host:port` entry. Returns whether anything was removed.
pub fn forget_known_host(id: &str) -> Result<bool, String> {
    crate::ssh::known_hosts::forget(id).map_err(|error| error.to_string())
}

/// Convenience for a frontend that keeps a registry of sessions.
pub type SessionRegistry = HashMap<u64, Arc<TerminalSession>>;

/// Creates a session registry shared behind a mutex.
pub fn new_registry() -> Arc<Mutex<SessionRegistry>> {
    Arc::new(Mutex::new(SessionRegistry::new()))
}
