use crate::model::{
    AgentEntry, AgentsCheck, ChezmoiCheck, ChezmoiData, DoctorChecks, DoctorReport,
    FetchItemStatus, FullSnapshot, LooseKey, PolicyFile, SecretsCheck, ShellGitCheck,
    SystemCheck, ToolchainCheck,
};
use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::fs;
use std::os::unix::fs::{FileTypeExt, MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

pub fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

pub fn xdg_config_home(home: &Path) -> PathBuf {
    env::var_os("XDG_CONFIG_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".config"))
}

pub fn xdg_state_home(home: &Path) -> PathBuf {
    env::var_os("XDG_STATE_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".local/state"))
}

pub fn xdg_data_home(home: &Path) -> PathBuf {
    env::var_os("XDG_DATA_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".local/share"))
}

fn is_executable(path: &Path) -> bool {
    fs::metadata(path)
        .map(|m| m.is_file() && (m.permissions().mode() & 0o111 != 0))
        .unwrap_or(false)
}

pub fn which(name: &str) -> Option<PathBuf> {
    if name.contains('/') {
        let p = PathBuf::from(name);
        return is_executable(&p).then_some(p);
    }
    let path_var = env::var_os("PATH")?;
    for dir in env::split_paths(&path_var) {
        let candidate = dir.join(name);
        if is_executable(&candidate) {
            return Some(candidate);
        }
    }
    None
}

pub fn find_tool(home: &Path, name: &str) -> Option<String> {
    let managed = [
        home.join(".local/opt/dotfiles/bin"),
        home.join(".local/share/mise/shims"),
        home.join(".pixi/bin"),
        home.join(".local/share/pnpm/bin"),
        home.join(".local/bin"),
    ];
    for dir in &managed {
        let candidate = dir.join(name);
        if is_executable(&candidate) {
            return Some(candidate.to_string_lossy().into_owned());
        }
    }
    which(name).map(|p| p.to_string_lossy().into_owned())
}

pub fn run_capture(prog: &str, args: &[&str]) -> (i32, String, String) {
    match Command::new(prog)
        .args(args)
        .stdin(Stdio::null())
        .output()
    {
        Ok(out) => (
            out.status.code().unwrap_or(1),
            String::from_utf8_lossy(&out.stdout).trim().to_string(),
            String::from_utf8_lossy(&out.stderr).trim().to_string(),
        ),
        Err(err) => (127, String::new(), err.to_string()),
    }
}

pub fn load_chezmoi_data() -> Result<ChezmoiData, String> {
    if which("chezmoi").is_none() {
        return Err("chezmoi not found on PATH".to_string());
    }
    let (rc, out, err) = run_capture("chezmoi", &["data", "--format", "json"]);
    if rc != 0 {
        return Err(format!(
            "chezmoi data failed: {}",
            if err.is_empty() { out } else { err }
        ));
    }
    serde_json::from_str::<ChezmoiData>(&out).map_err(|e| format!("invalid chezmoi data: {e}"))
}

fn check_chezmoi() -> (ChezmoiCheck, Option<ChezmoiData>) {
    match load_chezmoi_data() {
        Err(detail) => (
            ChezmoiCheck {
                status: "error".to_string(),
                detail: Some(detail),
                machine: None,
                description: None,
                theme: None,
                bundles: Vec::new(),
                sudo: false,
                manage_system: false,
                source_path: None,
                drifted_count: 0,
                drifted: Vec::new(),
            },
            None,
        ),
        Ok(data) => {
            let m_info = data.machines.get(&data.machine);
            let bundles = m_info.map(|m| m.bundles.clone()).unwrap_or_default();
            let description = m_info.map(|m| m.description.clone()).unwrap_or_default();
            let sudo = m_info.map(|m| m.sudo).unwrap_or(false);
            let manage_system = m_info.map(|m| m.manage_system).unwrap_or(false);

            let (src_rc, src_out, _) = run_capture("chezmoi", &["source-path"]);
            let (st_rc, st_out, _) =
                run_capture("chezmoi", &["status", "--exclude", "externals"]);
            let drifted: Vec<String> = if st_rc == 0 {
                st_out
                    .lines()
                    .map(str::trim)
                    .filter(|l| !l.is_empty())
                    .map(ToString::to_string)
                    .collect()
            } else {
                Vec::new()
            };
            let drifted_count = drifted.len();
            let status = if drifted_count == 0 { "ok" } else { "warn" }.to_string();

            let check = ChezmoiCheck {
                status,
                detail: None,
                machine: Some(if data.machine.is_empty() {
                    "unknown".to_string()
                } else {
                    data.machine.clone()
                }),
                description: Some(description),
                theme: Some(if data.theme.is_empty() {
                    "unknown".to_string()
                } else {
                    data.theme.clone()
                }),
                bundles,
                sudo,
                manage_system,
                source_path: (src_rc == 0 && !src_out.is_empty()).then_some(src_out),
                drifted_count,
                drifted: drifted.into_iter().take(20).collect(),
            };
            (check, Some(data))
        }
    }
}

fn check_secrets(home: &Path, data: Option<&ChezmoiData>) -> (SecretsCheck, Option<PolicyFile>) {
    let in_jail = env::var("DOTFILES_AGENT_JAIL").as_deref() == Ok("1");
    let age_rel = data
        .map(|d| d.secrets.age_identity.as_str())
        .filter(|s| !s.is_empty())
        .unwrap_or(".config/chezmoi/key.txt");
    let age_path = home.join(age_rel);

    // Only stat metadata (existence and mode); never open or read private keys.
    let mut age_exists = false;
    let mut age_masked = false;
    let mut age_mode = None;
    if let Ok(meta) = fs::metadata(&age_path) {
        age_exists = true;
        if in_jail && meta.file_type().is_char_device() {
            age_masked = true;
            age_mode = Some("masked".to_string());
        } else {
            let mode = meta.mode() & 0o7777;
            age_mode = Some(format!("0o{mode:o}"));
        }
    }

    let ssh_dir = home.join(".ssh");
    let public_names: BTreeSet<&str> = [
        "config",
        "known_hosts",
        "known_hosts.old",
        "authorized_keys",
        "authorized_keys2",
    ]
    .into_iter()
    .collect();
    let mut loose_keys = Vec::new();
    if let Ok(entries) = fs::read_dir(&ssh_dir) {
        let mut names: Vec<_> = entries.flatten().collect();
        names.sort_by_key(|e| e.file_name());
        for entry in names {
            let name = entry.file_name().to_string_lossy().into_owned();
            if public_names.contains(name.as_str()) || name.ends_with(".pub") {
                continue;
            }
            if let Ok(meta) = fs::metadata(entry.path()) {
                if meta.is_dir() {
                    continue;
                }
                if in_jail && meta.file_type().is_char_device() {
                    continue;
                }
                let mode = meta.mode() & 0o7777;
                if mode & 0o077 != 0 {
                    loose_keys.push(LooseKey {
                        name,
                        mode: format!("0o{mode:o}"),
                    });
                }
            }
        }
    }

    let policy_path = xdg_config_home(home).join("dotfiles/policy.json");
    let policy = fs::read_to_string(&policy_path)
        .ok()
        .and_then(|txt| serde_json::from_str::<PolicyFile>(&txt).ok());
    let policy_ok = policy.is_some();

    let mut issues = Vec::new();
    let bad_age_mode = age_exists
        && !age_masked
        && !matches!(age_mode.as_deref(), Some("0o600") | Some("0o400"));
    if bad_age_mode {
        issues.push(format!(
            "age identity permissions {} (expected 0o600)",
            age_mode.as_deref().unwrap_or("?")
        ));
    }
    if !loose_keys.is_empty() {
        issues.push(format!(
            "{} ssh private key(s) readable by group/other",
            loose_keys.len()
        ));
    }
    if !policy_ok {
        issues.push("policy.json missing or invalid".to_string());
    }
    if age_exists && which("chezmoi").is_some() {
        let (rc, cfg_json, _) = run_capture("chezmoi", &["dump-config", "--format", "json"]);
        if rc == 0
            && let Ok(val) = serde_json::from_str::<serde_json::Value>(&cfg_json)
            && val.get("useBuiltinAge").and_then(|v| v.as_bool()) == Some(false)
        {
            issues.push(
                "chezmoi.toml has useBuiltinAge=false (run `chezmoi init` to avoid external age shim deadlock)"
                    .to_string(),
            );
        }
    }

    let status = if !loose_keys.is_empty() || bad_age_mode {
        "error"
    } else if !issues.is_empty() {
        "warn"
    } else {
        "ok"
    }
    .to_string();

    (
        SecretsCheck {
            status,
            age_identity_present: age_exists,
            age_identity_mode: age_mode,
            loose_ssh_keys: loose_keys,
            policy_json_valid: policy_ok,
            issues,
        },
        policy,
    )
}

fn check_toolchain(home: &Path, bundles: &[String], data: Option<&ChezmoiData>) -> ToolchainCheck {
    let pixi_bin = which("pixi")
        .map(|p| p.to_string_lossy().into_owned())
        .or_else(|| {
            let p = home.join(".pixi/bin/pixi");
            p.is_file().then(|| p.to_string_lossy().into_owned())
        });
    let mise_bin = which("mise")
        .map(|p| p.to_string_lossy().into_owned())
        .or_else(|| {
            let p = home.join(".pixi/bin/mise");
            p.is_file().then(|| p.to_string_lossy().into_owned())
        });

    let mut selected_mise = Vec::new();
    if let Some(d) = data {
        for b in bundles {
            if let Some(spec) = d.bundles.get(b) {
                for tool_id in &spec.mise {
                    if !selected_mise.contains(tool_id) {
                        selected_mise.push(tool_id.clone());
                    }
                }
            }
        }
    }

    let shims_dir = home.join(".local/share/mise/shims");
    let missing_mise: Vec<String> = selected_mise
        .iter()
        .filter(|t| {
            let bin_name = data
                .and_then(|d| d.mise.get(t.as_str()))
                .and_then(|s| s.bin.as_deref())
                .unwrap_or(t.as_str());
            !shims_dir.join(bin_name).exists()
        })
        .cloned()
        .collect();

    let state_dir = xdg_state_home(home).join("dotfiles");
    let pending: Vec<String> = ["mise-pending", "zotero-pending"]
        .into_iter()
        .filter(|name| state_dir.join(name).exists())
        .map(ToString::to_string)
        .collect();

    let shadow_path = home.join(".local/opt/dotfiles/bin/dotfiles");
    let shadow_dotfiles_bin = if shadow_path.exists() {
        Some(shadow_path.to_string_lossy().into_owned())
    } else {
        None
    };

    let mut issues = Vec::new();
    if !bundles.is_empty() && pixi_bin.is_none() {
        issues.push("pixi missing".to_string());
    }
    if !selected_mise.is_empty() && mise_bin.is_none() {
        issues.push("mise missing".to_string());
    }
    if !missing_mise.is_empty() {
        issues.push(format!("missing mise shims: {}", missing_mise.join(", ")));
    }
    if !pending.is_empty() {
        issues.push(format!("pending retries: {}", pending.join(", ")));
    }
    if shadow_dotfiles_bin.is_some() {
        issues.push(
            "local override ~/.local/opt/dotfiles/bin/dotfiles shadows mise shim; remove it (`rm -f ~/.local/opt/dotfiles/bin/dotfiles`)"
                .to_string(),
        );
    }

    let status =
        if (!selected_mise.is_empty() && mise_bin.is_none()) || (!bundles.is_empty() && pixi_bin.is_none()) {
            "error"
        } else if !issues.is_empty() {
            "warn"
        } else {
            "ok"
        }
        .to_string();

    ToolchainCheck {
        status,
        pixi: pixi_bin,
        mise: mise_bin,
        selected_mise_tools: selected_mise,
        missing_mise_shims: missing_mise,
        pending_markers: pending,
        shadow_dotfiles_bin,
        issues,
    }
}

pub fn check_git_credential_helper_issue(url: &str, helper: &str) -> Option<String> {
    let trimmed = helper.trim();
    if trimmed.is_empty() {
        return None;
    }
    if trimmed.contains("/.local/share/mise/installs/") || trimmed.contains("/.pixi/envs/") {
        return Some(format!(
            "versioned/ephemeral git credential helper for {url} (run `git config --global --unset-all credential.{url}.helper` to inherit ~/.config/git/config)"
        ));
    }
    if let Some(cmd) = trimmed.strip_prefix('!') {
        let first = cmd.split_whitespace().next().unwrap_or("");
        let bin = first.trim_matches(|c| c == '"' || c == '\'');
        if bin.starts_with('/') && !Path::new(bin).is_file() {
            return Some(format!(
                "missing git credential helper binary for {url}: {bin}"
            ));
        }
    }
    None
}

fn check_shell_and_git(home: &Path) -> ShellGitCheck {
    let xdg_cfg = xdg_config_home(home);
    let env_sh = xdg_cfg.join("dotfiles/env.sh").is_file();
    let git_cfg = xdg_cfg.join("git/config").is_file();

    let mut issues = Vec::new();
    let (diff_algo, diff_ext) = if which("git").is_some() {
        let (_, a, _) = run_capture("git", &["config", "--get", "diff.algorithm"]);
        let (_, e, _) = run_capture("git", &["config", "--get", "diff.external"]);
        for url in ["https://github.com", "https://gist.github.com"] {
            let key = format!("credential.{url}.helper");
            let (rc, helpers, _) = run_capture("git", &["config", "--get-all", &key]);
            if rc == 0 {
                for line in helpers.lines() {
                    if let Some(msg) = check_git_credential_helper_issue(url, line)
                        && !issues.contains(&msg)
                    {
                        issues.push(msg);
                    }
                }
            }
        }
        let (lfs_rc, lfs_req, _) = run_capture("git", &["config", "--get", "filter.lfs.required"]);
        if lfs_rc == 0 && lfs_req.eq_ignore_ascii_case("true") {
            issues.push(
                "git filter.lfs.required=true couples all repos to the git-lfs shim (run `git config --global filter.lfs.required false`)"
                    .to_string(),
            );
        }
        (
            (!a.is_empty()).then_some(a),
            (!e.is_empty()).then_some(e),
        )
    } else {
        (None, None)
    };

    let sbc_bin = xdg_data_home(home).join("sbc/cli/sbc");
    let sbc_route = if sbc_bin.is_file() {
        let (rc, out, _) = run_capture(&sbc_bin.to_string_lossy(), &["route"]);
        (rc == 0)
            .then(|| out.lines().next().map(|l| l.trim().to_string()))
            .flatten()
            .filter(|s| !s.is_empty())
    } else {
        None
    };

    if !env_sh {
        issues.push("~/.config/dotfiles/env.sh missing".to_string());
    }
    if !git_cfg {
        issues.push("~/.config/git/config missing".to_string());
    }

    ShellGitCheck {
        status: if issues.is_empty() { "ok" } else { "warn" }.to_string(),
        env_sh,
        git_xdg_config: git_cfg,
        git_diff_algorithm: diff_algo,
        git_diff_external: diff_ext,
        zoxide: find_tool(home, "zoxide"),
        sbc_route,
        issues,
    }
}

fn file_contains(path: &Path, needle: &str) -> bool {
    fs::read_to_string(path)
        .map(|s| s.contains(needle))
        .unwrap_or(false)
}

fn check_agents(home: &Path, bundles: &[String]) -> AgentsCheck {
    let has_bundle = bundles.iter().any(|b| b == "dev");
    let key_guard = is_executable(&home.join(".agents/hooks/key-guard.py"));
    let agent_notify = is_executable(&home.join(".agents/hooks/agent-notify.py"));
    let jail_bin = home.join(".local/libexec/dotfiles/agent-jail");

    let active_jail = if env::var("DOTFILES_AGENT_JAIL").as_deref() == Ok("1") {
        Some(
            env::var("DOTFILES_AGENT_JAIL_BACKEND")
                .ok()
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| "unknown".to_string()),
        )
    } else {
        None
    };

    let mut jail_backends = Vec::new();
    if active_jail.as_deref() == Some("bwrap") {
        jail_backends.push("bwrap".to_string());
    } else if which("bwrap").is_some() {
        let (rc, _, _) = run_capture(
            "bwrap",
            &[
                "--ro-bind",
                "/",
                "/",
                "--dev",
                "/dev",
                "--proc",
                "/proc",
                "--",
                "/bin/true",
            ],
        );
        if rc == 0 {
            jail_backends.push("bwrap".to_string());
        }
    }
    if jail_bin.is_file() {
        let jail_str = jail_bin.to_string_lossy().into_owned();
        let (rc, _, _) = run_capture(
            "python3",
            &[&jail_str, "--force", "--backend", "landlock", "--", "/bin/true"],
        );
        if rc == 0 {
            jail_backends.push("landlock".to_string());
        }
    }

    let mut agents = BTreeMap::new();
    agents.insert(
        "claude".to_string(),
        AgentEntry {
            binary: find_tool(home, "claude"),
            instructions: home.join(".claude/CLAUDE.md").exists(),
            key_guard_configured: Some(file_contains(
                &home.join(".claude/settings.json"),
                "key-guard.py",
            )),
            sandbox_profile: None,
            guard_extension: None,
        },
    );
    agents.insert(
        "codex".to_string(),
        AgentEntry {
            binary: find_tool(home, "codex"),
            instructions: home.join(".codex/AGENTS.md").exists(),
            key_guard_configured: Some(file_contains(
                &home.join(".codex/hooks.json"),
                "key-guard.py",
            )),
            sandbox_profile: Some(file_contains(
                &home.join(".codex/config.toml"),
                "default_permissions = \"key-guard\"",
            )),
            guard_extension: None,
        },
    );
    agents.insert(
        "agy".to_string(),
        AgentEntry {
            binary: find_tool(home, "agy"),
            instructions: home.join(".gemini/AGENTS.md").exists(),
            key_guard_configured: Some(file_contains(
                &home.join(".gemini/config/hooks.json"),
                "key-guard.py",
            )),
            sandbox_profile: None,
            guard_extension: None,
        },
    );
    agents.insert(
        "pi".to_string(),
        AgentEntry {
            binary: find_tool(home, "pi"),
            instructions: home.join(".pi/agent/AGENTS.md").exists(),
            key_guard_configured: None,
            sandbox_profile: None,
            guard_extension: Some(home.join(".pi/agent/extensions/dotfiles-guard.ts").is_file()),
        },
    );

    let mut issues = Vec::new();
    if has_bundle {
        if !key_guard {
            issues.push("key-guard.py missing or not executable".to_string());
        }
        if !agent_notify {
            issues.push("agent-notify.py missing or not executable".to_string());
        }
        if jail_backends.is_empty() {
            issues.push("no active agent-jail backend (bwrap/landlock)".to_string());
        }
        for (name, info) in &agents {
            if info.binary.is_some() && !info.instructions {
                issues.push(format!("{name}: missing AGENTS/CLAUDE instructions link"));
            }
            if info.binary.is_some()
                && matches!(name.as_str(), "claude" | "codex" | "agy")
                && info.key_guard_configured != Some(true)
            {
                issues.push(format!("{name}: key-guard hook not configured"));
            }
            if info.binary.is_some() && name == "pi" && info.guard_extension != Some(true) {
                issues.push("pi: dotfiles-guard.ts extension missing".to_string());
            }
        }
    }

    AgentsCheck {
        status: if issues.is_empty() { "ok" } else { "warn" }.to_string(),
        agent_tools_selected: has_bundle,
        key_guard,
        agent_notify,
        agent_jail_backends: jail_backends,
        active_jail,
        agents,
        issues,
    }
}

fn load_fetch_items(home: &Path, bundles: &[String], data: Option<&ChezmoiData>) -> Vec<FetchItemStatus> {
    let mut selected_ids = BTreeSet::new();
    if let Some(d) = data {
        for b in bundles {
            if let Some(spec) = d.bundles.get(b) {
                for id in &spec.downloads {
                    selected_ids.insert(id.clone());
                }
            }
        }
    }
    let opt_root = home.join(".local/opt/dotfiles");
    let font_root = home.join(".local/share/fonts/dotfiles");
    let mut items = Vec::new();
    if let Some(d) = data {
        for (id, spec) in &d.downloads {
            let is_font = spec.fonts.is_some();
            let kind = if is_font { "font" } else { "app" }.to_string();
            let source = if let Some(gh) = &spec.github {
                if let Some(tag) = &spec.tag {
                    format!("github:{gh}@{tag}")
                } else {
                    format!("github:{gh}")
                }
            } else if spec.manifest.is_some() {
                "manifest".to_string()
            } else {
                "url".to_string()
            };
            let installed_version = if is_font {
                let fdir = font_root.join(id);
                let marker = opt_root.join(id).join("current");
                if let Ok(target) = fs::read_link(&marker) {
                    target
                        .file_name()
                        .map(|n| n.to_string_lossy().into_owned())
                } else if fdir.is_dir() {
                    Some("installed".to_string())
                } else {
                    None
                }
            } else {
                let current = opt_root.join(id).join("current");
                fs::read_link(&current)
                    .ok()
                    .and_then(|t| t.file_name().map(|n| n.to_string_lossy().into_owned()))
            };
            items.push(FetchItemStatus {
                id: id.clone(),
                kind,
                source,
                installed_version,
                selected: selected_ids.contains(id),
            });
        }
    }
    items.sort_by(|a, b| b.selected.cmp(&a.selected).then_with(|| a.id.cmp(&b.id)));
    items
}

const MIGRATED_SBIN_TO_LIBEXEC: [(&str, &str); 3] = [
    ("/usr/local/sbin/bt-autoenable", "/usr/local/libexec/bt-autoenable"),
    ("/usr/local/sbin/power-tunables", "/usr/local/libexec/power-tunables"),
    ("/usr/local/sbin/dgpu-display", "/usr/local/libexec/dgpu-display"),
];

fn walk_system_root(root: &Path, cur: &Path, out: &mut BTreeMap<String, (PathBuf, u32)>) {
    let Ok(entries) = fs::read_dir(cur) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let Ok(meta) = entry.metadata() else {
            continue;
        };
        if meta.is_dir() {
            if entry.file_name() == "__pycache__" {
                continue;
            }
            walk_system_root(root, &path, out);
        } else if meta.is_file() {
            let Ok(rel) = path.strip_prefix(root) else {
                continue;
            };
            let rel_str = rel.to_string_lossy();
            if rel_str.ends_with(".pyc") || rel_str.ends_with(".pyo") {
                continue;
            }
            let dst = format!("/{rel_str}");
            let mode = if (meta.permissions().mode() & 0o100) != 0 {
                0o755
            } else {
                0o644
            };
            out.insert(dst, (path, mode));
        }
    }
}

fn check_system(chezmoi: &ChezmoiCheck, data: Option<&ChezmoiData>) -> SystemCheck {
    if !chezmoi.sudo || !chezmoi.manage_system {
        let reason = if !chezmoi.sudo {
            "rootless host"
        } else {
            "personal ~ only (manageSystem=false)"
        };
        return SystemCheck {
            status: "ok".to_string(),
            skipped: true,
            skip_reason: Some(reason.to_string()),
            managed_files: 0,
            drifted_files: Vec::new(),
            selected_system_packages: Vec::new(),
            missing_packages: Vec::new(),
            stale_sbin_files: Vec::new(),
            issues: Vec::new(),
        };
    }

    let mut merged: BTreeMap<String, (PathBuf, u32)> = BTreeMap::new();
    if let (Some(src_root), Some(machine)) = (&chezmoi.source_path, &chezmoi.machine) {
        let sys_dir = Path::new(src_root).join("system");
        for b in &chezmoi.bundles {
            if b != machine {
                let root = sys_dir.join(b);
                if root.is_dir() {
                    walk_system_root(&root, &root, &mut merged);
                }
            }
        }
        let machine_root = sys_dir.join(machine);
        if machine_root.is_dir() {
            walk_system_root(&machine_root, &machine_root, &mut merged);
        }
    }

    let mut drifted_files = Vec::new();
    for (dst, (src, expected_mode)) in &merged {
        let dst_path = Path::new(dst);
        let matches = match (fs::metadata(dst_path), fs::read(dst_path), fs::read(src)) {
            (Ok(meta), Ok(dst_bytes), Ok(src_bytes)) => {
                (meta.permissions().mode() & 0o777) == *expected_mode && dst_bytes == src_bytes
            }
            _ => false,
        };
        if !matches {
            drifted_files.push(dst.clone());
        }
    }

    let mut selected_set = BTreeSet::new();
    if let Some(d) = data {
        for b in &chezmoi.bundles {
            if let Some(spec) = d.bundles.get(b) {
                for pkg in &spec.system_packages {
                    selected_set.insert(pkg.clone());
                }
            }
        }
    }
    let selected_system_packages: Vec<String> = selected_set.into_iter().collect();

    let mut missing_packages = Vec::new();
    if let Some(d) = data {
        for pkg in &selected_system_packages {
            if let Some(spec) = d.system_packages.get(pkg) {
                let present = spec.probe.iter().any(|p| Path::new(p).exists());
                if !present {
                    missing_packages.push(pkg.clone());
                }
            }
        }
    }

    let mut stale_sbin_files = Vec::new();
    for (old_sbin, new_libexec) in MIGRATED_SBIN_TO_LIBEXEC {
        if merged.contains_key(new_libexec)
            && Path::new(new_libexec).is_file()
            && Path::new(old_sbin).exists()
        {
            stale_sbin_files.push(old_sbin.to_string());
        }
    }

    let mut issues = Vec::new();
    if !drifted_files.is_empty() {
        issues.push(format!(
            "{} system/ file(s) differ from / (run `sudo -v && chezmoi apply`): {}",
            drifted_files.len(),
            drifted_files.join(", ")
        ));
    }
    if !missing_packages.is_empty() {
        issues.push(format!(
            "missing system_packages (run `sudo -v && chezmoi apply`): {}",
            missing_packages.join(", ")
        ));
    }
    if !stale_sbin_files.is_empty() {
        issues.push(format!(
            "superseded /usr/local/sbin files remain; remove with `sudo rm -f {}`",
            stale_sbin_files.join(" ")
        ));
    }

    let status = if issues.is_empty() { "ok" } else { "warn" }.to_string();
    SystemCheck {
        status,
        skipped: false,
        skip_reason: None,
        managed_files: merged.len(),
        drifted_files,
        selected_system_packages,
        missing_packages,
        stale_sbin_files,
        issues,
    }
}

pub fn build_snapshot() -> FullSnapshot {
    let home = home_dir();
    let (chezmoi, data) = check_chezmoi();
    let bundles = chezmoi.bundles.clone();
    let (secrets, policy) = check_secrets(&home, data.as_ref());
    let toolchain = check_toolchain(&home, &bundles, data.as_ref());
    let shell_git = check_shell_and_git(&home);
    let agents = check_agents(&home, &bundles);
    let system = check_system(&chezmoi, data.as_ref());
    let fetch_items = load_fetch_items(&home, &bundles, data.as_ref());
    let host = crate::host::collect_report(&bundles);

    let statuses = [
        chezmoi.status.as_str(),
        secrets.status.as_str(),
        toolchain.status.as_str(),
        shell_git.status.as_str(),
        agents.status.as_str(),
        system.status.as_str(),
    ];
    let overall = if statuses.contains(&"error") {
        "error"
    } else if statuses.contains(&"warn") {
        "warn"
    } else {
        "ok"
    }
    .to_string();

    let report = DoctorReport {
        status: overall,
        checks: DoctorChecks {
            chezmoi,
            secrets,
            toolchain,
            shell_git,
            agents,
            system,
        },
    };

    FullSnapshot {
        data,
        policy,
        report,
        fetch_items,
        host,
    }
}

pub fn print_doctor_pretty(report: &DoctorReport) {
    let use_color = std::io::IsTerminal::is_terminal(&std::io::stdout())
        && env::var_os("NO_COLOR").is_none();
    let (bold, dim, green, yellow, red, cyan, reset) = if use_color {
        ("\x1b[1m", "\x1b[2m", "\x1b[32m", "\x1b[33m", "\x1b[31m", "\x1b[36m", "\x1b[0m")
    } else {
        ("", "", "", "", "", "", "")
    };

    let status_color = match report.status.as_str() {
        "ok" => green,
        "warn" => yellow,
        _ => red,
    };

    println!(
        "{bold}dotfiles doctor:{reset} {status_color}{bold}{}{reset}",
        report.status.to_uppercase()
    );
    let cz = &report.checks.chezmoi;
    if let Some(machine) = &cz.machine {
        println!(
            "  {dim}machine{reset}    {cyan}{bold}{machine}{reset} ({}) — {}",
            cz.theme.as_deref().unwrap_or("unknown"),
            cz.description.as_deref().unwrap_or("")
        );
        let b = if cz.bundles.is_empty() {
            "(none)".to_string()
        } else {
            cz.bundles.join(" ")
        };
        println!("  {dim}bundles{reset}    {b}");
    }
    println!();

    let badge = |s: &str| match s {
        "ok" => format!("{green}[OK  ]{reset}"),
        "warn" => format!("{yellow}[WARN]{reset}"),
        "error" => format!("{red}[ERR ]{reset}"),
        other => format!("[{other}]"),
    };

    // chezmoi
    let cz_summary = if let Some(detail) = &cz.detail {
        detail.clone()
    } else if cz.drifted_count == 0 {
        "clean".to_string()
    } else {
        format!("{} drifted/pending target(s)", cz.drifted_count)
    };
    println!("  {} {:<10} {}", badge(&cz.status), "chezmoi", cz_summary);
    for item in cz.drifted.iter().take(5) {
        println!("          {dim}-{reset} {item}");
    }
    if cz.drifted.len() > 5 {
        println!("          {dim}- ... ({} more){reset}", cz.drifted.len() - 5);
    }

    // secrets
    let sec = &report.checks.secrets;
    let age_state = if sec.age_identity_present { "present" } else { "absent" };
    let sec_summary = format!(
        "age key {age_state} ({}) | {}",
        sec.age_identity_mode.as_deref().unwrap_or("-"),
        if sec.policy_json_valid { "policy.json ok" } else { "policy.json missing" }
    );
    println!("  {} {:<10} {}", badge(&sec.status), "secrets", sec_summary);
    for issue in &sec.issues {
        println!("          {dim}-{reset} {issue}");
    }

    // toolchain
    let tc = &report.checks.toolchain;
    let mut tc_parts = vec![format!("mise tools: {}", tc.selected_mise_tools.len())];
    if !tc.pending_markers.is_empty() {
        tc_parts.push(format!("pending: {}", tc.pending_markers.join(", ")));
    }
    println!("  {} {:<10} {}", badge(&tc.status), "toolchain", tc_parts.join(" | "));
    for issue in &tc.issues {
        println!("          {dim}-{reset} {issue}");
    }

    // shell_git
    let sg = &report.checks.shell_git;
    let mut sg_parts = vec![format!(
        "git diff={}",
        sg.git_diff_algorithm.as_deref().unwrap_or("?")
    )];
    if let Some(route) = &sg.sbc_route {
        sg_parts.push(format!("sbc: {route}"));
    }
    println!("  {} {:<10} {}", badge(&sg.status), "shell_git", sg_parts.join(" | "));
    for issue in &sg.issues {
        println!("          {dim}-{reset} {issue}");
    }

    // agents
    let ag = &report.checks.agents;
    let installed: Vec<&str> = ["claude", "codex", "agy", "pi"]
        .into_iter()
        .filter(|name| ag.agents.get(*name).and_then(|a| a.binary.as_ref()).is_some())
        .collect();
    let inst_str = if installed.is_empty() {
        "none".to_string()
    } else {
        installed.join(", ")
    };
    let mut jail_str = if ag.agent_jail_backends.is_empty() {
        "none".to_string()
    } else {
        ag.agent_jail_backends.join(", ")
    };
    if let Some(active) = &ag.active_jail {
        jail_str.push_str(&format!(" (active: {active})"));
    }
    println!(
        "  {} {:<10} installed: {} | jail: {}",
        badge(&ag.status),
        "agents",
        inst_str,
        jail_str
    );
    for issue in &ag.issues {
        println!("          {dim}-{reset} {issue}");
    }

    // system
    let sys = &report.checks.system;
    let sys_summary = if sys.skipped {
        format!(
            "{} (skipped)",
            sys.skip_reason.as_deref().unwrap_or("unmanaged")
        )
    } else {
        format!(
            "files: {} ({} drifted) | pkgs: {} ({} missing)",
            sys.managed_files,
            sys.drifted_files.len(),
            sys.selected_system_packages.len(),
            sys.missing_packages.len()
        )
    };
    println!("  {} {:<10} {}", badge(&sys.status), "system", sys_summary);
    for issue in &sys.issues {
        println!("          {dim}-{reset} {issue}");
    }
}
