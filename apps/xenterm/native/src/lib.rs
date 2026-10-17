//! The Flutter frontend's bridge onto the xenterm service core
//! (docs/flutter-bridge.md).
//!
//! Step 0 of the API ladder: the core's version and a compile-proof of the
//! in-process link. Every later step (sessions, terminal streams, SFTP,
//! resource sampling) is exposed here first as plain Rust, then flutter_rust_bridge
//! generates the Dart side against it — never the other way around.

/// The service core's version string (版本号规范 v1: `xt-…`).
pub fn core_version() -> String {
    xenterm::version::VERSION.to_string()
}

/// One host, as the hosts screen's list will receive it. Field names mirror
/// the core's `Session` projection; FRB will turn this into a Dart class.
pub struct HostSummary {
    pub id: String,
    pub label: String,
    pub address: String,
    pub port: u16,
    pub username: String,
    pub group: String,
}

/// Placeholder listing until the profile-scoped store constructor lands in
/// step 1 — keeps the bridge compiling and the shape pinned.
pub fn hosts_placeholder() -> Vec<HostSummary> {
    Vec::new()
}
