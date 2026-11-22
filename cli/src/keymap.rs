use crate::doctor::{run_capture, which};
use anyhow::Result;
use clap::Subcommand;
use serde::Serialize;
use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

pub const KEYD_UNIT: &str = "keyd.service";
pub const KEYD_CONFIG_PATH: &str = "/etc/keyd/default.conf";
const POLKIT_RULE_PATH: &str = "/usr/share/polkit-1/rules.d/60-dotfiles-keyd.rules";

/// Bitmask for Q..=P (Linux keycodes 16..=25) and A..=L (30..=38) in the lowest
/// 64-bit word of `/proc/bus/input/devices`'s `B: KEY=` bitmap.
const ALPHA_KEY_MASK: u64 = (0x3ff_u64 << 16) | (0x1ff_u64 << 30);

#[derive(Subcommand, Debug)]
pub enum KeymapAction {
    /// Show keyd service state, config status, and connected keyboards (default)
    Status {
        /// Emit machine-readable JSON
        #[arg(long)]
        json: bool,
    },
    /// Enable the HHKB keymap (start keyd.service)
    On,
    /// Disable the HHKB keymap and restore standard keys (stop keyd.service)
    Off,
    /// Toggle between HHKB keymap and standard keys
    Toggle,
    /// Reload /etc/keyd/default.conf into a running keyd service
    Reload,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct KeyboardDevice {
    pub id: String,
    pub name: String,
    pub internal: bool,
    pub excluded: bool,
    pub state: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct KeymapReport {
    pub installed: bool,
    pub active: bool,
    pub enabled: Option<bool>,
    pub service_state: String,
    pub config_path: String,
    pub config_present: bool,
    pub polkit_rule_path: String,
    pub polkit_rule_present: bool,
    pub excluded_ids: Vec<String>,
    pub keyboards: Vec<KeyboardDevice>,
}

pub fn cmd_keymap(action: Option<KeymapAction>) -> Result<i32> {
    match action.unwrap_or(KeymapAction::Status { json: false }) {
        KeymapAction::Status { json } => cmd_status(json),
        KeymapAction::On => cmd_set(true),
        KeymapAction::Off => cmd_set(false),
        KeymapAction::Toggle => {
            if !keyd_installed() {
                print_install_hint();
                return Ok(1);
            }
            cmd_set(!keyd_active())
        }
        KeymapAction::Reload => cmd_reload(),
    }
}

fn find_keyd_bin() -> Option<std::path::PathBuf> {
    // Debian/Ubuntu packages keyd as `keyd.rvaiya` to avoid conflicting with
    // `onak` (Debian bug #1098982); upstream/other distros ship `keyd`.
    which("keyd.rvaiya").or_else(|| which("keyd"))
}

pub fn keyd_installed() -> bool {
    find_keyd_bin().is_some()
}

fn keyd_service_state() -> String {
    if which("systemctl").is_none() {
        return "unavailable".to_string();
    }
    let (_, out, _) = run_capture("systemctl", &["is-active", KEYD_UNIT]);
    if out.is_empty() {
        "unknown".to_string()
    } else {
        out
    }
}

pub fn keyd_active() -> bool {
    keyd_service_state() == "active"
}

fn keyd_enabled() -> Option<bool> {
    which("systemctl")?;
    let (rc, out, _) = run_capture("systemctl", &["is-enabled", KEYD_UNIT]);
    match out.as_str() {
        "enabled" | "enabled-runtime" => Some(true),
        "disabled" | "masked" | "static" => Some(false),
        _ if rc == 0 => Some(true),
        _ => None,
    }
}

fn print_install_hint() {
    eprintln!("dotfiles host keymap: keyd is not installed.");
    eprintln!("Install and activate automatically on desktop hosts with:");
    eprintln!("  sudo -v && chezmoi apply");
}

pub fn collect_report() -> KeymapReport {
    let installed = keyd_installed();
    let service_state = if installed {
        keyd_service_state()
    } else {
        "not-installed".to_string()
    };
    let active = installed && service_state == "active";
    let enabled = if installed { keyd_enabled() } else { None };
    let config_present = Path::new(KEYD_CONFIG_PATH).is_file();
    let polkit_rule_present = Path::new(POLKIT_RULE_PATH).is_file();

    let excluded_set = fs::read_to_string(KEYD_CONFIG_PATH)
        .map(|text| parse_keyd_exclusions(&text))
        .unwrap_or_default();
    let keyboards = fs::read_to_string("/proc/bus/input/devices")
        .map(|text| parse_input_keyboards(&text, &excluded_set, active))
        .unwrap_or_default();

    KeymapReport {
        installed,
        active,
        enabled,
        service_state,
        config_path: KEYD_CONFIG_PATH.to_string(),
        config_present,
        polkit_rule_path: POLKIT_RULE_PATH.to_string(),
        polkit_rule_present,
        excluded_ids: excluded_set.into_iter().collect(),
        keyboards,
    }
}

fn cmd_status(json_out: bool) -> Result<i32> {
    let report = collect_report();
    if json_out {
        println!("{}", serde_json::to_string_pretty(&report)?);
        return Ok(0);
    }

    let summary = if !report.installed {
        "not installed".to_string()
    } else if report.active {
        "on (HHKB remap active)".to_string()
    } else {
        format!("off (standard keyboard; unit={})", report.service_state)
    };
    println!("keymap (keyd): {summary}");
    if report.installed {
        let boot = match report.enabled {
            Some(true) => "enabled",
            Some(false) => "disabled",
            None => "unknown",
        };
        println!("boot:          {boot}");
    }
    println!(
        "config:        {} ({})",
        report.config_path,
        if report.config_present { "present" } else { "missing" }
    );
    println!(
        "polkit rule:   {} ({})",
        report.polkit_rule_path,
        if report.polkit_rule_present {
            "present"
        } else {
            "missing"
        }
    );

    if !report.keyboards.is_empty() {
        println!("keyboards:");
        for kb in &report.keyboards {
            let tag = if kb.internal { " (internal)" } else { "" };
            println!("  {:<9} {}{} [{}]", kb.id, kb.name, tag, kb.state);
        }
    }

    if !report.installed || !report.config_present || !report.polkit_rule_present {
        println!("hint:          sudo -v && chezmoi apply");
    }
    Ok(0)
}

/// Attempt to control `keyd.service` without prompting for a password (succeeds
/// inline on active local desktop sessions once the polkit rule is installed).
pub fn try_manage_unit_passwordless(verb: &str) -> Result<bool> {
    if which("systemctl").is_none() {
        return Ok(false);
    }
    let direct = Command::new("systemctl")
        .args(["--no-ask-password", verb, KEYD_UNIT])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    Ok(direct.success())
}

fn manage_keyd_unit(verb: &str) -> Result<i32> {
    if which("systemctl").is_none() {
        eprintln!("dotfiles keymap: systemctl not found on PATH");
        return Ok(1);
    }

    // Prefer passwordless polkit auth on an active local desktop session.
    let direct = Command::new("systemctl")
        .args(["--no-ask-password", verb, KEYD_UNIT])
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output()?;
    if direct.status.success() {
        return Ok(0);
    }

    // Fall back to interactive sudo (for SSH sessions or before polkit rule install).
    if which("sudo").is_some() {
        let status = Command::new("sudo")
            .args(["systemctl", verb, KEYD_UNIT])
            .status()?;
        return Ok(status.code().unwrap_or(1));
    }

    let err = String::from_utf8_lossy(&direct.stderr);
    if !err.trim().is_empty() {
        eprintln!("dotfiles keymap: {}", err.trim());
    }
    Ok(direct.status.code().unwrap_or(1))
}

fn maybe_notify(summary: &str, body: &str) {
    if env::var_os("WAYLAND_DISPLAY").is_none() && env::var_os("DISPLAY").is_none() {
        return;
    }
    if which("notify-send").is_none() {
        return;
    }
    let _ = Command::new("notify-send")
        .args(["-a", "dotfiles", "-t", "2500", summary, body])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

pub fn notify_state(enabled: bool) {
    if enabled {
        maybe_notify("Keymap: HHKB", "CapsLock = Left Ctrl, Right Ctrl = Fn");
    } else {
        maybe_notify("Keymap: Standard", "HHKB remap disabled");
    }
}

fn cmd_set(enable: bool) -> Result<i32> {
    if !keyd_installed() {
        print_install_hint();
        return Ok(1);
    }
    if enable && !Path::new(KEYD_CONFIG_PATH).is_file() {
        eprintln!(
            "dotfiles keymap: {KEYD_CONFIG_PATH} is missing; run 'sudo -v && chezmoi apply' first."
        );
        return Ok(1);
    }

    let currently_active = keyd_active();
    if enable && currently_active {
        println!("keymap (keyd): already on (HHKB remap active)");
        return Ok(0);
    }
    if !enable && !currently_active {
        println!("keymap (keyd): already off (standard keyboard)");
        return Ok(0);
    }

    let verb = if enable { "start" } else { "stop" };
    let rc = manage_keyd_unit(verb)?;
    if rc != 0 {
        return Ok(rc);
    }

    if enable {
        println!("keymap (keyd): on (HHKB remap active)");
    } else {
        println!("keymap (keyd): off (standard keyboard)");
    }
    notify_state(enable);
    Ok(0)
}

fn cmd_reload() -> Result<i32> {
    if !keyd_installed() {
        print_install_hint();
        return Ok(1);
    }
    if !Path::new(KEYD_CONFIG_PATH).is_file() {
        eprintln!(
            "dotfiles keymap: {KEYD_CONFIG_PATH} is missing; run 'sudo -v && chezmoi apply' first."
        );
        return Ok(1);
    }

    if !keyd_active() {
        println!("keymap (keyd): keyd is currently off (run `dotfiles host keymap on`)");
        return Ok(0);
    }

    let rc = manage_keyd_unit("restart")?;
    if rc == 0 {
        println!("keymap (keyd): reloaded {KEYD_CONFIG_PATH}");
    }
    Ok(rc)
}

/// Extract excluded `vvvv:pppp` IDs from the `[ids]` section of a keyd config.
pub fn parse_keyd_exclusions(content: &str) -> BTreeSet<String> {
    let mut in_ids = false;
    let mut excluded = BTreeSet::new();
    for raw in content.lines() {
        let line = raw.split('#').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        if line.starts_with('[') && line.ends_with(']') {
            in_ids = line == "[ids]";
            continue;
        }
        if !in_ids {
            continue;
        }
        if let Some(rest) = line.strip_prefix('-') {
            let trimmed = rest
                .trim()
                .strip_prefix("k:")
                .or_else(|| rest.trim().strip_prefix("m:"))
                .unwrap_or_else(|| rest.trim())
                .to_ascii_lowercase();
            let mut parts = trimmed.split(':');
            if let (Some(vid), Some(pid)) = (parts.next(), parts.next())
                && vid.len() == 4
                && pid.len() == 4
                && vid.chars().all(|c| c.is_ascii_hexdigit())
                && pid.chars().all(|c| c.is_ascii_hexdigit())
            {
                excluded.insert(format!("{vid}:{pid}"));
            }
        }
    }
    excluded
}

/// Parse `/proc/bus/input/devices` and list physical typing keyboards.
pub fn parse_input_keyboards(
    content: &str,
    excluded_ids: &BTreeSet<String>,
    keyd_active: bool,
) -> Vec<KeyboardDevice> {
    let mut devices = Vec::new();
    let mut seen = BTreeSet::new();

    for block in content.split("\n\n") {
        let mut bus = String::new();
        let mut vendor = String::new();
        let mut product = String::new();
        let mut name = String::new();
        let mut handlers = String::new();
        let mut key_bitmap = String::new();

        for line in block.lines() {
            if let Some(rest) = line.strip_prefix("I: ") {
                for tok in rest.split_whitespace() {
                    if let Some(v) = tok.strip_prefix("Bus=") {
                        bus = v.to_ascii_lowercase();
                    } else if let Some(v) = tok.strip_prefix("Vendor=") {
                        vendor = v.to_ascii_lowercase();
                    } else if let Some(v) = tok.strip_prefix("Product=") {
                        product = v.to_ascii_lowercase();
                    }
                }
            } else if let Some(rest) = line.strip_prefix("N: Name=") {
                name = rest.trim().trim_matches('"').to_string();
            } else if let Some(rest) = line.strip_prefix("H: Handlers=") {
                handlers = rest.trim().to_string();
            } else if let Some(rest) = line.strip_prefix("B: KEY=") {
                key_bitmap = rest.trim().to_string();
            }
        }

        if vendor.is_empty() || product.is_empty() || vendor == "0000" {
            continue;
        }
        let tokens: Vec<&str> = handlers.split_whitespace().collect();
        if !tokens.contains(&"kbd")
            || tokens.contains(&"rfkill")
            || tokens.iter().any(|t| t.starts_with("mouse"))
        {
            continue;
        }
        let Some(low_hex) = key_bitmap.split_whitespace().last() else {
            continue;
        };
        let Ok(low_word) = u64::from_str_radix(low_hex, 16) else {
            continue;
        };
        if (low_word & ALPHA_KEY_MASK) != ALPHA_KEY_MASK {
            continue;
        }

        let id = format!("{vendor}:{product}");
        if !seen.insert((id.clone(), name.clone())) {
            continue;
        }
        let internal = bus == "0011";
        let excluded = excluded_ids.contains(&id);
        let state = if excluded {
            "excluded"
        } else if keyd_active {
            "remapped"
        } else {
            "standard"
        };
        devices.push(KeyboardDevice {
            id,
            name,
            internal,
            excluded,
            state: state.to_string(),
        });
    }

    devices
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_keyd_exclusions_ignoring_comments_and_other_sections() {
        let cfg = r#"
[ids]
*
-046d:b023   # MX Master 3
-k:0853:0100 # HHKB
-m:1234:5678:abcd1234
# -aaaa:bbbb

[main]
-9999:9999
capslock = leftcontrol
"#;
        let ids = parse_keyd_exclusions(cfg);
        assert!(ids.contains("046d:b023"));
        assert!(ids.contains("0853:0100"));
        assert!(ids.contains("1234:5678"));
        assert!(!ids.contains("aaaa:bbbb"));
        assert!(!ids.contains("9999:9999"));
    }

    #[test]
    fn parses_proc_input_devices_and_filters_mice_and_virtual() {
        let sample = r#"I: Bus=0019 Vendor=0000 Product=0001 Version=0000
N: Name="Power Button"
H: Handlers=kbd event1
B: KEY=8000 10000000000000 0

I: Bus=0011 Vendor=0001 Product=0001 Version=ab83
N: Name="AT Translated Set 2 keyboard"
H: Handlers=sysrq kbd event3 leds
B: KEY=402000007 ff803078f800d001 feffffdfffcfffff fffffffffffffffe

I: Bus=0003 Vendor=1a81 Product=2038 Version=0111
N: Name="USB Keyboard USB Keyboard"
H: Handlers=sysrq kbd event8 leds
B: KEY=1000000000007 ff9f207ac14057ff febeffdfffefffff fffffffffffffffe

I: Bus=0003 Vendor=1a81 Product=2038 Version=0111
N: Name="USB Keyboard USB Keyboard"
H: Handlers=kbd event9
B: KEY=3f00733fff 0 0 483ffff17aff32d bfd4444600000000 1 130ff38b17d000 7fe77bfad9415fed 81beffcd01cfffff febffbffdffffffe

I: Bus=0003 Vendor=0853 Product=0100 Version=0111
N: Name="PFU Limited HHKB"
H: Handlers=sysrq kbd event10 leds
B: KEY=1000000000007 ff9f207ac14057ff febeffdfffefffff fffffffffffffffe

I: Bus=0005 Vendor=046d Product=b023 Version=0015
N: Name="Logitech Wireless Mouse MX Master 3"
H: Handlers=sysrq kbd mouse2 event24
B: KEY=ffff0000 1000000000007 ff800000000007ff febeffdfffefffff fffffffffffffffe

I: Bus=0000 Vendor=0000 Product=0000 Version=0000
N: Name="keyd virtual keyboard"
H: Handlers=sysrq kbd event25 leds
B: KEY=ffffffffffffffff fffffffffffffffe
"#;
        let excluded: BTreeSet<String> = ["0853:0100".to_string()].into_iter().collect();
        let kbs = parse_input_keyboards(sample, &excluded, true);
        assert_eq!(kbs.len(), 3);
        assert_eq!(kbs[0].id, "0001:0001");
        assert!(kbs[0].internal);
        assert_eq!(kbs[0].state, "remapped");

        assert_eq!(kbs[1].id, "1a81:2038");
        assert!(!kbs[1].internal);
        assert_eq!(kbs[1].state, "remapped");

        assert_eq!(kbs[2].id, "0853:0100");
        assert!(kbs[2].excluded);
        assert_eq!(kbs[2].state, "excluded");
    }
}
