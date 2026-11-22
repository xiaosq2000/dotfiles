use crate::doctor::{load_chezmoi_data, run_capture, which};
use crate::keymap::{self, KeymapAction, KeymapReport};
use anyhow::Result;
use clap::Subcommand;
use serde::Serialize;
use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

pub const DGPU_HELPER_PATH: &str = "/usr/local/libexec/dgpu-display";
pub const BATTERY_CHARGE_TYPES_PATH: &str = "/sys/class/power_supply/BAT0/charge_types";
pub const BATTERY_FULL_MARKER: &str = "/var/lib/dotfiles/battery-full";
pub const BATTERY_LIMIT_UNIT: &str = "battery-charge-limit.service";
pub const REFRESH_USER_UNIT: &str = "refresh-rate-on-power.service";
pub const LOGID_UNIT: &str = "logid.service";
pub const LOGID_CONFIG_PATH: &str = "/etc/logid.cfg";

#[derive(Subcommand, Debug)]
pub enum HostAction {
    /// Show status of personal host hardware/system controls on this machine (default)
    Status {
        /// Emit machine-readable JSON
        #[arg(long)]
        json: bool,
    },
    /// Toggle or inspect the HHKB-style keyd keyboard remap (desktop)
    Keymap {
        #[command(subcommand)]
        action: Option<KeymapAction>,
    },
    /// Switch whether GNOME drives displays from the NVIDIA dGPU (laptop)
    Dgpu {
        #[command(subcommand)]
        action: Option<DgpuAction>,
    },
    /// Switch persistent battery charge cap between 80% (limit) and 100% (full)
    Battery {
        #[command(subcommand)]
        action: Option<BatteryAction>,
    },
    /// Control the 60 Hz-on-battery display refresh user service (laptop)
    Refresh {
        #[command(subcommand)]
        action: Option<RefreshAction>,
    },
    /// Inspect or restart the Logitech MX Master daemon (logid)
    Logid {
        #[command(subcommand)]
        action: Option<LogidAction>,
    },
}

#[derive(Subcommand, Debug)]
pub enum DgpuAction {
    /// Show dGPU display setting, GNOME state, and D3cold power telemetry (default)
    Status,
    /// Allow GNOME to drive HDMI/DisplayPort via the NVIDIA dGPU
    On,
    /// Have GNOME ignore the dGPU so it sleeps in D3cold (~8 W savings)
    Off,
}

#[derive(Subcommand, Debug)]
pub enum BatteryAction {
    /// Show persistent cap setting and live BAT0/charge_types state (default)
    Status,
    /// Cap charging near 80% (Long_Life; survives suspend and reboot)
    Limit,
    /// Allow charging to 100% (Standard; persists until `battery limit`)
    Full,
}

#[derive(Subcommand, Debug)]
pub enum RefreshAction {
    /// Show refresh-rate-on-power.service user unit status (default)
    Status,
    /// Start refresh-rate-on-power.service
    On,
    /// Stop refresh-rate-on-power.service
    Off,
    /// Toggle refresh-rate-on-power.service
    Toggle,
}

#[derive(Subcommand, Debug)]
pub enum LogidAction {
    /// Show logid.service and /etc/logid.cfg status (default)
    Status,
    /// Restart logid.service via sudo
    Restart,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct DgpuStatus {
    pub helper_present: bool,
    pub pci: Option<String>,
    pub setting: String,
    pub gnome: String,
    pub power: String,
    pub open_by: String,
    pub advice: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct BatteryStatus {
    pub available: bool,
    pub persistent_mode: String,
    pub live_mode: Option<String>,
    pub available_modes: Vec<String>,
    pub service_enabled: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct RefreshStatus {
    pub unit_present: bool,
    pub active: bool,
    pub service_state: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct LogidStatus {
    pub binary: Option<String>,
    pub active: bool,
    pub service_state: String,
    pub config_present: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct HostSummary {
    pub os_pretty: String,
    pub kernel: String,
    pub uptime: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct HostReport {
    pub desktop_selected: bool,
    pub keymap: KeymapReport,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dgpu: Option<DgpuStatus>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub battery: Option<BatteryStatus>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub refresh: Option<RefreshStatus>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub logid: Option<LogidStatus>,
    pub system: HostSummary,
}

pub fn cmd_host(action: Option<HostAction>) -> Result<i32> {
    match action.unwrap_or(HostAction::Status { json: false }) {
        HostAction::Status { json } => cmd_status(json),
        HostAction::Keymap { action } => keymap::cmd_keymap(action),
        HostAction::Dgpu { action } => cmd_dgpu(action.unwrap_or(DgpuAction::Status)),
        HostAction::Battery { action } => cmd_battery(action.unwrap_or(BatteryAction::Status)),
        HostAction::Refresh { action } => cmd_refresh(action.unwrap_or(RefreshAction::Status)),
        HostAction::Logid { action } => cmd_logid(action.unwrap_or(LogidAction::Status)),
    }
}

fn current_bundles() -> Vec<String> {
    load_chezmoi_data()
        .ok()
        .and_then(|d| d.machines.get(&d.machine).map(|m| m.bundles.clone()))
        .unwrap_or_default()
}

pub fn collect_report(bundles: &[String]) -> HostReport {
    let desktop_selected = bundles.iter().any(|b| b == "desktop");
    let laptop_selected = bundles.iter().any(|b| b == "laptop");

    let keymap = keymap::collect_report();
    let dgpu = collect_dgpu(laptop_selected);
    let battery = collect_battery(laptop_selected);
    let refresh = collect_refresh(laptop_selected);
    let logid = collect_logid(desktop_selected);
    let system = collect_host_summary();

    HostReport {
        desktop_selected,
        keymap,
        dgpu,
        battery,
        refresh,
        logid,
        system,
    }
}

fn collect_host_summary() -> HostSummary {
    let os_pretty = fs::read_to_string("/etc/os-release")
        .ok()
        .and_then(|txt| {
            txt.lines()
                .find_map(|l| l.strip_prefix("PRETTY_NAME="))
                .map(|v| v.trim().trim_matches('"').to_string())
        })
        .unwrap_or_else(|| "Linux".to_string());

    let kernel = run_capture("uname", &["-r"]).1;
    let uptime = fs::read_to_string("/proc/uptime")
        .ok()
        .and_then(|txt| txt.split_whitespace().next()?.parse::<f64>().ok())
        .map(format_uptime)
        .unwrap_or_else(|| "-".to_string());

    HostSummary {
        os_pretty,
        kernel: if kernel.is_empty() { "-".to_string() } else { kernel },
        uptime,
    }
}

fn format_uptime(secs: f64) -> String {
    let total = secs.max(0.0) as u64;
    let days = total / 86_400;
    let hours = (total % 86_400) / 3_600;
    let mins = (total % 3_600) / 60;
    if days > 0 {
        format!("{days}d {hours}h {mins}m")
    } else if hours > 0 {
        format!("{hours}h {mins}m")
    } else {
        format!("{mins}m")
    }
}

fn unit_is_active(unit: &str, user: bool) -> (bool, String) {
    if which("systemctl").is_none() {
        return (false, "unavailable".to_string());
    }
    let args: Vec<&str> = if user {
        vec!["--user", "is-active", unit]
    } else {
        vec!["is-active", unit]
    };
    let (_, out, _) = run_capture("systemctl", &args);
    let state = if out.is_empty() {
        "unknown".to_string()
    } else {
        out
    };
    (state == "active", state)
}

fn unit_is_enabled(unit: &str) -> Option<bool> {
    which("systemctl")?;
    let (rc, out, _) = run_capture("systemctl", &["is-enabled", unit]);
    match out.as_str() {
        "enabled" | "enabled-runtime" => Some(true),
        "disabled" | "masked" | "static" => Some(false),
        _ if rc == 0 => Some(true),
        _ => None,
    }
}

fn collect_dgpu(laptop_selected: bool) -> Option<DgpuStatus> {
    let helper_present = Path::new(DGPU_HELPER_PATH).is_file();
    if !helper_present && !laptop_selected {
        return None;
    }
    if !helper_present {
        return Some(DgpuStatus {
            helper_present: false,
            pci: None,
            setting: "not-installed".to_string(),
            gnome: "unknown".to_string(),
            power: "-".to_string(),
            open_by: "-".to_string(),
            advice: vec!["Run `sudo -v && chezmoi apply` to install /usr/local/libexec/dgpu-display.".to_string()],
        });
    }
    let (rc, out, err) = run_capture(DGPU_HELPER_PATH, &["status"]);
    if rc != 0 {
        let msg = if err.is_empty() {
            "dgpu-display failed".to_string()
        } else {
            err
        };
        return Some(DgpuStatus {
            helper_present: true,
            pci: None,
            setting: "error".to_string(),
            gnome: msg,
            power: "-".to_string(),
            open_by: "-".to_string(),
            advice: vec![],
        });
    }
    Some(parse_dgpu_output(&out))
}

/// Parse stdout of `/usr/local/libexec/dgpu-display status`.
pub fn parse_dgpu_output(output: &str) -> DgpuStatus {
    let mut pci = None;
    let mut setting = "unknown".to_string();
    let mut gnome = "unknown".to_string();
    let mut power = "-".to_string();
    let mut open_by = "-".to_string();
    let mut advice = Vec::new();

    for raw in output.lines() {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        if let Some(rest) = line.strip_prefix("dGPU") {
            pci = Some(rest.trim().to_string());
        } else if let Some(rest) = line.strip_prefix("setting") {
            setting = rest.trim().to_string();
        } else if let Some(rest) = line.strip_prefix("GNOME") {
            gnome = rest.trim().to_string();
        } else if let Some(rest) = line.strip_prefix("power") {
            power = rest.trim().to_string();
        } else if let Some(rest) = line.strip_prefix("open by") {
            open_by = rest.trim().to_string();
        } else {
            advice.push(line.to_string());
        }
    }

    DgpuStatus {
        helper_present: true,
        pci,
        setting,
        gnome,
        power,
        open_by,
        advice,
    }
}

fn collect_battery(laptop_selected: bool) -> Option<BatteryStatus> {
    let sysfs = Path::new(BATTERY_CHARGE_TYPES_PATH);
    if !sysfs.exists() && !laptop_selected {
        return None;
    }
    let persistent_mode = if Path::new(BATTERY_FULL_MARKER).exists() {
        "full".to_string()
    } else {
        "limit".to_string()
    };
    let (live_mode, available_modes) = fs::read_to_string(sysfs)
        .map(|text| parse_charge_types(&text))
        .unwrap_or((None, Vec::new()));
    let service_enabled = unit_is_enabled(BATTERY_LIMIT_UNIT);

    Some(BatteryStatus {
        available: sysfs.exists(),
        persistent_mode,
        live_mode,
        available_modes,
        service_enabled,
    })
}

/// Parse Linux `power_supply/BAT*/charge_types`, e.g. `"Fast Standard [Long_Life]"`.
pub fn parse_charge_types(content: &str) -> (Option<String>, Vec<String>) {
    let mut active = None;
    let mut all = Vec::new();
    for tok in content.split_whitespace() {
        if let Some(inner) = tok.strip_prefix('[').and_then(|t| t.strip_suffix(']')) {
            active = Some(inner.to_string());
            all.push(inner.to_string());
        } else {
            all.push(tok.to_string());
        }
    }
    (active, all)
}

fn collect_refresh(laptop_selected: bool) -> Option<RefreshStatus> {
    let unit_file = crate::doctor::xdg_config_home(&crate::doctor::home_dir())
        .join("systemd/user")
        .join(REFRESH_USER_UNIT);
    let unit_present = unit_file.is_file();
    if !unit_present && !laptop_selected {
        return None;
    }
    let (active, service_state) = unit_is_active(REFRESH_USER_UNIT, true);
    Some(RefreshStatus {
        unit_present,
        active,
        service_state,
    })
}

fn find_logid_bin() -> Option<String> {
    for candidate in ["/usr/local/bin/logid", "/usr/bin/logid"] {
        if Path::new(candidate).is_file() {
            return Some(candidate.to_string());
        }
    }
    which("logid").map(|p| p.to_string_lossy().into_owned())
}

fn collect_logid(desktop_selected: bool) -> Option<LogidStatus> {
    let binary = find_logid_bin();
    let config_present = Path::new(LOGID_CONFIG_PATH).is_file();
    if binary.is_none() && !config_present && !desktop_selected {
        return None;
    }
    let (active, service_state) = if binary.is_some() {
        unit_is_active(LOGID_UNIT, false)
    } else {
        (false, "not-installed".to_string())
    };
    Some(LogidStatus {
        binary,
        active,
        service_state,
        config_present,
    })
}

fn cmd_status(json_out: bool) -> Result<i32> {
    let bundles = current_bundles();
    let report = collect_report(&bundles);
    if json_out {
        println!("{}", serde_json::to_string_pretty(&report)?);
        return Ok(0);
    }

    println!("host: {} (kernel {}, up {})", report.system.os_pretty, report.system.kernel, report.system.uptime);

    let mut any = false;
    if report.desktop_selected || report.keymap.installed || report.keymap.config_present {
        any = true;
        let state = if !report.keymap.installed {
            "not installed"
        } else if report.keymap.active {
            "on (HHKB remap active)"
        } else {
            "off (standard keyboard)"
        };
        println!("  keymap    {state}");
    }
    if let Some(dgpu) = &report.dgpu {
        any = true;
        println!("  dgpu      setting={} | GNOME: {} | {}", dgpu.setting, dgpu.gnome, dgpu.power);
    }
    if let Some(bat) = &report.battery {
        any = true;
        let live = bat.live_mode.as_deref().unwrap_or("unavailable");
        println!("  battery   setting={} | live={live}", bat.persistent_mode);
    }
    if let Some(rf) = &report.refresh {
        any = true;
        println!("  refresh   {} ({})", if rf.active { "on" } else { "off" }, rf.service_state);
    }
    if let Some(lg) = &report.logid {
        any = true;
        let bin = lg.binary.as_deref().unwrap_or("not installed");
        println!("  logid     {} ({bin})", lg.service_state);
    }
    if !any {
        println!("  (no managed host hardware controls active on this profile)");
    }
    Ok(0)
}

fn cmd_dgpu(action: DgpuAction) -> Result<i32> {
    if !Path::new(DGPU_HELPER_PATH).is_file() {
        eprintln!("dotfiles host dgpu: {DGPU_HELPER_PATH} is missing; run 'sudo -v && chezmoi apply' on laptop.");
        return Ok(1);
    }
    let arg = match action {
        DgpuAction::Status => "status",
        DgpuAction::On => "on",
        DgpuAction::Off => "off",
    };
    let status = Command::new(DGPU_HELPER_PATH).arg(arg).status()?;
    Ok(status.code().unwrap_or(1))
}

fn cmd_battery(action: BatteryAction) -> Result<i32> {
    match action {
        BatteryAction::Status => {
            let Some(bat) = collect_battery(true) else {
                eprintln!("dotfiles host battery: battery control unavailable");
                return Ok(1);
            };
            println!(
                "battery:  persistent={} | live={} | modes=[{}]",
                bat.persistent_mode,
                bat.live_mode.as_deref().unwrap_or("unavailable"),
                bat.available_modes.join(", ")
            );
            Ok(0)
        }
        BatteryAction::Limit => set_battery_mode(false),
        BatteryAction::Full => set_battery_mode(true),
    }
}

pub fn set_battery_mode(full: bool) -> Result<i32> {
    if !Path::new(BATTERY_CHARGE_TYPES_PATH).exists() {
        eprintln!("dotfiles host battery: {BATTERY_CHARGE_TYPES_PATH} not found on this host.");
        return Ok(1);
    }
    let script = if full {
        format!(
            "mkdir -p /var/lib/dotfiles && touch {BATTERY_FULL_MARKER} && echo Standard > {BATTERY_CHARGE_TYPES_PATH}"
        )
    } else {
        format!(
            "rm -f {BATTERY_FULL_MARKER} && echo Long_Life > {BATTERY_CHARGE_TYPES_PATH}"
        )
    };
    let status = Command::new("sudo").args(["sh", "-c", &script]).status()?;
    if status.success() {
        if full {
            println!("battery: full (Standard, ~100%; persists until `dotfiles host battery limit`)");
        } else {
            println!("battery: limit (Long_Life, ~80%; enforced across suspend and reboot)");
        }
    }
    Ok(status.code().unwrap_or(1))
}

pub fn set_refresh_inline(enable: bool) -> Result<bool> {
    if which("systemctl").is_none() {
        return Ok(false);
    }
    let verb = if enable { "start" } else { "stop" };
    let st = Command::new("systemctl")
        .args(["--user", verb, REFRESH_USER_UNIT])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    Ok(st.success())
}

pub fn restart_refresh_inline() -> Result<bool> {
    if which("systemctl").is_none() {
        return Ok(false);
    }
    let st = Command::new("systemctl")
        .args(["--user", "restart", REFRESH_USER_UNIT])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    Ok(st.success())
}

fn cmd_refresh(action: RefreshAction) -> Result<i32> {
    match action {
        RefreshAction::Status => {
            let (active, state) = unit_is_active(REFRESH_USER_UNIT, true);
            println!("refresh ({REFRESH_USER_UNIT}): {} ({state})", if active { "on" } else { "off" });
            Ok(0)
        }
        RefreshAction::On => {
            let ok = set_refresh_inline(true)?;
            if ok {
                println!("refresh ({REFRESH_USER_UNIT}): on");
                Ok(0)
            } else {
                eprintln!("dotfiles host refresh: failed to start {REFRESH_USER_UNIT}");
                Ok(1)
            }
        }
        RefreshAction::Off => {
            let ok = set_refresh_inline(false)?;
            if ok {
                println!("refresh ({REFRESH_USER_UNIT}): off");
                Ok(0)
            } else {
                eprintln!("dotfiles host refresh: failed to stop {REFRESH_USER_UNIT}");
                Ok(1)
            }
        }
        RefreshAction::Toggle => {
            let (active, _) = unit_is_active(REFRESH_USER_UNIT, true);
            let target = !active;
            let ok = set_refresh_inline(target)?;
            if ok {
                println!("refresh ({REFRESH_USER_UNIT}): {}", if target { "on" } else { "off" });
                Ok(0)
            } else {
                eprintln!("dotfiles host refresh: failed to toggle {REFRESH_USER_UNIT}");
                Ok(1)
            }
        }
    }
}

fn cmd_logid(action: LogidAction) -> Result<i32> {
    match action {
        LogidAction::Status => {
            let st = collect_logid(true).expect("desktop flag forces Some");
            println!(
                "logid ({LOGID_UNIT}): {} | binary={} | config={}",
                st.service_state,
                st.binary.as_deref().unwrap_or("not installed"),
                if st.config_present { "present" } else { "missing" }
            );
            Ok(0)
        }
        LogidAction::Restart => {
            if find_logid_bin().is_none() {
                eprintln!("dotfiles host logid: logid is not installed; run 'sudo -v && chezmoi apply'.");
                return Ok(1);
            }
            let status = Command::new("sudo")
                .args(["systemctl", "restart", LOGID_UNIT])
                .status()?;
            if status.success() {
                println!("logid ({LOGID_UNIT}): restarted");
            }
            Ok(status.code().unwrap_or(1))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_dgpu_display_status_output() {
        let sample = "\
dGPU      0000:01:00.0, /dev/dri/card1
setting   off
GNOME     ignores it
power     D3cold, suspended; awake 12% since boot
open by   nothing (your processes only)
Log out and back in to apply.
";
        let st = parse_dgpu_output(sample);
        assert!(st.helper_present);
        assert_eq!(st.pci.as_deref(), Some("0000:01:00.0, /dev/dri/card1"));
        assert_eq!(st.setting, "off");
        assert_eq!(st.gnome, "ignores it");
        assert_eq!(st.power, "D3cold, suspended; awake 12% since boot");
        assert_eq!(st.open_by, "nothing (your processes only)");
        assert_eq!(st.advice, vec!["Log out and back in to apply."]);
    }

    #[test]
    fn parses_battery_charge_types() {
        let (active, modes) = parse_charge_types("Fast Standard [Long_Life]\n");
        assert_eq!(active.as_deref(), Some("Long_Life"));
        assert_eq!(modes, vec!["Fast", "Standard", "Long_Life"]);

        let (active2, modes2) = parse_charge_types("Fast [Standard] Long_Life");
        assert_eq!(active2.as_deref(), Some("Standard"));
        assert_eq!(modes2, vec!["Fast", "Standard", "Long_Life"]);
    }
}
