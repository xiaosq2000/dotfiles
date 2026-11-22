pub mod app;
pub mod theme;
pub mod ui;

use crate::doctor::{build_snapshot, home_dir};
use crate::keymap;
use crate::model::FullSnapshot;
use crate::tui::app::{AGENT_NAMES, App, PendingAction, Tab};
use anyhow::Result;
use crossterm::event::{
    self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind, KeyModifiers,
    MouseButton, MouseEventKind,
};
use crossterm::execute;
use crossterm::terminal::{
    EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode,
};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use std::env;
use std::io::{self, BufRead, Write};
use std::path::PathBuf;
use std::process::Command;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

fn spawn_refresh() -> mpsc::Receiver<FullSnapshot> {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let _ = tx.send(build_snapshot());
    });
    rx
}

fn enter_tui() -> Result<Terminal<CrosstermBackend<io::Stdout>>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;
    terminal.clear()?;
    Ok(terminal)
}

fn leave_tui(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) {
    let _ = disable_raw_mode();
    let _ = execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    );
    let _ = terminal.show_cursor();
}

pub fn run() -> Result<i32> {
    let initial = build_snapshot();
    let mut app = App::new(initial);
    let mut terminal = enter_tui()?;
    let mut refresh_rx: Option<mpsc::Receiver<FullSnapshot>> = None;

    let result = loop {
        if let Some(rx) = &refresh_rx
            && let Ok(snap) = rx.try_recv()
        {
            app.update_snapshot(snap);
            app.status_msg = Some("Refreshed host state.".to_string());
            refresh_rx = None;
        }

        if let Err(err) = terminal.draw(|f| ui::render(f, &app)) {
            break Err(err.into());
        }

        if let Some(action) = app.pending_action.take() {
            leave_tui(&mut terminal);
            let msg = execute_action(action);
            terminal = enter_tui()?;
            app.status_msg = Some(msg);
            app.refreshing = true;
            refresh_rx = Some(spawn_refresh());
            continue;
        }

        if app.should_quit {
            break Ok(0);
        }

        if event::poll(Duration::from_millis(80))? {
            match event::read()? {
                Event::Key(key) if key.kind == KeyEventKind::Press => {
                    handle_key(&mut app, key.code, key.modifiers, &mut refresh_rx);
                }
                Event::Mouse(mouse) => {
                    if mouse.kind == MouseEventKind::Down(MouseButton::Left) && mouse.row <= 2 {
                        // Clicking the top tab bar switches tabs smoothly.
                        if let Some(tab) = Tab::at_column(mouse.column) {
                            app.tab = tab;
                        }
                    } else if mouse.kind == MouseEventKind::ScrollDown {
                        app.move_down();
                    } else if mouse.kind == MouseEventKind::ScrollUp {
                        app.move_up();
                    }
                }
                _ => {}
            }
        } else {
            app.tick = app.tick.wrapping_add(1);
        }
    };

    leave_tui(&mut terminal);
    result
}

fn handle_key(
    app: &mut App,
    code: KeyCode,
    mods: KeyModifiers,
    refresh_rx: &mut Option<mpsc::Receiver<FullSnapshot>>,
) {
    if code == KeyCode::Char('c') && mods.contains(KeyModifiers::CONTROL) {
        app.should_quit = true;
        return;
    }

    if app.show_help {
        if matches!(code, KeyCode::Esc | KeyCode::Char('?') | KeyCode::Char('q')) {
            app.show_help = false;
        }
        return;
    }

    match code {
        KeyCode::Char('q') | KeyCode::Esc => app.should_quit = true,
        KeyCode::Char('?') => app.show_help = true,
        KeyCode::Char('1') => app.tab = Tab::Overview,
        KeyCode::Char('2') => app.tab = Tab::Themes,
        KeyCode::Char('3') => app.tab = Tab::Agents,
        KeyCode::Char('4') => app.tab = Tab::Toolchain,
        KeyCode::Char('5') => app.tab = Tab::Machines,
        KeyCode::Char('6') => app.tab = Tab::Keymap,
        KeyCode::Tab | KeyCode::Right | KeyCode::Char('l') => app.tab = app.tab.next(),
        KeyCode::BackTab | KeyCode::Left | KeyCode::Char('h') => app.tab = app.tab.prev(),
        KeyCode::Down | KeyCode::Char('j') if app.tab != Tab::Agents || code == KeyCode::Down => {
            app.move_down();
        }
        KeyCode::Char('j') if app.tab == Tab::Agents => {
            // In Agents tab, Down/Up moves, and 'j' previews agent-jail plan (Wait: keep j/k vim navigation!).
            // Let's keep j/k ALWAYS vim navigation across all tabs, and use 'x' for jail dry-run or handle below.
            app.move_down();
        }
        KeyCode::Up | KeyCode::Char('k') => app.move_up(),
        KeyCode::Char('r') => {
            if !app.refreshing {
                app.refreshing = true;
                app.status_msg = Some("Refreshing host state...".to_string());
                *refresh_rx = Some(spawn_refresh());
            }
        }
        KeyCode::Char('s') if app.tab == Tab::Overview => {
            app.pending_action = Some(PendingAction::RunCommand {
                label: "chezmoi apply".to_string(),
                prog: "chezmoi".to_string(),
                args: vec!["apply".to_string()],
                pause: true,
            });
        }
        KeyCode::Char('d') if app.tab == Tab::Overview => {
            app.pending_action = Some(PendingAction::RunCommand {
                label: "chezmoi diff".to_string(),
                prog: "chezmoi".to_string(),
                args: vec!["diff".to_string(), "--exclude".to_string(), "externals".to_string()],
                pause: true,
            });
        }
        KeyCode::Char('c') if app.tab == Tab::Overview => {
            app.pending_action = Some(PendingAction::RunCommand {
                label: "dotfiles check".to_string(),
                prog: "mise".to_string(),
                args: vec!["run".to_string(), "check".to_string()],
                pause: true,
            });
        }
        KeyCode::Enter if app.tab == Tab::Themes => {
            if let Some(item) = app.themes.get(app.theme_idx) {
                let helper = home_dir().join(".local/libexec/dotfiles/theme");
                app.pending_action = Some(PendingAction::RunCommand {
                    label: format!("theme {}", item.slug),
                    prog: helper.to_string_lossy().into_owned(),
                    args: vec![item.slug.clone()],
                    pause: false,
                });
            }
        }
        KeyCode::Char('p') if app.tab == Tab::Themes => {
            if let Some(item) = app.themes.get(app.theme_idx) {
                let helper = home_dir().join(".local/libexec/dotfiles/theme");
                app.pending_action = Some(PendingAction::RunCommand {
                    label: format!("theme --dry-run {}", item.slug),
                    prog: helper.to_string_lossy().into_owned(),
                    args: vec!["--dry-run".to_string(), item.slug.clone()],
                    pause: true,
                });
            }
        }
        KeyCode::Enter | KeyCode::Char('x') if app.tab == Tab::Agents => {
            let agent = AGENT_NAMES[app.agent_idx];
            let helper = home_dir().join(".local/libexec/dotfiles/agent-jail");
            app.pending_action = Some(PendingAction::RunCommand {
                label: format!("agent-jail --wrap {agent} --dry-run"),
                prog: helper.to_string_lossy().into_owned(),
                args: vec![
                    "--wrap".to_string(),
                    agent.to_string(),
                    "--dry-run".to_string(),
                ],
                pause: true,
            });
        }
        KeyCode::Char('S') if app.tab == Tab::Agents => {
            let helper = home_dir().join(".local/libexec/dotfiles/agent-skills.sh");
            app.pending_action = Some(PendingAction::RunCommand {
                label: "agent skills".to_string(),
                prog: helper.to_string_lossy().into_owned(),
                args: vec![],
                pause: true,
            });
        }
        KeyCode::Char('u') if app.tab == Tab::Toolchain => {
            let helper = home_dir().join(".local/libexec/dotfiles/dotfiles-fetch");
            app.pending_action = Some(PendingAction::RunCommand {
                label: "dotfiles fetch outdated".to_string(),
                prog: helper.to_string_lossy().into_owned(),
                args: vec!["outdated".to_string()],
                pause: true,
            });
        }
        KeyCode::Char('U') if app.tab == Tab::Toolchain => {
            let helper = home_dir().join(".local/libexec/dotfiles/upgrade-toolchain.py");
            app.pending_action = Some(PendingAction::RunCommand {
                label: "dotfiles upgrade --dry-run".to_string(),
                prog: helper.to_string_lossy().into_owned(),
                args: vec!["--dry-run".to_string()],
                pause: true,
            });
        }
        KeyCode::Char('f') if app.tab == Tab::Toolchain => {
            let helper = home_dir().join(".local/libexec/dotfiles/dotfiles-fetch");
            app.pending_action = Some(PendingAction::RunCommand {
                label: "dotfiles fetch sync".to_string(),
                prog: helper.to_string_lossy().into_owned(),
                args: vec!["sync".to_string()],
                pause: true,
            });
        }
        KeyCode::Char(' ') | KeyCode::Enter | KeyCode::Char('t') if app.tab == Tab::Keymap => {
            toggle_keymap_in_tui(app);
        }
        KeyCode::Char('R') if app.tab == Tab::Keymap => {
            reload_keymap_in_tui(app);
        }
        KeyCode::Char('e') if app.tab == Tab::Keymap => {
            let source_root = app
                .snapshot
                .report
                .checks
                .chezmoi
                .source_path
                .as_deref()
                .map(PathBuf::from)
                .unwrap_or_else(|| home_dir().join(".local/share/chezmoi"));
            let cfg_src = source_root.join("system/desktop/etc/keyd/default.conf");
            let editor = env::var("EDITOR")
                .ok()
                .filter(|v| !v.trim().is_empty())
                .unwrap_or_else(|| "vi".to_string());
            app.pending_action = Some(PendingAction::RunCommand {
                label: format!("{editor} {}", cfg_src.display()),
                prog: editor,
                args: vec![cfg_src.to_string_lossy().into_owned()],
                pause: false,
            });
        }
        KeyCode::Char('a') if app.tab == Tab::Keymap => {
            app.pending_action = Some(PendingAction::RunCommand {
                label: "sudo -v && chezmoi apply".to_string(),
                prog: "sh".to_string(),
                args: vec!["-c".to_string(), "sudo -v && chezmoi apply".to_string()],
                pause: true,
            });
        }
        _ => {}
    }
}

fn toggle_keymap_in_tui(app: &mut App) {
    if !app.snapshot.keymap.installed {
        app.status_msg = Some(
            "keyd is not installed — press 'a' to run `sudo -v && chezmoi apply`.".to_string(),
        );
        return;
    }
    let target_on = !app.snapshot.keymap.active;
    if target_on && !app.snapshot.keymap.config_present {
        app.status_msg = Some(format!(
            "{} missing — press 'a' to run `sudo -v && chezmoi apply`.",
            keymap::KEYD_CONFIG_PATH
        ));
        return;
    }

    let verb = if target_on { "start" } else { "stop" };
    if matches!(keymap::try_manage_unit_passwordless(verb), Ok(true)) {
        app.snapshot.keymap = keymap::collect_report();
        if !app.snapshot.keymap.keyboards.is_empty() {
            app.keymap_idx = app.keymap_idx.min(app.snapshot.keymap.keyboards.len() - 1);
        }
        keymap::notify_state(target_on);
        app.status_msg = Some(if target_on {
            "Keymap: ON (HHKB remap active)".to_string()
        } else {
            "Keymap: OFF (standard keyboard)".to_string()
        });
    } else {
        app.pending_action = Some(PendingAction::RunCommand {
            label: format!("sudo systemctl {verb} {}", keymap::KEYD_UNIT),
            prog: "sudo".to_string(),
            args: vec![
                "systemctl".to_string(),
                verb.to_string(),
                keymap::KEYD_UNIT.to_string(),
            ],
            pause: false,
        });
    }
}

fn reload_keymap_in_tui(app: &mut App) {
    if !app.snapshot.keymap.installed {
        app.status_msg = Some(
            "keyd is not installed — press 'a' to run `sudo -v && chezmoi apply`.".to_string(),
        );
        return;
    }
    if !app.snapshot.keymap.active {
        app.status_msg =
            Some("keyd is currently off — press Space/t to enable it first.".to_string());
        return;
    }
    if matches!(keymap::try_manage_unit_passwordless("restart"), Ok(true)) {
        app.snapshot.keymap = keymap::collect_report();
        app.status_msg = Some(format!("Reloaded {}.", keymap::KEYD_CONFIG_PATH));
    } else {
        app.pending_action = Some(PendingAction::RunCommand {
            label: format!("sudo systemctl restart {}", keymap::KEYD_UNIT),
            prog: "sudo".to_string(),
            args: vec![
                "systemctl".to_string(),
                "restart".to_string(),
                keymap::KEYD_UNIT.to_string(),
            ],
            pause: false,
        });
    }
}

fn execute_action(action: PendingAction) -> String {
    match action {
        PendingAction::RunCommand {
            label,
            prog,
            args,
            pause,
        } => {
            println!("\x1b[1m▸ {label}\x1b[0m\n");
            let status = Command::new(&prog).args(&args).status();
            let summary = match status {
                Ok(st) if st.success() => format!("Completed: {label}"),
                Ok(st) => format!("Failed (exit {}): {label}", st.code().unwrap_or(1)),
                Err(err) => format!("Error running {label}: {err}"),
            };
            if pause {
                print!("\n\x1b[2m[{summary}] Press Enter to return to TUI...\x1b[0m");
                let _ = io::stdout().flush();
                let mut line = String::new();
                let _ = io::stdin().lock().read_line(&mut line);
            }
            summary
        }
    }
}
