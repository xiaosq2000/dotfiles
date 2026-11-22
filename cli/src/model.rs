use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct ChezmoiData {
    #[serde(default)]
    pub machine: String,
    #[serde(default)]
    pub theme: String,
    #[serde(default)]
    pub machines: BTreeMap<String, MachineSpec>,
    #[serde(default)]
    pub bundles: BTreeMap<String, BundleSpec>,
    #[serde(default)]
    pub mise: BTreeMap<String, MiseToolSpec>,
    #[serde(default)]
    pub downloads: BTreeMap<String, DownloadSpec>,
    #[serde(default)]
    pub system_packages: BTreeMap<String, SystemPackageSpec>,
    #[serde(default)]
    pub schemes: BTreeMap<String, SchemeSpec>,
    #[serde(default)]
    pub themes: BTreeMap<String, ThemeSpec>,
    #[serde(default)]
    pub secrets: SecretsConfig,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct SecretsConfig {
    #[serde(rename = "ageIdentity", default = "default_age_identity")]
    pub age_identity: String,
}

fn default_age_identity() -> String {
    ".config/chezmoi/key.txt".to_string()
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct MachineSpec {
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub bundles: Vec<String>,
    #[serde(default)]
    pub sudo: bool,
    #[serde(rename = "manageSystem", default)]
    pub manage_system: bool,
    #[serde(rename = "virtual", default)]
    pub is_virtual: bool,
    #[serde(default)]
    pub docs: String,
    #[serde(default)]
    pub pixi: PixiRelocation,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct PixiRelocation {
    #[serde(rename = "cacheDir", default)]
    pub cache_dir: String,
    #[serde(rename = "detachedEnvironments", default)]
    pub detached_environments: String,
    #[serde(rename = "repodataDir", default)]
    pub repodata_dir: String,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct BundleSpec {
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub packages: Vec<String>,
    #[serde(default)]
    pub mise: Vec<String>,
    #[serde(default)]
    pub downloads: Vec<String>,
    #[serde(default)]
    pub system_packages: Vec<String>,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct SystemPackageSpec {
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub probe: Vec<String>,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct MiseToolSpec {
    #[serde(default)]
    pub tool: String,
    #[serde(default)]
    pub version: String,
    #[serde(default)]
    pub bin: Option<String>,
    #[serde(default)]
    pub description: String,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct DownloadSpec {
    #[serde(default)]
    pub github: Option<String>,
    #[serde(default)]
    pub tag: Option<String>,
    #[serde(default)]
    pub url: Option<serde_json::Value>,
    #[serde(default)]
    pub manifest: Option<serde_json::Value>,
    #[serde(default)]
    pub fonts: Option<Vec<String>>,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct SchemeSpec {
    #[serde(default)]
    pub description: String,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct ThemeSpec {
    #[serde(default)]
    pub scheme: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub appearance: String,
    #[serde(default)]
    pub starship: StarshipPalette,
    #[serde(default)]
    pub fzf: FzfPalette,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct StarshipPalette {
    #[serde(default)]
    pub surface: String,
    #[serde(default)]
    pub error: String,
    #[serde(default)]
    pub warn: String,
    #[serde(default)]
    pub accent: String,
    #[serde(default)]
    pub lang: String,
    #[serde(default)]
    pub vcs: String,
    #[serde(default)]
    pub primary: String,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct FzfPalette {
    #[serde(default)]
    pub fg: String,
    #[serde(default)]
    pub bg: String,
    #[serde(default)]
    pub hl: String,
    #[serde(rename = "fgPlus", default)]
    pub fg_plus: String,
    #[serde(rename = "bgPlus", default)]
    pub bg_plus: String,
    #[serde(default)]
    pub border: String,
    #[serde(default)]
    pub header: String,
    #[serde(default)]
    pub spinner: String,
    #[serde(default)]
    pub info: String,
    #[serde(default)]
    pub pointer: String,
    #[serde(default)]
    pub marker: String,
    #[serde(default)]
    pub prompt: String,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct PolicyFile {
    #[serde(default)]
    pub secrets: PolicySecrets,
    #[serde(default)]
    pub jail: PolicyJail,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct PolicySecrets {
    #[serde(default)]
    pub age_identity: String,
    #[serde(default)]
    pub masked_dirs: Vec<String>,
    #[serde(default)]
    pub masked_files: Vec<String>,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct PolicyJail {
    #[serde(default)]
    pub hide_system_dirs: Vec<String>,
    #[serde(default)]
    pub common_rw_dirs: Vec<String>,
    #[serde(default)]
    pub machine_rw_dirs: Vec<String>,
    #[serde(default)]
    pub agents: BTreeMap<String, PolicyAgentJail>,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct PolicyAgentJail {
    #[serde(default)]
    pub rw_dirs: Vec<String>,
    #[serde(default)]
    pub rw_files: Vec<String>,
    #[serde(default)]
    pub own_auth_files: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct DoctorReport {
    pub status: String,
    pub checks: DoctorChecks,
}

#[derive(Debug, Clone, Serialize)]
pub struct DoctorChecks {
    pub chezmoi: ChezmoiCheck,
    pub secrets: SecretsCheck,
    pub toolchain: ToolchainCheck,
    pub shell_git: ShellGitCheck,
    pub agents: AgentsCheck,
    pub system: SystemCheck,
}

#[derive(Debug, Clone, Serialize)]
pub struct ChezmoiCheck {
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub machine: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub theme: Option<String>,
    pub bundles: Vec<String>,
    pub sudo: bool,
    pub manage_system: bool,
    pub source_path: Option<String>,
    pub drifted_count: usize,
    pub drifted: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LooseKey {
    pub name: String,
    pub mode: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct SecretsCheck {
    pub status: String,
    pub age_identity_present: bool,
    pub age_identity_mode: Option<String>,
    pub loose_ssh_keys: Vec<LooseKey>,
    pub policy_json_valid: bool,
    pub issues: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ToolchainCheck {
    pub status: String,
    pub pixi: Option<String>,
    pub mise: Option<String>,
    pub selected_mise_tools: Vec<String>,
    pub missing_mise_shims: Vec<String>,
    pub pending_markers: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub shadow_dotfiles_bin: Option<String>,
    pub issues: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ShellGitCheck {
    pub status: String,
    pub env_sh: bool,
    pub git_xdg_config: bool,
    pub git_diff_algorithm: Option<String>,
    pub git_diff_external: Option<String>,
    pub zoxide: Option<String>,
    pub sbc_route: Option<String>,
    pub issues: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentEntry {
    pub binary: Option<String>,
    pub instructions: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub key_guard_configured: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sandbox_profile: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub guard_extension: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentsCheck {
    pub status: String,
    pub agent_tools_selected: bool,
    pub key_guard: bool,
    pub agent_notify: bool,
    pub agent_jail_backends: Vec<String>,
    pub active_jail: Option<String>,
    pub agents: BTreeMap<String, AgentEntry>,
    pub issues: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SystemCheck {
    pub status: String,
    pub skipped: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub skip_reason: Option<String>,
    pub managed_files: usize,
    pub drifted_files: Vec<String>,
    pub selected_system_packages: Vec<String>,
    pub missing_packages: Vec<String>,
    pub stale_sbin_files: Vec<String>,
    pub issues: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct FetchItemStatus {
    pub id: String,
    pub kind: String,
    pub source: String,
    pub installed_version: Option<String>,
    pub selected: bool,
}

#[derive(Debug, Clone)]
pub struct FullSnapshot {
    pub data: Option<ChezmoiData>,
    pub policy: Option<PolicyFile>,
    pub report: DoctorReport,
    pub fetch_items: Vec<FetchItemStatus>,
    pub host: crate::host::HostReport,
}
