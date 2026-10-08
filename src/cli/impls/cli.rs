use anyhow::{anyhow, Context, Result};
use serde_json::{json, Value};
use std::path::Path;

use super::structs::CliCommand;

async fn call_cli(name: &str, arguments: &Value) -> Result<Value> {
    crate::automation::call(name, arguments, crate::automation::Frontend::Cli).await
}

pub(crate) fn run(args: &[String]) -> Result<()> {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .context("create CLI runtime")?;
    let command_name = args.get(2).map(String::as_str).unwrap_or("help");
    let command = CliCommand::parse(Some(command_name))
        .ok_or_else(|| anyhow!("unknown CLI command: {command_name}"))?;
    let value = match command {
        CliCommand::Import => {
            let path = args
                .get(3)
                .filter(|arg| !arg.starts_with("--"))
                .ok_or_else(|| {
                    anyhow!("usage: xenterm cli import <export.json> [--dry-run] [--preserve-ids] [--json]")
                })?;
            for arg in &args[4..] {
                if !matches!(arg.as_str(), "--dry-run" | "--preserve-ids" | "--json") {
                    return Err(anyhow!("unknown import option"));
                }
            }
            let dry_run = args[4..].iter().any(|arg| arg == "--dry-run");
            if args[4..].iter().any(|arg| arg == "--preserve-ids") {
                require_independent_migration_profile(crate::config::has_explicit_data_dir())?;
                let mut store = crate::config::ConfigStore::load()?;
                let summary = store.import_from_preserving_ids(Path::new(path), dry_run)?;
                let mut value = serde_json::to_value(summary)?;
                value["dry_run"] = json!(dry_run);
                value
            } else {
                runtime.block_on(call_cli(
                    "import_sessions",
                    &json!({
                        "local_path": path, "dry_run": dry_run
                    }),
                ))?
            }
        }
        CliCommand::SyncNative => {
            require_independent_migration_profile(crate::config::has_explicit_data_dir())?;
            let path = args
                .get(3)
                .filter(|arg| !arg.starts_with("--"))
                .ok_or_else(|| {
                    anyhow!("usage: xenterm cli sync-native <sessions.json> [--dry-run] [--json]")
                })?;
            if args[4..]
                .iter()
                .any(|arg| !matches!(arg.as_str(), "--json" | "--dry-run"))
            {
                return Err(anyhow!(
                    "unknown sync-native option (expected --dry-run or --json)"
                ));
            }
            let mut store = crate::config::ConfigStore::load()?;
            let dry_run = args[4..].iter().any(|arg| arg == "--dry-run");
            let (updated, added) = store.sync_native_snapshot_preview(Path::new(path), dry_run)?;
            json!({ "updated": updated, "added": added, "dry_run": dry_run })
        }
        CliCommand::Sessions => {
            let group = option_value(args, "--group")?;
            runtime.block_on(call_cli("list_sessions", &json!({ "group": group })))?
        }
        CliCommand::Session => {
            let id = args
                .get(3)
                .ok_or_else(|| anyhow!("usage: xenterm cli session <session-id> [--json]"))?;
            runtime.block_on(call_cli("get_session", &json!({ "session_id": id })))?
        }
        CliCommand::Exec => {
            let id = args.get(3).ok_or_else(|| {
                anyhow!("usage: xenterm cli exec <session-id> [--timeout <seconds>] [--json] -- <command>")
            })?;
            let delimiter = args
                .iter()
                .position(|arg| arg == "--")
                .ok_or_else(|| anyhow!("exec command must follow --"))?;
            let remote_command = args[delimiter + 1..].join(" ");
            if remote_command.trim().is_empty() {
                return Err(anyhow!("remote command must not be empty"));
            }
            let timeout = option_value(args, "--timeout")?
                .map(|value| value.parse::<u64>())
                .transpose()
                .context("--timeout must be a positive integer")?
                .unwrap_or(30);
            runtime.block_on(call_cli(
                "run_command",
                &json!({
                    "session_id": id,
                    "command": remote_command,
                    "timeout_seconds": timeout
                }),
            ))?
        }
        CliCommand::Files => {
            let id = args
                .get(3)
                .ok_or_else(|| anyhow!("usage: xenterm cli files <session-id> [path] [--json]"))?;
            let path = args
                .get(4)
                .filter(|value| !value.starts_with("--"))
                .map(String::as_str)
                .unwrap_or(".");
            runtime.block_on(call_cli(
                "list_remote_files",
                &json!({ "session_id": id, "path": path }),
            ))?
        }
        CliCommand::Read => {
            let id = args.get(3).ok_or_else(|| {
                anyhow!("usage: xenterm cli read <session-id> <remote-path> [--json]")
            })?;
            let path = args.get(4).ok_or_else(|| {
                anyhow!("usage: xenterm cli read <session-id> <remote-path> [--json]")
            })?;
            runtime.block_on(call_cli(
                "read_remote_text_file",
                &json!({ "session_id": id, "path": path }),
            ))?
        }
        CliCommand::Upload => {
            let id = args.get(3).ok_or_else(|| {
                anyhow!("usage: xenterm cli upload <session-id> <local-path> <remote-directory> [--json]")
            })?;
            let local_path = args.get(4).ok_or_else(|| anyhow!("missing local path"))?;
            let remote_directory = args
                .get(5)
                .ok_or_else(|| anyhow!("missing remote directory"))?;
            runtime.block_on(call_cli(
                "upload_file",
                &json!({
                    "session_id": id,
                    "local_path": local_path,
                    "remote_directory": remote_directory,
                    "timeout_seconds": 120
                }),
            ))?
        }
        CliCommand::Download => {
            let id = args.get(3).ok_or_else(|| {
                anyhow!("usage: xenterm cli download <session-id> <remote-path> <local-directory> [--json]")
            })?;
            let remote_path = args.get(4).ok_or_else(|| anyhow!("missing remote path"))?;
            let local_directory = args
                .get(5)
                .ok_or_else(|| anyhow!("missing local directory"))?;
            runtime.block_on(call_cli(
                "download_file",
                &json!({
                    "session_id": id,
                    "remote_path": remote_path,
                    "local_directory": local_directory,
                    "timeout_seconds": 120
                }),
            ))?
        }
        CliCommand::Help => {
            print_help();
            return Ok(());
        }
    };

    if args.iter().any(|arg| arg == "--json") {
        println!("{}", serde_json::to_string_pretty(&value)?);
    } else {
        print_human(command, &value);
    }
    Ok(())
}

/// Stable identifiers must stay within an independent local-key profile.
fn require_independent_migration_profile(explicit: bool) -> Result<()> {
    anyhow::ensure!(explicit,
        "stable-ID and native snapshot migrations require a separate --data-dir profile with local credential storage; export from the original application and initialize that independent profile with a portable import");
    Ok(())
}

fn option_value<'a>(args: &'a [String], option: &str) -> Result<Option<&'a str>> {
    let Some(index) = args.iter().position(|arg| arg == option) else {
        return Ok(None);
    };
    args.get(index + 1)
        .filter(|value| !value.starts_with("--"))
        .map(|value| Some(value.as_str()))
        .ok_or_else(|| anyhow!("missing value for {option}"))
}

fn print_human(command: CliCommand, value: &Value) {
    match command {
        CliCommand::Import => {
            println!(
                "{} {} sessions, skipped {} duplicates",
                if value.get("dry_run").and_then(Value::as_bool) == Some(true) {
                    "Would import"
                } else {
                    "Imported"
                },
                value.get("added").and_then(Value::as_u64).unwrap_or(0),
                value.get("skipped").and_then(Value::as_u64).unwrap_or(0)
            );
            if let Some(warnings) = value.get("warnings").and_then(Value::as_array) {
                for warning in warnings {
                    eprintln!(
                        "Warning ({} entries): {}",
                        warning.get("entries").and_then(Value::as_u64).unwrap_or(0),
                        text(warning, "message")
                    );
                }
            }
        }
        CliCommand::SyncNative => println!(
            "{} {} sessions, {} {} sessions",
            if value.get("dry_run").and_then(Value::as_bool) == Some(true) {
                "Would update"
            } else {
                "Updated"
            },
            value.get("updated").and_then(Value::as_u64).unwrap_or(0),
            if value.get("dry_run").and_then(Value::as_bool) == Some(true) {
                "would add"
            } else {
                "added"
            },
            value.get("added").and_then(Value::as_u64).unwrap_or(0)
        ),
        CliCommand::Sessions => {
            if let Some(sessions) = value.get("sessions").and_then(Value::as_array) {
                for session in sessions {
                    println!(
                        "{}\t{}@{}:{}\t{}",
                        text(session, "id"),
                        text(session, "user"),
                        text(session, "host"),
                        session.get("port").and_then(Value::as_u64).unwrap_or(0),
                        text(session, "name")
                    );
                }
            }
        }
        CliCommand::Session => println!(
            "{}",
            serde_json::to_string_pretty(value).unwrap_or_default()
        ),
        CliCommand::Exec => {
            print!("{}", text(value, "stdout"));
            eprint!("{}", text(value, "stderr"));
            if value.get("timed_out").and_then(Value::as_bool) == Some(true) {
                eprintln!("command timed out");
            }
        }
        CliCommand::Files => {
            if let Some(entries) = value.get("entries").and_then(Value::as_array) {
                for entry in entries {
                    println!(
                        "{}\t{}\t{}",
                        if entry.get("is_directory").and_then(Value::as_bool) == Some(true) {
                            "dir"
                        } else {
                            "file"
                        },
                        entry.get("size").and_then(Value::as_u64).unwrap_or(0),
                        text(entry, "path")
                    );
                }
            }
        }
        CliCommand::Read => print!("{}", text(value, "content")),
        CliCommand::Upload | CliCommand::Download => println!(
            "{} {} bytes",
            text(value, "name"),
            value
                .get("transferred")
                .and_then(Value::as_u64)
                .unwrap_or(0)
        ),
        CliCommand::Help => println!(
            "{}",
            serde_json::to_string_pretty(value).unwrap_or_default()
        ),
    }
}

fn text<'a>(value: &'a Value, key: &str) -> &'a str {
    value.get(key).and_then(Value::as_str).unwrap_or("")
}

fn print_help() {
    println!(
        "XenTerm CLI\n\n\
         Usage:\n\
           xenterm cli import <export.json> [--dry-run] [--preserve-ids] [--json]\n\
           xenterm cli sync-native <sessions.json> [--dry-run] [--json]\n\
           xenterm cli sessions [--group <name>] [--json]\n\
           xenterm cli session <session-id> [--json]\n\
           xenterm cli exec <session-id> [--timeout <seconds>] [--json] -- <command>\n\
           xenterm cli files <session-id> [path] [--json]\n\
           xenterm cli read <session-id> <remote-path> [--json]\n\
           xenterm cli upload <session-id> <local-path> <remote-directory> [--json]\n\
           xenterm cli download <session-id> <remote-path> <local-directory> [--json]"
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_option_values() {
        let args = vec![
            "xenterm".into(),
            "cli".into(),
            "sessions".into(),
            "--group".into(),
            "prod".into(),
        ];
        assert_eq!(option_value(&args, "--group").unwrap(), Some("prod"));
        assert_eq!(option_value(&args, "--json").unwrap(), None);
        assert_eq!(
            CliCommand::parse(Some("sync-native")),
            Some(CliCommand::SyncNative)
        );
    }

    #[test]
    fn migration_modes_require_explicit_independent_profiles() {
        assert!(require_independent_migration_profile(true).is_ok());
        assert!(require_independent_migration_profile(false)
            .unwrap_err()
            .to_string()
            .contains("--data-dir"));
    }
}
