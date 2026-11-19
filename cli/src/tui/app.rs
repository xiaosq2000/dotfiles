use crate::model::{FullSnapshot, ThemeSpec};
use crate::tui::theme::TuiTheme;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tab {
    Overview,
    Themes,
    Agents,
    Toolchain,
    Machines,
}

impl Tab {
    pub const ALL: [Tab; 5] = [
        Tab::Overview,
        Tab::Themes,
        Tab::Agents,
        Tab::Toolchain,
        Tab::Machines,
    ];

    pub fn title(self) -> &'static str {
        match self {
            Tab::Overview => "1 Overview",
            Tab::Themes => "2 Themes",
            Tab::Agents => "3 Agents & Jail",
            Tab::Toolchain => "4 Toolchain",
            Tab::Machines => "5 Machines",
        }
    }

    pub fn index(self) -> usize {
        match self {
            Tab::Overview => 0,
            Tab::Themes => 1,
            Tab::Agents => 2,
            Tab::Toolchain => 3,
            Tab::Machines => 4,
        }
    }

    pub fn next(self) -> Self {
        Self::ALL[(self.index() + 1) % Self::ALL.len()]
    }

    pub fn prev(self) -> Self {
        Self::ALL[(self.index() + Self::ALL.len() - 1) % Self::ALL.len()]
    }
}

#[derive(Debug, Clone)]
pub enum PendingAction {
    RunCommand {
        label: String,
        prog: String,
        args: Vec<String>,
        pause: bool,
    },
}

#[derive(Debug, Clone)]
pub struct ThemeListItem {
    pub slug: String,
    pub spec: ThemeSpec,
    pub active: bool,
}

#[derive(Debug, Clone)]
pub struct ToolchainRow {
    pub category: &'static str,
    pub id: String,
    pub detail: String,
    pub status: String,
    pub ok: bool,
}

pub struct App {
    pub snapshot: FullSnapshot,
    pub tab: Tab,
    pub overview_idx: usize,
    pub theme_idx: usize,
    pub agent_idx: usize,
    pub toolchain_idx: usize,
    pub machine_idx: usize,
    pub themes: Vec<ThemeListItem>,
    pub toolchain_rows: Vec<ToolchainRow>,
    pub machine_names: Vec<String>,
    pub refreshing: bool,
    pub tick: usize,
    pub status_msg: Option<String>,
    pub should_quit: bool,
    pub pending_action: Option<PendingAction>,
    pub show_help: bool,
}

pub const AGENT_NAMES: [&str; 4] = ["claude", "codex", "agy", "pi"];

impl App {
    pub fn new(snapshot: FullSnapshot) -> Self {
        let mut app = Self {
            snapshot,
            tab: Tab::Overview,
            overview_idx: 0,
            theme_idx: 0,
            agent_idx: 0,
            toolchain_idx: 0,
            machine_idx: 0,
            themes: Vec::new(),
            toolchain_rows: Vec::new(),
            machine_names: Vec::new(),
            refreshing: false,
            tick: 0,
            status_msg: None,
            should_quit: false,
            pending_action: None,
            show_help: false,
        };
        app.rebuild_derived(true);
        app
    }

    pub fn update_snapshot(&mut self, snapshot: FullSnapshot) {
        self.snapshot = snapshot;
        self.refreshing = false;
        self.rebuild_derived(false);
    }

    fn rebuild_derived(&mut self, select_defaults: bool) {
        let active_theme = self
            .snapshot
            .report
            .checks
            .chezmoi
            .theme
            .clone()
            .unwrap_or_default();
        let active_machine = self
            .snapshot
            .report
            .checks
            .chezmoi
            .machine
            .clone()
            .unwrap_or_default();

        // Build ordered theme list grouped by scheme.
        let mut themes = Vec::new();
        if let Some(data) = &self.snapshot.data {
            for scheme in data.schemes.keys() {
                for (slug, spec) in &data.themes {
                    if &spec.scheme == scheme {
                        themes.push(ThemeListItem {
                            slug: slug.clone(),
                            spec: spec.clone(),
                            active: slug == &active_theme,
                        });
                    }
                }
            }
            for (slug, spec) in &data.themes {
                if !themes.iter().any(|t| &t.slug == slug) {
                    themes.push(ThemeListItem {
                        slug: slug.clone(),
                        spec: spec.clone(),
                        active: slug == &active_theme,
                    });
                }
            }
        }
        self.themes = themes;
        if select_defaults {
            if let Some(pos) = self.themes.iter().position(|t| t.active) {
                self.theme_idx = pos;
            }
        } else if !self.themes.is_empty() {
            self.theme_idx = self.theme_idx.min(self.themes.len() - 1);
        }

        // Build combined toolchain rows (mise + dotfiles-fetch).
        let mut rows = Vec::new();
        let tc = &self.snapshot.report.checks.toolchain;
        for tool_id in &tc.selected_mise_tools {
            let missing = tc.missing_mise_shims.contains(tool_id);
            let spec_info = self
                .snapshot
                .data
                .as_ref()
                .and_then(|d| d.mise.get(tool_id))
                .map(|m| format!("{} @ {}", m.tool, m.version))
                .unwrap_or_else(|| "mise locked".to_string());
            rows.push(ToolchainRow {
                category: "mise",
                id: tool_id.clone(),
                detail: spec_info,
                status: if missing { "missing shim" } else { "locked" }.to_string(),
                ok: !missing,
            });
        }
        for item in &self.snapshot.fetch_items {
            if !item.selected {
                continue;
            }
            let ok = item.installed_version.is_some();
            rows.push(ToolchainRow {
                category: if item.kind == "font" { "font" } else { "fetch" },
                id: item.id.clone(),
                detail: item.source.clone(),
                status: item
                    .installed_version
                    .clone()
                    .unwrap_or_else(|| "not synced".to_string()),
                ok,
            });
        }
        self.toolchain_rows = rows;
        if !self.toolchain_rows.is_empty() {
            self.toolchain_idx = self.toolchain_idx.min(self.toolchain_rows.len() - 1);
        } else {
            self.toolchain_idx = 0;
        }

        // Build machine list: real hosts first, virtual fallback/CI profiles last.
        let mut machines = Vec::new();
        if let Some(data) = &self.snapshot.data {
            for (name, spec) in &data.machines {
                if !spec.is_virtual {
                    machines.push(name.clone());
                }
            }
            for (name, spec) in &data.machines {
                if spec.is_virtual {
                    machines.push(name.clone());
                }
            }
        }
        self.machine_names = machines;
        if select_defaults {
            if let Some(pos) = self.machine_names.iter().position(|m| m == &active_machine) {
                self.machine_idx = pos;
            }
        } else if !self.machine_names.is_empty() {
            self.machine_idx = self.machine_idx.min(self.machine_names.len() - 1);
        }
    }

    pub fn active_palette(&self) -> TuiTheme {
        // On the Themes tab, live-preview the currently highlighted theme!
        if self.tab == Tab::Themes
            && let Some(item) = self.themes.get(self.theme_idx)
        {
            return TuiTheme::from_spec(&item.spec);
        }
        let active_name = self
            .snapshot
            .report
            .checks
            .chezmoi
            .theme
            .as_deref()
            .unwrap_or("");
        if let Some(spec) = self
            .snapshot
            .data
            .as_ref()
            .and_then(|d| d.themes.get(active_name))
        {
            return TuiTheme::from_spec(spec);
        }
        TuiTheme::default()
    }

    pub fn move_down(&mut self) {
        match self.tab {
            Tab::Overview => self.overview_idx = (self.overview_idx + 1) % 5,
            Tab::Themes if !self.themes.is_empty() => {
                self.theme_idx = (self.theme_idx + 1) % self.themes.len();
            }
            Tab::Agents => self.agent_idx = (self.agent_idx + 1) % AGENT_NAMES.len(),
            Tab::Toolchain if !self.toolchain_rows.is_empty() => {
                self.toolchain_idx = (self.toolchain_idx + 1) % self.toolchain_rows.len();
            }
            Tab::Machines if !self.machine_names.is_empty() => {
                self.machine_idx = (self.machine_idx + 1) % self.machine_names.len();
            }
            _ => {}
        }
    }

    pub fn move_up(&mut self) {
        match self.tab {
            Tab::Overview => self.overview_idx = (self.overview_idx + 4) % 5,
            Tab::Themes if !self.themes.is_empty() => {
                self.theme_idx = (self.theme_idx + self.themes.len() - 1) % self.themes.len();
            }
            Tab::Agents => {
                self.agent_idx = (self.agent_idx + AGENT_NAMES.len() - 1) % AGENT_NAMES.len();
            }
            Tab::Toolchain if !self.toolchain_rows.is_empty() => {
                self.toolchain_idx =
                    (self.toolchain_idx + self.toolchain_rows.len() - 1) % self.toolchain_rows.len();
            }
            Tab::Machines if !self.machine_names.is_empty() => {
                self.machine_idx =
                    (self.machine_idx + self.machine_names.len() - 1) % self.machine_names.len();
            }
            _ => {}
        }
    }
}
