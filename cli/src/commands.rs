use crate::doctor::{build_snapshot, home_dir, load_chezmoi_data, print_doctor_pretty, run_capture, which};
use anyhow::{Result, bail};
use std::env;
use std::os::unix::process::CommandExt;
use std::process::Command;

pub fn exec_helper(name: &str, args: &[String]) -> Result<i32> {
    let binary = home_dir().join(".local/libexec/dotfiles").join(name);
    if !binary.is_file() {
        eprintln!(
            "dotfiles: helper '{name}' not found at {}; run 'chezmoi apply'",
            binary.display()
        );
        return Ok(1);
    }

    let err = Command::new(&binary).args(args).exec();
    Err(anyhow::anyhow!("failed to exec {}: {err}", binary.display()))
}

pub fn cmd_doctor(json_out: bool) -> Result<i32> {
    let snap = build_snapshot();
    if json_out {
        println!("{}", serde_json::to_string_pretty(&snap.report)?);
    } else {
        print_doctor_pretty(&snap.report);
    }
    Ok(if snap.report.status == "error" { 1 } else { 0 })
}

pub fn cmd_sync(update: bool, dry_run: bool, no_externals: bool) -> Result<i32> {
    if which("chezmoi").is_none() {
        bail!("chezmoi not found on PATH");
    }
    if update {
        let (src_rc, src, _) = run_capture("chezmoi", &["source-path"]);
        if src_rc == 0 && !src.is_empty() && which("git").is_some() {
            let (in_git, _, _) = run_capture("git", &["-C", &src, "rev-parse", "--is-inside-work-tree"]);
            if in_git == 0 {
                let (st_rc, dirty, _) = run_capture("git", &["-C", &src, "status", "--porcelain"]);
                if st_rc == 0 && !dirty.is_empty() {
                    let lines: Vec<&str> = dirty.lines().collect();
                    if dry_run {
                        eprintln!(
                            "dotfiles sync: warning: source repo ({src}) has {} uncommitted change(s):",
                            lines.len()
                        );
                    } else {
                        eprintln!(
                            "dotfiles sync: source repo ({src}) has {} uncommitted change(s); refusing to auto-stash during update:",
                            lines.len()
                        );
                    }
                    for line in lines.iter().take(10) {
                        eprintln!("  {line}");
                    }
                    if lines.len() > 10 {
                        eprintln!("  ... ({} more)", lines.len() - 10);
                    }
                    if !dry_run {
                        eprintln!(
                            "Run `git -C {src} status` to inspect, then commit/stash/clean them before retrying `dotfiles sync --update`."
                        );
                        return Ok(1);
                    }
                }
                let (stash_rc, stashes, _) = run_capture("git", &["-C", &src, "stash", "list"]);
                if stash_rc == 0 && !stashes.is_empty() {
                    let count = stashes.lines().count();
                    eprintln!(
                        "dotfiles sync: note: {count} git stash entr{} in {src} (inspect with `git -C {src} stash list`)",
                        if count == 1 { "y" } else { "ies" }
                    );
                }
            }
        }
    }
    let mut args = vec![if update { "update" } else { "apply" }];
    if update {
        args.push("--init");
    }
    if dry_run {
        args.push("--dry-run");
        args.push("--verbose");
    }
    if no_externals {
        args.push("--exclude");
        args.push("externals");
    }
    let status = Command::new("chezmoi").args(&args).status()?;
    Ok(status.code().unwrap_or(1))
}

pub fn cmd_check() -> Result<i32> {
    let (rc, src, _) = run_capture("chezmoi", &["source-path"]);
    let cwd = if rc == 0 && !src.is_empty() {
        src
    } else {
        env::current_dir()?.to_string_lossy().into_owned()
    };
    let status = if which("mise").is_some() {
        Command::new("mise")
            .args(["run", "check"])
            .current_dir(&cwd)
            .status()?
    } else {
        Command::new("python3")
            .args(["-m", "unittest", "discover", "-s", "tests", "-v"])
            .current_dir(&cwd)
            .status()?
    };
    Ok(status.code().unwrap_or(1))
}

pub fn cmd_bootstrap() -> Result<i32> {
    let rc = cmd_sync(false, false, false)?;
    if rc != 0 {
        return Ok(rc);
    }
    cmd_doctor(false)
}

pub fn cmd_agent_status(json_out: bool) -> Result<i32> {
    let snap = build_snapshot();
    let agents = &snap.report.checks.agents;
    if json_out {
        println!("{}", serde_json::to_string_pretty(agents)?);
        return Ok(0);
    }
    println!(
        "dev bundle (agents): {}",
        if agents.agent_tools_selected { "enabled" } else { "disabled" }
    );
    let mut jail = if agents.agent_jail_backends.is_empty() {
        "none".to_string()
    } else {
        agents.agent_jail_backends.join(", ")
    };
    if let Some(active) = &agents.active_jail {
        jail.push_str(&format!(" (active: {active})"));
    }
    println!("agent-jail backends: {jail}");
    println!(
        "hooks: key-guard={} notify={}",
        if agents.key_guard { "ok" } else { "missing" },
        if agents.agent_notify { "ok" } else { "missing" }
    );
    for name in ["claude", "codex", "agy", "pi"] {
        if let Some(info) = agents.agents.get(name) {
            let bin = info.binary.as_deref().unwrap_or("not installed");
            let guard = if name == "pi" {
                info.guard_extension.unwrap_or(false)
            } else {
                info.key_guard_configured.unwrap_or(false)
            };
            println!(
                "  {name:<7} binary={bin} instructions={} guard={}",
                if info.instructions { "ok" } else { "missing" },
                if guard { "ok" } else { "missing" }
            );
        }
    }
    Ok(0)
}

pub fn cmd_complete(kind: &str) -> Result<i32> {
    let Ok(data) = load_chezmoi_data() else {
        return Ok(0);
    };
    match kind {
        "themes" => {
            for (slug, spec) in &data.themes {
                let desc = spec.description.replace(':', "\\:");
                println!("{slug}:{desc}");
            }
        }
        "machines" => {
            for (name, spec) in &data.machines {
                let desc = spec.description.replace(':', "\\:");
                println!("{name}:{desc}");
            }
        }
        "downloads" => {
            for (id, spec) in &data.downloads {
                let kind_label = if spec.fonts.is_some() { "font" } else { "app" };
                println!("{id}:{kind_label}");
            }
        }
        _ => {}
    }
    Ok(0)
}
