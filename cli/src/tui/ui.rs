use crate::tui::app::{AGENT_NAMES, App, HostControlKind, Tab};
use crate::tui::theme::{TuiTheme, parse_hex};
use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{
    Block, BorderType, Borders, Clear, List, ListItem, ListState, Paragraph, Tabs, Wrap,
};

const SPINNER: [&str; 10] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

pub fn render(frame: &mut Frame, app: &App) {
    let p = app.active_palette();
    let area = frame.area();

    // Paint the entire terminal background with the active (or previewed) theme canvas.
    frame.render_widget(
        Block::default().style(Style::default().bg(p.bg).fg(p.fg)),
        area,
    );

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // header + tabs
            Constraint::Min(10),   // main content
            Constraint::Length(2), // footer hints + status
        ])
        .split(area);

    render_header(frame, app, p, chunks[0]);

    match app.tab {
        Tab::Overview => render_overview(frame, app, p, chunks[1]),
        Tab::Themes => render_themes(frame, app, p, chunks[1]),
        Tab::Agents => render_agents(frame, app, p, chunks[1]),
        Tab::Toolchain => render_toolchain(frame, app, p, chunks[1]),
        Tab::Machines => render_machines(frame, app, p, chunks[1]),
        Tab::Host => render_host(frame, app, p, chunks[1]),
    }

    render_footer(frame, app, p, chunks[2]);

    if app.show_help {
        render_help_modal(frame, p, area);
    }
}

fn status_color(status: &str, p: TuiTheme) -> ratatui::style::Color {
    match status {
        "ok" => p.ok,
        "warn" => p.warn,
        _ => p.error,
    }
}

fn styled_block<'a>(title: impl Into<Line<'a>>, p: TuiTheme, focused: bool) -> Block<'a> {
    Block::default()
        .title(title)
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(if focused { p.primary } else { p.border }))
        .style(Style::default().bg(p.bg).fg(p.fg))
}

fn render_header(frame: &mut Frame, app: &App, p: TuiTheme, area: Rect) {
    let cz = &app.snapshot.report.checks.chezmoi;
    let sg = &app.snapshot.report.checks.shell_git;
    let ag = &app.snapshot.report.checks.agents;

    let machine = cz.machine.as_deref().unwrap_or("unknown");
    let theme = cz.theme.as_deref().unwrap_or("unknown");
    let overall = app.snapshot.report.status.to_uppercase();

    let header_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(62), Constraint::Percentage(38)])
        .split(area);

    let titles: Vec<Line> = Tab::ALL
        .iter()
        .map(|t| Line::from(Span::raw(t.title())))
        .collect();
    let tabs = Tabs::new(titles)
        .select(app.tab.index())
        .block(styled_block(
            Line::from(vec![
                Span::styled(" ◈ dotfiles ", Style::default().fg(p.primary).add_modifier(Modifier::BOLD)),
            ]),
            p,
            true,
        ))
        .style(Style::default().fg(p.fg))
        .highlight_style(
            Style::default()
                .fg(p.bg)
                .bg(p.primary)
                .add_modifier(Modifier::BOLD),
        )
        .divider(Span::styled(" │ ", Style::default().fg(p.border)));
    frame.render_widget(tabs, header_chunks[0]);

    let mut right_spans = vec![
        Span::styled(
            format!(" {overall} "),
            Style::default()
                .fg(p.bg)
                .bg(status_color(&app.snapshot.report.status, p))
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" "),
        Span::styled(
            machine,
            Style::default().fg(p.fg_bright).add_modifier(Modifier::BOLD),
        ),
        Span::styled(" · ", Style::default().fg(p.border)),
        Span::styled(theme, Style::default().fg(p.accent)),
    ];
    if let Some(active_jail) = &ag.active_jail {
        right_spans.push(Span::styled(" · ", Style::default().fg(p.border)));
        right_spans.push(Span::styled(
            format!("jail:{active_jail}"),
            Style::default().fg(p.ok).add_modifier(Modifier::BOLD),
        ));
    } else if let Some(route) = &sg.sbc_route {
        right_spans.push(Span::styled(" · ", Style::default().fg(p.border)));
        right_spans.push(Span::styled(route.as_str(), Style::default().fg(p.vcs)));
    }
    if app.snapshot.host.keymap.installed {
        right_spans.push(Span::styled(" · ", Style::default().fg(p.border)));
        let (label, color) = if app.snapshot.host.keymap.active {
            ("hhkb:on", p.ok)
        } else {
            ("hhkb:off", p.warn)
        };
        right_spans.push(Span::styled(
            label,
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ));
    }
    if let Some(dgpu) = &app.snapshot.host.dgpu
        && dgpu.setting == "off"
    {
        right_spans.push(Span::styled(" · ", Style::default().fg(p.border)));
        right_spans.push(Span::styled(
            "dgpu:off",
            Style::default().fg(p.info).add_modifier(Modifier::BOLD),
        ));
    }
    if app.refreshing {
        let spin = SPINNER[app.tick % SPINNER.len()];
        right_spans.push(Span::styled(
            format!(" {spin}"),
            Style::default().fg(p.warn).add_modifier(Modifier::BOLD),
        ));
    }

    let info_bar = Paragraph::new(Line::from(right_spans)).block(styled_block(
        Line::from(Span::styled(" Host ", Style::default().fg(p.info))),
        p,
        false,
    ));
    frame.render_widget(info_bar, header_chunks[1]);
}

fn render_overview(frame: &mut Frame, app: &App, p: TuiTheme, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(42), Constraint::Percentage(58)])
        .split(area);

    let checks = &app.snapshot.report.checks;
    let sections = [
        (
            "chezmoi",
            checks.chezmoi.status.as_str(),
            if checks.chezmoi.drifted_count == 0 {
                "clean working home".to_string()
            } else {
                format!("{} drifted/pending", checks.chezmoi.drifted_count)
            },
        ),
        (
            "secrets",
            checks.secrets.status.as_str(),
            format!(
                "age={} · policy={}",
                checks.secrets.age_identity_mode.as_deref().unwrap_or("absent"),
                if checks.secrets.policy_json_valid { "ok" } else { "err" }
            ),
        ),
        (
            "toolchain",
            checks.toolchain.status.as_str(),
            format!(
                "mise={} · missing={}",
                checks.toolchain.selected_mise_tools.len(),
                checks.toolchain.missing_mise_shims.len()
            ),
        ),
        (
            "shell & git",
            checks.shell_git.status.as_str(),
            format!(
                "diff={} · zoxide={}",
                checks.shell_git.git_diff_algorithm.as_deref().unwrap_or("?"),
                if checks.shell_git.zoxide.is_some() { "on" } else { "off" }
            ),
        ),
        (
            "agents & jail",
            checks.agents.status.as_str(),
            format!(
                "backends={}",
                if checks.agents.agent_jail_backends.is_empty() {
                    "none".to_string()
                } else {
                    checks.agents.agent_jail_backends.join(",")
                }
            ),
        ),
        (
            "system",
            checks.system.status.as_str(),
            if checks.system.skipped {
                format!(
                    "{} (skipped)",
                    checks.system.skip_reason.as_deref().unwrap_or("unmanaged")
                )
            } else {
                format!(
                    "files={} ({} drift) · pkgs={} ({} miss)",
                    checks.system.managed_files,
                    checks.system.drifted_files.len(),
                    checks.system.selected_system_packages.len(),
                    checks.system.missing_packages.len()
                )
            },
        ),
    ];

    let items: Vec<ListItem> = sections
        .iter()
        .map(|(name, status, summary)| {
            let badge = match *status {
                "ok" => " OK ",
                "warn" => "WARN",
                _ => "ERR ",
            };
            ListItem::new(vec![
                Line::from(vec![
                    Span::styled(
                        format!(" {badge} "),
                        Style::default()
                            .fg(p.bg)
                            .bg(status_color(status, p))
                            .add_modifier(Modifier::BOLD),
                    ),
                    Span::raw(" "),
                    Span::styled(
                        *name,
                        Style::default().fg(p.fg_bright).add_modifier(Modifier::BOLD),
                    ),
                ]),
                Line::from(vec![
                    Span::raw("        "),
                    Span::styled(summary.clone(), Style::default().fg(p.fg)),
                ]),
            ])
        })
        .collect();

    let mut list_state = ListState::default();
    list_state.select(Some(app.overview_idx));
    let list = List::new(items)
        .block(styled_block(
            Line::from(Span::styled(" Doctor Health ", Style::default().fg(p.primary).add_modifier(Modifier::BOLD))),
            p,
            true,
        ))
        .highlight_style(Style::default().bg(p.surface).add_modifier(Modifier::BOLD))
        .highlight_symbol("▸ ");
    frame.render_stateful_widget(list, cols[0], &mut list_state);

    // Right inspector panel for the selected health section
    let mut lines: Vec<Line> = Vec::new();
    match app.overview_idx {
        0 => {
            let cz = &checks.chezmoi;
            lines.push(kv("Machine", cz.machine.as_deref().unwrap_or("-"), p));
            lines.push(kv("Description", cz.description.as_deref().unwrap_or("-"), p));
            lines.push(kv("Theme", cz.theme.as_deref().unwrap_or("-"), p));
            lines.push(kv("Source", cz.source_path.as_deref().unwrap_or("-"), p));
            lines.push(kv("Sudo", if cz.sudo { "yes" } else { "no" }, p));
            lines.push(Line::raw(""));
            lines.push(section_heading("Bundles", p));
            lines.push(Line::from(Span::styled(
                if cz.bundles.is_empty() {
                    "(none)".to_string()
                } else {
                    cz.bundles.join(" · ")
                },
                Style::default().fg(p.vcs),
            )));
            lines.push(Line::raw(""));
            lines.push(section_heading("Drift / Status", p));
            if cz.drifted.is_empty() {
                lines.push(Line::from(Span::styled(
                    "✓ All managed targets match source state.",
                    Style::default().fg(p.ok),
                )));
            } else {
                for item in &cz.drifted {
                    lines.push(Line::from(vec![
                        Span::styled("• ", Style::default().fg(p.warn)),
                        Span::styled(item.clone(), Style::default().fg(p.fg_bright)),
                    ]));
                }
            }
        }
        1 => {
            let sec = &checks.secrets;
            lines.push(kv(
                "Age Identity",
                if sec.age_identity_present {
                    sec.age_identity_mode.as_deref().unwrap_or("present")
                } else {
                    "absent"
                },
                p,
            ));
            lines.push(kv(
                "policy.json",
                if sec.policy_json_valid { "valid" } else { "missing/invalid" },
                p,
            ));
            lines.push(kv(
                "Loose SSH Keys",
                &sec.loose_ssh_keys.len().to_string(),
                p,
            ));
            lines.push(Line::raw(""));
            lines.push(section_heading("Findings", p));
            if sec.issues.is_empty() {
                lines.push(Line::from(Span::styled(
                    "✓ Secret permissions and policy file look healthy.",
                    Style::default().fg(p.ok),
                )));
            } else {
                for issue in &sec.issues {
                    lines.push(Line::from(Span::styled(
                        format!("✗ {issue}"),
                        Style::default().fg(p.error),
                    )));
                }
            }
        }
        2 => {
            let tc = &checks.toolchain;
            lines.push(kv("pixi", tc.pixi.as_deref().unwrap_or("missing"), p));
            lines.push(kv("mise", tc.mise.as_deref().unwrap_or("missing"), p));
            lines.push(Line::raw(""));
            lines.push(section_heading("Locked mise Tools", p));
            lines.push(Line::from(Span::styled(
                tc.selected_mise_tools.join(" · "),
                Style::default().fg(p.accent),
            )));
            if !tc.issues.is_empty() {
                lines.push(Line::raw(""));
                lines.push(section_heading("Issues", p));
                for issue in &tc.issues {
                    lines.push(Line::from(Span::styled(
                        format!("! {issue}"),
                        Style::default().fg(p.warn),
                    )));
                }
            }
        }
        3 => {
            let sg = &checks.shell_git;
            lines.push(kv("env.sh", if sg.env_sh { "deployed" } else { "missing" }, p));
            lines.push(kv(
                "XDG git/config",
                if sg.git_xdg_config { "deployed" } else { "missing" },
                p,
            ));
            lines.push(kv(
                "diff.algorithm",
                sg.git_diff_algorithm.as_deref().unwrap_or("-"),
                p,
            ));
            lines.push(kv(
                "diff.external",
                sg.git_diff_external.as_deref().unwrap_or("(unset — native)"),
                p,
            ));
            lines.push(kv("zoxide", sg.zoxide.as_deref().unwrap_or("not installed"), p));
            lines.push(kv("sbc route", sg.sbc_route.as_deref().unwrap_or("-"), p));
        }
        4 => {
            let ag = &checks.agents;
            lines.push(kv(
                "dev bundle",
                if ag.agent_tools_selected { "enabled" } else { "disabled" },
                p,
            ));
            lines.push(kv("key-guard.py", if ag.key_guard { "ok" } else { "missing" }, p));
            lines.push(kv("agent-notify.py", if ag.agent_notify { "ok" } else { "missing" }, p));
            lines.push(kv(
                "agent-jail backends",
                &ag.agent_jail_backends.join(", "),
                p,
            ));
            lines.push(Line::raw(""));
            lines.push(section_heading("4-Agent Control Plane", p));
            for name in AGENT_NAMES {
                if let Some(info) = ag.agents.get(name) {
                    let status = if info.binary.is_some() { "installed" } else { "not installed" };
                    let color = if info.binary.is_some() { p.ok } else { p.fg };
                    lines.push(Line::from(vec![
                        Span::styled(
                            format!("  {name:<7} "),
                            Style::default().fg(p.fg_bright).add_modifier(Modifier::BOLD),
                        ),
                        Span::styled(status, Style::default().fg(color)),
                    ]));
                }
            }
        }
        _ => {
            let sys = &checks.system;
            if sys.skipped {
                lines.push(kv(
                    "Mode",
                    &format!("{} (skipped)", sys.skip_reason.as_deref().unwrap_or("unmanaged")),
                    p,
                ));
            } else {
                lines.push(kv("Managed Files", &sys.managed_files.to_string(), p));
                lines.push(kv("Drifted Files", &sys.drifted_files.len().to_string(), p));
                lines.push(kv(
                    "System Pkgs",
                    &if sys.selected_system_packages.is_empty() {
                        "(none)".to_string()
                    } else {
                        sys.selected_system_packages.join(" · ")
                    },
                    p,
                ));
                lines.push(kv("Missing Pkgs", &sys.missing_packages.len().to_string(), p));
                lines.push(kv("Stale sbin", &sys.stale_sbin_files.len().to_string(), p));
                lines.push(Line::raw(""));
                lines.push(section_heading("Findings", p));
                if sys.issues.is_empty() {
                    lines.push(Line::from(Span::styled(
                        "✓ All system/ files and system_packages match.",
                        Style::default().fg(p.ok),
                    )));
                } else {
                    for issue in &sys.issues {
                        lines.push(Line::from(Span::styled(
                            format!("! {issue}"),
                            Style::default().fg(p.warn),
                        )));
                    }
                }
            }
        }
    }

    let detail = Paragraph::new(lines)
        .block(styled_block(
            Line::from(Span::styled(" Inspector  (s: sync · d: diff · c: check) ", Style::default().fg(p.info))),
            p,
            false,
        ))
        .wrap(Wrap { trim: false });
    frame.render_widget(detail, cols[1]);
}

fn render_themes(frame: &mut Frame, app: &App, p: TuiTheme, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(44), Constraint::Percentage(56)])
        .split(area);

    let items: Vec<ListItem> = app
        .themes
        .iter()
        .map(|item| {
            let marker = if item.active { "★" } else { " " };
            let mode_badge = if item.spec.appearance == "light" { "LIGHT" } else { "DARK " };
            ListItem::new(vec![
                Line::from(vec![
                    Span::styled(
                        format!("{marker} "),
                        Style::default().fg(p.warn).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        format!("{:<20}", item.slug),
                        Style::default().fg(p.fg_bright).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        format!(" {mode_badge} "),
                        Style::default().fg(p.bg).bg(if item.spec.appearance == "light" { p.warn } else { p.info }),
                    ),
                ]),
                Line::from(vec![
                    Span::raw("  "),
                    Span::styled(item.spec.description.clone(), Style::default().fg(p.fg)),
                ]),
            ])
        })
        .collect();

    let mut state = ListState::default();
    if !app.themes.is_empty() {
        state.select(Some(app.theme_idx));
    }
    let list = List::new(items)
        .block(styled_block(
            Line::from(Span::styled(
                " Theme Studio (live preview on move · Enter: apply) ",
                Style::default().fg(p.primary).add_modifier(Modifier::BOLD),
            )),
            p,
            true,
        ))
        .highlight_style(Style::default().bg(p.surface))
        .highlight_symbol("▸ ");
    frame.render_stateful_widget(list, cols[0], &mut state);

    let mut lines: Vec<Line> = Vec::new();
    if let Some(item) = app.themes.get(app.theme_idx) {
        let s = &item.spec;
        lines.push(kv("Variant", &item.slug, p));
        lines.push(kv("Scheme", &s.scheme, p));
        lines.push(kv("Appearance", &s.appearance, p));
        lines.push(kv("Targets", "kitty · tmux · fzf · starship · nvim · btop · zathura · herdr", p));
        lines.push(Line::raw(""));
        lines.push(section_heading("Palette Swatches", p));

        let swatches = [
            ("bg", &s.fzf.bg),
            ("surface", &s.fzf.bg_plus),
            ("fg", &s.fzf.fg),
            ("fg_bright", &s.fzf.fg_plus),
            ("primary", &s.starship.primary),
            ("accent", &s.starship.accent),
            ("info", &s.starship.lang),
            ("vcs", &s.starship.vcs),
            ("warn", &s.starship.warn),
            ("error", &s.starship.error),
        ];
        for chunk in swatches.chunks(2) {
            let mut spans = Vec::new();
            for (label, hex) in chunk {
                let col = parse_hex(hex).unwrap_or(p.fg);
                spans.push(Span::styled("  ████ ", Style::default().fg(col)));
                spans.push(Span::styled(
                    format!("{label:<10}"),
                    Style::default().fg(p.fg_bright),
                ));
                spans.push(Span::styled(
                    format!("{hex:<9} "),
                    Style::default().fg(p.fg),
                ));
            }
            lines.push(Line::from(spans));
        }

        lines.push(Line::raw(""));
        lines.push(section_heading("Prompt Preview", p));
        let user_host = format!(
            "  {}@{} ",
            std::env::var("USER").unwrap_or_else(|_| "user".to_string()),
            app.snapshot
                .report
                .checks
                .chezmoi
                .machine
                .as_deref()
                .unwrap_or("host")
        );
        lines.push(Line::from(vec![
            Span::styled(user_host, Style::default().fg(p.primary).add_modifier(Modifier::BOLD)),
            Span::styled("~/dotfiles ", Style::default().fg(p.info).add_modifier(Modifier::BOLD)),
            Span::styled(" main ", Style::default().fg(p.vcs)),
            Span::styled("pixi ", Style::default().fg(p.accent)),
            Span::styled("!1 ", Style::default().fg(p.warn)),
            Span::styled("❯ ", Style::default().fg(p.primary).add_modifier(Modifier::BOLD)),
            Span::styled("dotfiles doctor", Style::default().fg(p.fg_bright)),
        ]));
        lines.push(Line::raw(""));
        lines.push(Line::from(Span::styled(
            "  Press Enter to switch across all tools, or 'p' for dry-run diff.",
            Style::default().fg(p.accent),
        )));
    } else {
        lines.push(Line::from(Span::styled(
            "No theme metadata loaded from chezmoi.",
            Style::default().fg(p.warn),
        )));
    }

    let preview = Paragraph::new(lines)
        .block(styled_block(
            Line::from(Span::styled(" Live Preview ", Style::default().fg(p.info))),
            p,
            false,
        ))
        .wrap(Wrap { trim: false });
    frame.render_widget(preview, cols[1]);
}

fn render_agents(frame: &mut Frame, app: &App, p: TuiTheme, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(42), Constraint::Percentage(58)])
        .split(area);

    let ag = &app.snapshot.report.checks.agents;
    let items: Vec<ListItem> = AGENT_NAMES
        .iter()
        .map(|name| {
            let entry = ag.agents.get(*name);
            let installed = entry.and_then(|e| e.binary.as_ref()).is_some();
            let guard_ok = if *name == "pi" {
                entry.and_then(|e| e.guard_extension).unwrap_or(false)
            } else {
                entry.and_then(|e| e.key_guard_configured).unwrap_or(false)
            };
            let badge = if installed { " ON " } else { "OFF " };
            ListItem::new(vec![
                Line::from(vec![
                    Span::styled(
                        format!(" {badge} "),
                        Style::default()
                            .fg(p.bg)
                            .bg(if installed { p.ok } else { p.border })
                            .add_modifier(Modifier::BOLD),
                    ),
                    Span::raw(" "),
                    Span::styled(
                        *name,
                        Style::default().fg(p.fg_bright).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        if guard_ok { "  [guard ✓]" } else { "  [guard ✗]" },
                        Style::default().fg(if guard_ok { p.vcs } else { p.warn }),
                    ),
                ]),
                Line::from(vec![
                    Span::raw("        "),
                    Span::styled(
                        entry
                            .and_then(|e| e.binary.as_deref())
                            .unwrap_or("not installed on this host"),
                        Style::default().fg(p.fg),
                    ),
                ]),
            ])
        })
        .collect();

    let mut state = ListState::default();
    state.select(Some(app.agent_idx));
    let list = List::new(items)
        .block(styled_block(
            Line::from(Span::styled(
                " 4-Agent Control Plane ",
                Style::default().fg(p.primary).add_modifier(Modifier::BOLD),
            )),
            p,
            true,
        ))
        .highlight_style(Style::default().bg(p.surface))
        .highlight_symbol("▸ ");
    frame.render_stateful_widget(list, cols[0], &mut state);

    let selected_agent = AGENT_NAMES[app.agent_idx];
    let mut lines = Vec::new();
    lines.push(section_heading(&format!("Agent: {selected_agent}"), p));
    if let Some(entry) = ag.agents.get(selected_agent) {
        lines.push(kv(
            "Binary",
            entry.binary.as_deref().unwrap_or("not installed"),
            p,
        ));
        lines.push(kv(
            "Shared AGENTS.md",
            if entry.instructions { "linked ✓" } else { "missing" },
            p,
        ));
        lines.push(kv("Default Wrapper", "agent-jail --wrap (escape: unjail <agent>)", p));
        if selected_agent == "codex" {
            lines.push(kv(
                "Sandbox Mode",
                "-s danger-full-access inside agent-jail (keeps gh.rules)",
                p,
            ));
        } else if selected_agent == "agy" {
            lines.push(kv(
                "Default Flags",
                "--dangerously-skip-permissions + key-guard PreToolUse",
                p,
            ));
        }
    }

    lines.push(Line::raw(""));
    lines.push(section_heading("OS Sandbox (agent-jail / policy.json)", p));
    lines.push(kv(
        "Backends",
        &if ag.agent_jail_backends.is_empty() {
            "none".to_string()
        } else {
            ag.agent_jail_backends.join(", ")
        },
        p,
    ));
    if let Some(policy) = &app.snapshot.policy {
        if let Some(pa) = policy.jail.agents.get(selected_agent) {
            lines.push(kv("Agent RW dirs", &pa.rw_dirs.join(", "), p));
            if !pa.rw_files.is_empty() {
                lines.push(kv("Agent RW files", &pa.rw_files.join(", "), p));
            }
            let own = if pa.own_auth_files.is_empty() {
                "(none)".to_string()
            } else {
                pa.own_auth_files.join(", ")
            };
            lines.push(kv("Own Auth (allowed)", &own, p));
        }
        lines.push(kv("Common RW dirs", &policy.jail.common_rw_dirs.join(", "), p));
        if !policy.jail.machine_rw_dirs.is_empty() {
            lines.push(kv(
                "Machine Pixi RW",
                &policy.jail.machine_rw_dirs.join(", "),
                p,
            ));
        }
        lines.push(kv("Masked Dirs", &policy.secrets.masked_dirs.join(", "), p));
        lines.push(kv(
            "Masked Files",
            &format!("{} entries + all ~/.ssh private keys", policy.secrets.masked_files.len()),
            p,
        ));
    }

    lines.push(Line::raw(""));
    lines.push(Line::from(Span::styled(
        "  Enter/x: dry-run agent-jail plan · S: agent skills",
        Style::default().fg(p.accent),
    )));

    let inspector = Paragraph::new(lines)
        .block(styled_block(
            Line::from(Span::styled(" Sandbox & Policy Inspector ", Style::default().fg(p.info))),
            p,
            false,
        ))
        .wrap(Wrap { trim: false });
    frame.render_widget(inspector, cols[1]);
}

fn render_toolchain(frame: &mut Frame, app: &App, p: TuiTheme, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(52), Constraint::Percentage(48)])
        .split(area);

    let items: Vec<ListItem> = app
        .toolchain_rows
        .iter()
        .map(|row| {
            let cat_color = match row.category {
                "mise" => p.primary,
                "fetch" => p.vcs,
                _ => p.accent,
            };
            ListItem::new(Line::from(vec![
                Span::styled(
                    format!(" {:<5} ", row.category),
                    Style::default().fg(p.bg).bg(cat_color).add_modifier(Modifier::BOLD),
                ),
                Span::raw(" "),
                Span::styled(
                    format!("{:<20}", row.id),
                    Style::default().fg(p.fg_bright).add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    row.status.clone(),
                    Style::default().fg(if row.ok { p.ok } else { p.warn }),
                ),
            ]))
        })
        .collect();

    let mut state = ListState::default();
    if !app.toolchain_rows.is_empty() {
        state.select(Some(app.toolchain_idx));
    }
    let list = List::new(items)
        .block(styled_block(
            Line::from(Span::styled(
                " Managed Toolchain (mise + dotfiles-fetch) ",
                Style::default().fg(p.primary).add_modifier(Modifier::BOLD),
            )),
            p,
            true,
        ))
        .highlight_style(Style::default().bg(p.surface))
        .highlight_symbol("▸ ");
    frame.render_stateful_widget(list, cols[0], &mut state);

    let mut lines = Vec::new();
    let tc = &app.snapshot.report.checks.toolchain;
    if let Some(row) = app.toolchain_rows.get(app.toolchain_idx) {
        lines.push(kv("Item", &row.id, p));
        lines.push(kv("Layer", row.category, p));
        lines.push(kv("Source", &row.detail, p));
        lines.push(kv("Status", &row.status, p));
        if row.category == "mise"
            && let Some(spec) = app
                .snapshot
                .data
                .as_ref()
                .and_then(|d| d.mise.get(&row.id))
            && !spec.description.is_empty()
        {
            lines.push(kv("Notes", &spec.description, p));
        }
    }
    lines.push(Line::raw(""));
    lines.push(section_heading("Managers", p));
    lines.push(kv("pixi", tc.pixi.as_deref().unwrap_or("missing"), p));
    lines.push(kv("mise", tc.mise.as_deref().unwrap_or("missing"), p));
    lines.push(Line::raw(""));
    lines.push(Line::from(Span::styled(
        "  U: upgrade dry-run · u: fetch outdated · f: fetch sync",
        Style::default().fg(p.accent),
    )));

    let panel = Paragraph::new(lines)
        .block(styled_block(
            Line::from(Span::styled(" Package Detail ", Style::default().fg(p.info))),
            p,
            false,
        ))
        .wrap(Wrap { trim: false });
    frame.render_widget(panel, cols[1]);
}

fn render_machines(frame: &mut Frame, app: &App, p: TuiTheme, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(36), Constraint::Percentage(64)])
        .split(area);

    let current = app
        .snapshot
        .report
        .checks
        .chezmoi
        .machine
        .as_deref()
        .unwrap_or("");

    let items: Vec<ListItem> = app
        .machine_names
        .iter()
        .map(|name| {
            let is_cur = name == current;
            let spec = app.snapshot.data.as_ref().and_then(|d| d.machines.get(name));
            let count = spec.map(|m| m.bundles.len()).unwrap_or(0);
            let is_virtual = spec.map(|m| m.is_virtual).unwrap_or(false);
            let mut spans = vec![
                Span::styled(
                    if is_cur { "★ " } else { "  " },
                    Style::default().fg(p.warn).add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    format!("{name:<13}"),
                    Style::default()
                        .fg(if is_virtual { p.fg } else { p.fg_bright })
                        .add_modifier(if is_virtual { Modifier::empty() } else { Modifier::BOLD }),
                ),
            ];
            if is_virtual {
                spans.push(Span::styled("[profile] ", Style::default().fg(p.info)));
            }
            spans.push(Span::styled(
                format!("{count} bundles"),
                Style::default().fg(p.fg),
            ));
            ListItem::new(Line::from(spans))
        })
        .collect();

    let mut state = ListState::default();
    if !app.machine_names.is_empty() {
        state.select(Some(app.machine_idx));
    }
    let list = List::new(items)
        .block(styled_block(
            Line::from(Span::styled(
                " Fleet (.chezmoidata/machines.toml) ",
                Style::default().fg(p.primary).add_modifier(Modifier::BOLD),
            )),
            p,
            true,
        ))
        .highlight_style(Style::default().bg(p.surface))
        .highlight_symbol("▸ ");
    frame.render_stateful_widget(list, cols[0], &mut state);

    let mut lines = Vec::new();
    if let Some(name) = app.machine_names.get(app.machine_idx)
        && let Some(spec) = app.snapshot.data.as_ref().and_then(|d| d.machines.get(name))
    {
        lines.push(kv("Machine", name, p));
        lines.push(kv(
            "Kind",
            if spec.is_virtual {
                "virtual fallback / CI profile"
            } else {
                "physical / managed host"
            },
            p,
        ));
        lines.push(kv("Role", &spec.description, p));
        lines.push(kv("Sudo", if spec.sudo { "yes" } else { "no (rootless)" }, p));
        if !spec.docs.is_empty() {
            lines.push(kv("Encrypted Doc", &spec.docs, p));
        }
        lines.push(Line::raw(""));
        lines.push(section_heading("Selected Bundles", p));
        lines.push(Line::from(Span::styled(
            if spec.bundles.is_empty() {
                "(none)".to_string()
            } else {
                spec.bundles.join(" · ")
            },
            Style::default().fg(p.vcs),
        )));
        if !spec.pixi.cache_dir.is_empty() || !spec.pixi.detached_environments.is_empty() {
            lines.push(Line::raw(""));
            lines.push(section_heading("Pixi Relocations (auto-bound RW in agent-jail)", p));
            if !spec.pixi.cache_dir.is_empty() {
                lines.push(kv("cacheDir", &spec.pixi.cache_dir, p));
            }
            if !spec.pixi.detached_environments.is_empty() {
                lines.push(kv("detachedEnvs", &spec.pixi.detached_environments, p));
            }
            if !spec.pixi.repodata_dir.is_empty() {
                lines.push(kv("repodataDir", &spec.pixi.repodata_dir, p));
            }
        }
    }

    let detail = Paragraph::new(lines)
        .block(styled_block(
            Line::from(Span::styled(" Machine Profile ", Style::default().fg(p.info))),
            p,
            false,
        ))
        .wrap(Wrap { trim: false });
    frame.render_widget(detail, cols[1]);
}

fn render_host(frame: &mut Frame, app: &App, p: TuiTheme, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(42), Constraint::Percentage(58)])
        .split(area);

    let h = &app.snapshot.host;

    let items: Vec<ListItem> = if app.host_controls.is_empty() {
        vec![ListItem::new(Line::from(Span::styled(
            "  No managed hardware controls on this profile.",
            Style::default().fg(p.fg),
        )))]
    } else {
        app.host_controls
            .iter()
            .map(|kind| {
                let (badge, badge_bg, title, sub) = match kind {
                    HostControlKind::Keymap => {
                        let km = &h.keymap;
                        if !km.installed {
                            ("MISS ", p.warn, "Keymap (keyd)", "not installed — press 'a'".to_string())
                        } else if km.active {
                            (" ON  ", p.ok, "Keymap (keyd)", format!("HHKB remap · {} keyboard(s)", km.keyboards.len()))
                        } else {
                            (" OFF ", p.warn, "Keymap (keyd)", "standard passthrough".to_string())
                        }
                    }
                    HostControlKind::Dgpu => {
                        let d = h.dgpu.as_ref().expect("dgpu present");
                        let (b, c) = match d.setting.as_str() {
                            "on" => (" ON  ", p.ok),
                            "off" => (" OFF ", p.info),
                            _ => ("WARN ", p.warn),
                        };
                        (b, c, "dGPU Display", format!("GNOME: {}", d.gnome))
                    }
                    HostControlKind::Battery => {
                        let b = h.battery.as_ref().expect("battery present");
                        let (badge, color) = if !b.available {
                            (" N/A ", p.border)
                        } else if b.persistent_mode == "full" {
                            ("FULL ", p.warn)
                        } else {
                            ("LIMIT", p.ok)
                        };
                        let live = b.live_mode.as_deref().unwrap_or("unavailable");
                        (badge, color, "Battery Limit", format!("live={live} · persistent={}", b.persistent_mode))
                    }
                    HostControlKind::Refresh => {
                        let r = h.refresh.as_ref().expect("refresh present");
                        let (b, c) = if r.active { (" ON  ", p.ok) } else { (" OFF ", p.warn) };
                        (b, c, "Refresh Rate", format!("60 Hz on battery ({})", r.service_state))
                    }
                    HostControlKind::Logid => {
                        let l = h.logid.as_ref().expect("logid present");
                        let (b, c) = if l.binary.is_none() {
                            ("MISS ", p.warn)
                        } else if l.active {
                            (" ON  ", p.ok)
                        } else {
                            (" OFF ", p.warn)
                        };
                        (b, c, "LogiOps (logid)", format!("MX Master 3 ({})", l.service_state))
                    }
                };
                ListItem::new(vec![
                    Line::from(vec![
                        Span::styled(
                            format!(" {badge} "),
                            Style::default()
                                .fg(p.bg)
                                .bg(badge_bg)
                                .add_modifier(Modifier::BOLD),
                        ),
                        Span::raw(" "),
                        Span::styled(
                            title,
                            Style::default().fg(p.fg_bright).add_modifier(Modifier::BOLD),
                        ),
                    ]),
                    Line::from(vec![
                        Span::raw("        "),
                        Span::styled(sub, Style::default().fg(p.fg)),
                    ]),
                ])
            })
            .collect()
    };

    let mut state = ListState::default();
    if !app.host_controls.is_empty() {
        state.select(Some(app.host_idx));
    }
    let list = List::new(items)
        .block(styled_block(
            Line::from(Span::styled(
                " Host Controls (Space/t: toggle · R: reload) ",
                Style::default().fg(p.primary).add_modifier(Modifier::BOLD),
            )),
            p,
            true,
        ))
        .highlight_style(Style::default().bg(p.surface))
        .highlight_symbol("▸ ");
    frame.render_stateful_widget(list, cols[0], &mut state);

    let mut lines: Vec<Line> = Vec::new();
    match app.host_controls.get(app.host_idx) {
        Some(HostControlKind::Keymap) => {
            let km = &h.keymap;
            let boot_str = match km.enabled {
                Some(true) => "enabled (starts at boot)",
                Some(false) => "disabled",
                None => "-",
            };
            lines.push(section_heading("Keymap Daemon (keyd)", p));
            lines.push(kv("Service", &format!("keyd.service ({})", km.service_state), p));
            lines.push(kv("Boot", boot_str, p));
            lines.push(kv(
                "Config",
                if km.config_present {
                    "/etc/keyd/default.conf (present)"
                } else {
                    "/etc/keyd/default.conf (missing)"
                },
                p,
            ));
            lines.push(kv(
                "Polkit Rule",
                if km.polkit_rule_present {
                    "passwordless toggle ready ✓"
                } else {
                    "missing (press 'a' to apply)"
                },
                p,
            ));
            lines.push(Line::raw(""));
            lines.push(section_heading("HHKB Mapping ([main] + [hhkb_fn])", p));
            lines.push(kv("Base Layer", "CapsLock → Left Ctrl · Right Ctrl → Fn (hold)", p));
            lines.push(kv("Diamond Arrows", "[ = Up · ; = Left · ' = Right · / = Down", p));
            lines.push(kv("Navigation", "k = Home · , = End · l = PgUp · . = PgDn", p));
            lines.push(kv("Audio", "a = Vol- · s = Vol+ · d = Mute", p));
            lines.push(kv("Edit / Lock", "Bksp = Del · Tab = CapsLock · \\ = Ins · i = PrtSc", p));
            lines.push(kv("Function Row", "1..0, -, =  →  F1..F12", p));
            lines.push(Line::raw(""));
            lines.push(section_heading("Connected Keyboards & Exclusions", p));
            lines.push(kv(
                "Excluded [ids]",
                &if km.excluded_ids.is_empty() {
                    "(none)".to_string()
                } else {
                    km.excluded_ids.join(" · ")
                },
                p,
            ));
            for kb in &km.keyboards {
                let tag = if kb.internal { " (internal)" } else { "" };
                let hint = if !kb.internal && !kb.excluded {
                    format!("  (exclude: -{})", kb.id)
                } else {
                    String::new()
                };
                let color = match kb.state.as_str() {
                    "remapped" => p.ok,
                    "excluded" => p.info,
                    _ => p.fg,
                };
                lines.push(Line::from(vec![
                    Span::styled(format!("  [{}] ", kb.state), Style::default().fg(color)),
                    Span::styled(format!("{} ", kb.id), Style::default().fg(p.accent).add_modifier(Modifier::BOLD)),
                    Span::styled(format!("{}{}", kb.name, tag), Style::default().fg(p.fg_bright)),
                    Span::styled(hint, Style::default().fg(p.fg)),
                ]));
            }
            lines.push(Line::raw(""));
            lines.push(Line::from(Span::styled(
                "  Space/t: toggle · R: reload · e: edit default.conf · a: sudo apply",
                Style::default().fg(p.accent),
            )));
        }
        Some(HostControlKind::Dgpu) => {
            if let Some(dgpu) = &h.dgpu {
                lines.push(section_heading("NVIDIA dGPU Display Output", p));
                lines.push(kv("Device", dgpu.pci.as_deref().unwrap_or("-"), p));
                lines.push(kv("Setting", &dgpu.setting, p));
                lines.push(kv("GNOME", &dgpu.gnome, p));
                lines.push(kv("Power", &dgpu.power, p));
                lines.push(kv("Open By", &dgpu.open_by, p));
                lines.push(kv("Backend", "/usr/local/libexec/dgpu-display", p));
                if !dgpu.advice.is_empty() {
                    lines.push(Line::raw(""));
                    lines.push(section_heading("Advice", p));
                    for line in &dgpu.advice {
                        lines.push(Line::from(Span::styled(
                            format!("  ! {line}"),
                            Style::default().fg(p.warn),
                        )));
                    }
                }
                lines.push(Line::raw(""));
                lines.push(Line::from(Span::styled(
                    "  Space/t: toggle on/off (uses sudo; pauses to show logout guidance)",
                    Style::default().fg(p.accent),
                )));
            }
        }
        Some(HostControlKind::Battery) => {
            if let Some(bat) = &h.battery {
                lines.push(section_heading("Battery Charge Limit (BAT0)", p));
                lines.push(kv(
                    "Persistent Mode",
                    if bat.persistent_mode == "full" {
                        "full (~100% Standard; marker present)"
                    } else {
                        "limit (~80% Long_Life; enforced at boot/resume)"
                    },
                    p,
                ));
                lines.push(kv("Live Sysfs", bat.live_mode.as_deref().unwrap_or("unavailable"), p));
                lines.push(kv("Available Modes", &bat.available_modes.join(" · "), p));
                lines.push(kv(
                    "Boot/Resume Unit",
                    match bat.service_enabled {
                        Some(true) => "battery-charge-limit.service (enabled)",
                        Some(false) => "battery-charge-limit.service (disabled)",
                        None => "unknown",
                    },
                    p,
                ));
                lines.push(kv("State Marker", "/var/lib/dotfiles/battery-full", p));
                lines.push(Line::raw(""));
                lines.push(Line::from(Span::styled(
                    "  Space/t: toggle persistent limit (80%) ↔ full (100%) via sudo",
                    Style::default().fg(p.accent),
                )));
            }
        }
        Some(HostControlKind::Refresh) => {
            if let Some(rf) = &h.refresh {
                lines.push(section_heading("Display Refresh Rate on Power", p));
                lines.push(kv("User Unit", &format!("refresh-rate-on-power.service ({})", rf.service_state), p));
                lines.push(kv("Unit File", if rf.unit_present { "deployed ✓" } else { "missing" }, p));
                lines.push(kv("Helper", "~/.local/libexec/dotfiles/refresh-rate-on-power", p));
                lines.push(kv("Behavior", "Drops panel to 60 Hz on battery, full rate on AC", p));
                lines.push(Line::raw(""));
                lines.push(Line::from(Span::styled(
                    "  Space/t: start/stop (passwordless) · R: restart",
                    Style::default().fg(p.accent),
                )));
            }
        }
        Some(HostControlKind::Logid) => {
            if let Some(lg) = &h.logid {
                lines.push(section_heading("Logitech MX Master 3 (logid)", p));
                lines.push(kv("Service", &format!("logid.service ({})", lg.service_state), p));
                lines.push(kv("Binary", lg.binary.as_deref().unwrap_or("not installed"), p));
                lines.push(kv(
                    "Config",
                    if lg.config_present { "/etc/logid.cfg (present)" } else { "/etc/logid.cfg (missing)" },
                    p,
                ));
                lines.push(kv("Source", "system/desktop/etc/logid.cfg (shared desktop)", p));
                lines.push(Line::raw(""));
                lines.push(Line::from(Span::styled(
                    "  Space/t/R: restart via sudo · e: edit logid.cfg · a: sudo apply",
                    Style::default().fg(p.accent),
                )));
            }
        }
        None => {
            lines.push(section_heading("Host Environment (Read-Only)", p));
            lines.push(kv("OS", &h.system.os_pretty, p));
            lines.push(kv("Kernel", &h.system.kernel, p));
            lines.push(kv("Uptime", &h.system.uptime, p));
            lines.push(Line::raw(""));
            lines.push(Line::from(Span::styled(
                "  This machine profile has no managed personal hardware switches.",
                Style::default().fg(p.fg),
            )));
        }
    }

    let inspector = Paragraph::new(lines)
        .block(styled_block(
            Line::from(Span::styled(" Host Inspector ", Style::default().fg(p.info))),
            p,
            false,
        ))
        .wrap(Wrap { trim: false });
    frame.render_widget(inspector, cols[1]);
}

fn render_footer(frame: &mut Frame, app: &App, p: TuiTheme, area: Rect) {
    let hints = match app.tab {
        Tab::Overview => "j/k select · 1-6/Tab switch · s sync · d diff · c check · r refresh · ? help · q quit",
        Tab::Themes => "j/k live-preview · Enter apply theme · p dry-run diff · 1-6/Tab switch · q quit",
        Tab::Agents => "j/k select agent · Enter/x jail dry-run · S skills · r refresh · q quit",
        Tab::Toolchain => "j/k select tool · U upgrade dry-run · u fetch outdated · f fetch sync · r refresh · q quit",
        Tab::Machines => "j/k select machine · 1-6/Tab switch · r refresh · ? help · q quit",
        Tab::Host => "j/k control · Space/Enter/t toggle · R reload · e edit config · a sudo apply · r refresh · q quit",
    };

    let mut lines = vec![Line::from(vec![
        Span::styled(" ", Style::default()),
        Span::styled(hints, Style::default().fg(p.fg)),
    ])];
    if let Some(msg) = &app.status_msg {
        lines.push(Line::from(vec![
            Span::styled(" › ", Style::default().fg(p.primary).add_modifier(Modifier::BOLD)),
            Span::styled(msg.clone(), Style::default().fg(p.accent)),
        ]));
    }
    frame.render_widget(
        Paragraph::new(lines).style(Style::default().bg(p.bg).fg(p.fg)),
        area,
    );
}

fn render_help_modal(frame: &mut Frame, p: TuiTheme, area: Rect) {
    let width = area.width.min(68);
    let height = area.height.min(20);
    let rect = Rect {
        x: area.x + area.width.saturating_sub(width) / 2,
        y: area.y + area.height.saturating_sub(height) / 2,
        width,
        height,
    };
    frame.render_widget(Clear, rect);
    let lines = vec![
        kv("1 - 6 / Tab / h,l", "Switch tabs", p),
        kv("j / k / Up / Down", "Move selection (live-previews themes on Tab 2)", p),
        kv("r", "Async refresh doctor & host state", p),
        kv("s / d / c", "Overview: sync dotfiles / chezmoi diff / mise check", p),
        kv("Enter / p", "Themes: apply selected theme / dry-run diff", p),
        kv("Enter / x / S", "Agents: jail dry-run / skills", p),
        kv("U / u / f", "Toolchain: upgrade dry-run / fetch outdated / fetch sync", p),
        kv("Space / R / e / a", "Host: toggle / reload / edit config / sudo apply", p),
        kv("? / Esc / q", "Toggle help / Quit", p),
    ];
    let modal = Paragraph::new(lines)
        .block(styled_block(
            Line::from(Span::styled(
                " Keybindings (? or Esc to close) ",
                Style::default().fg(p.primary).add_modifier(Modifier::BOLD),
            )),
            p,
            true,
        ))
        .wrap(Wrap { trim: false });
    frame.render_widget(modal, rect);
}

fn kv<'a>(key: &'a str, val: &str, p: TuiTheme) -> Line<'a> {
    Line::from(vec![
        Span::styled(format!("  {key:<18} "), Style::default().fg(p.info).add_modifier(Modifier::BOLD)),
        Span::styled(val.to_string(), Style::default().fg(p.fg_bright)),
    ])
}

fn section_heading(title: &str, p: TuiTheme) -> Line<'static> {
    Line::from(Span::styled(
        format!("  {title}"),
        Style::default().fg(p.primary).add_modifier(Modifier::BOLD),
    ))
}
