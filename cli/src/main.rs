mod commands;
mod doctor;
mod model;
mod tui;

use clap::{CommandFactory, Parser, Subcommand, ValueEnum};
use clap_complete::{Shell, generate};
use std::io::{self, IsTerminal};
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(
    name = "dotfiles",
    version,
    about = "Unified Rust CLI & TUI for managing and diagnosing this dotfiles environment",
    long_about = "Run `dotfiles` with no arguments on a terminal to open the interactive Ratatui TUI.\nRun `dotfiles <subcommand> --help` for subcommand usage."
)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Launch the interactive Ratatui dashboard & Theme Studio
    Tui,

    /// Check host health, drift, secrets, toolchain, agents, and sandbox
    Doctor {
        /// Emit machine-readable JSON
        #[arg(long)]
        json: bool,
    },

    /// Describe this machine or list known machines
    Machine {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },

    /// Switch or preview colour theme across tools
    Theme {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },

    /// Manage downloaded apps, fonts, and Zotero plugins via dotfiles-fetch
    Fetch {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },

    /// Run a coding agent or command inside the OS-level agent-jail sandbox
    Jail {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },

    /// Manage shared coding agent skills or inspect 4-agent status
    Agent {
        #[command(subcommand)]
        action: AgentAction,
    },

    /// Apply or update dotfiles via chezmoi (inherits caller network environment)
    Sync {
        /// Pull latest git changes before applying (`chezmoi update`)
        #[arg(long)]
        update: bool,
        /// Show what would change without modifying ~
        #[arg(long)]
        dry_run: bool,
        /// Skip external downloads during apply
        #[arg(long)]
        no_externals: bool,
    },

    /// Upgrade managed toolchains (mise, pixi, fetch, sheldon) without auto-committing
    Upgrade {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },

    /// Run repository pre-commit hooks and full test suite via `mise run check`
    Check,

    /// Apply dotfiles and run `dotfiles doctor`
    Bootstrap,

    /// Generate shell completion script (cached automatically on fpath in zsh)
    Completion {
        /// Target shell
        shell: CompletionShell,
    },

    /// Internal helper used by dynamic shell completions
    #[command(name = "__complete", hide = true)]
    InternalComplete {
        kind: String,
    },
}

#[derive(Subcommand, Debug)]
enum AgentAction {
    /// Inspect or sync shared agent skills
    Skills {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// Show 4-Agent installation, hooks, and agent-jail status
    Status {
        /// Emit machine-readable JSON
        #[arg(long)]
        json: bool,
    },
}

#[derive(ValueEnum, Clone, Copy, Debug)]
enum CompletionShell {
    Zsh,
    Bash,
    Fish,
}

fn wire_zsh_subcommand(script: &str, subcmd: &str, helper: &str) -> String {
    let needle = format!("({subcmd})\n_arguments \"${{_arguments_options[@]}}\" : \\\n'-h[Print help]' \\\n'--help[Print help]' \\\n'*::args:_default'");
    let replacement = format!("({subcmd})\n_arguments \"${{_arguments_options[@]}}\" : \\\n'-h[Print help]' \\\n'--help[Print help]' \\\n'*::args:{helper}'");
    script.replacen(&needle, &replacement, 1)
}

fn generate_zsh_completion_with_dynamic() -> String {
    let mut buf = Vec::new();
    let mut cmd = Cli::command();
    generate(Shell::Zsh, &mut cmd, "dotfiles", &mut buf);
    let base = String::from_utf8_lossy(&buf).into_owned();

    let dynamic_helpers = r#"
_dotfiles_dynamic_themes() {
    local -a opts items
    opts=('--dry-run:Show what would change without applying')
    if [[ "${words[CURRENT]:-}" == -* ]]; then
        _describe -t options 'theme option' opts
        return
    fi
    items=("${(@f)$(command dotfiles __complete themes 2>/dev/null)}")
    if (( ${#items[@]} > 0 )) && [[ -n "${items[1]}" ]]; then
        _describe -t themes 'theme' items
    fi
}

_dotfiles_dynamic_machines() {
    local -a items
    items=("${(@f)$(command dotfiles __complete machines 2>/dev/null)}")
    if (( ${#items[@]} > 0 )) && [[ -n "${items[1]}" ]]; then
        _describe -t machines 'machine' items
    fi
}

_dotfiles_dynamic_fetch() {
    local -a subcmds items
    subcmds=(
        'status:Show installed vs declared downloads'
        'sync:Install or update declared downloads'
        'outdated:Check upstream for newer releases'
        'update:Update unpinned downloads to latest'
    )
    case "${words[1]:-}" in
        status|sync|outdated|update)
            items=("${(@f)$(command dotfiles __complete downloads 2>/dev/null)}")
            (( ${#items[@]} > 0 )) && [[ -n "${items[1]}" ]] && _describe -t downloads 'download id' items
            ;;
        *)
            _describe -t fetch-commands 'fetch action' subcmds
            ;;
    esac
}

_dotfiles_dynamic_jail() {
    local -a opts agents
    opts=(
        '--workspace:Writable workspace directory'
        '--rw:Additional writable directory'
        '--agent:Explicit agent profile (auto|none|claude|codex|agy|pi)'
        '--backend:Sandbox backend (auto|bwrap|landlock)'
        '--mask-gh:Also mask ~/.config/gh/hosts.yml'
        '--dry-run:Print sandbox plan JSON without executing'
    )
    agents=(
        'claude:Claude Code inside agent-jail'
        'codex:OpenAI Codex CLI inside agent-jail'
        'agy:Antigravity CLI inside agent-jail'
        'pi:Pi coding agent inside agent-jail'
    )
    if [[ "${words[CURRENT]:-}" == -* ]]; then
        _describe -t options 'agent-jail option' opts
    else
        _describe -t agents 'coding agent' agents
    fi
}

_dotfiles_dynamic_upgrade() {
    local -a opts layers
    opts=(
        '-n:Check upstream versions without modifying anything'
        '--dry-run:Check upstream versions without modifying anything'
        '--only:Limit to specific layer(s) (mise,pixi,fetch,sheldon)'
        '--no-major:Skip major version jumps in mise'
        '--include-self:Also check self-released dotfiles-cli'
        '--jobs:Parallel mise version queries'
    )
    layers=(
        'mise:Locked CLIs, runtimes, LSPs, and agents in .chezmoidata/mise.toml'
        'pixi:Global pixi environments'
        'fetch:Unpinned dotfiles-fetch apps and fonts'
        'sheldon:Zsh plugins via sheldon lock --update'
    )
    if [[ "${words[CURRENT-1]:-}" == "--only" ]]; then
        _describe -t layers 'upgrade layer' layers
    else
        _describe -t options 'upgrade option' opts
    fi
}
"#;

    let mut out = wire_zsh_subcommand(&base, "theme", "_dotfiles_dynamic_themes");
    out = wire_zsh_subcommand(&out, "machine", "_dotfiles_dynamic_machines");
    out = wire_zsh_subcommand(&out, "fetch", "_dotfiles_dynamic_fetch");
    out = wire_zsh_subcommand(&out, "jail", "_dotfiles_dynamic_jail");
    out = wire_zsh_subcommand(&out, "upgrade", "_dotfiles_dynamic_upgrade");

    // Insert helpers right before the final autoload/compdef line.
    if let Some(pos) = out.rfind("\nif [ \"$funcstack[1]\"") {
        out.insert_str(pos, &format!("\n{dynamic_helpers}\n"));
    } else {
        out.push('\n');
        out.push_str(dynamic_helpers);
    }
    out
}

fn run() -> anyhow::Result<i32> {
    let cli = Cli::parse();
    match cli.command {
        None => {
            if io::stdout().is_terminal() && io::stdin().is_terminal() {
                tui::run()
            } else {
                Cli::command().print_help()?;
                println!();
                Ok(0)
            }
        }
        Some(Commands::Tui) => tui::run(),
        Some(Commands::Doctor { json }) => commands::cmd_doctor(json),
        Some(Commands::Machine { args }) => commands::exec_helper("machine", &args),
        Some(Commands::Theme { args }) => commands::exec_helper("theme", &args),
        Some(Commands::Fetch { args }) => commands::exec_helper("dotfiles-fetch", &args),
        Some(Commands::Jail { args }) => commands::exec_helper("agent-jail", &args),
        Some(Commands::Agent { action }) => match action {
            AgentAction::Skills { args } => commands::exec_helper("agent-skills.sh", &args),
            AgentAction::Status { json } => commands::cmd_agent_status(json),
        },
        Some(Commands::Sync {
            update,
            dry_run,
            no_externals,
        }) => commands::cmd_sync(update, dry_run, no_externals),
        Some(Commands::Upgrade { args }) => {
            commands::exec_helper("upgrade-toolchain.py", &args)
        }
        Some(Commands::Check) => commands::cmd_check(),
        Some(Commands::Bootstrap) => commands::cmd_bootstrap(),
        Some(Commands::Completion { shell }) => {
            match shell {
                CompletionShell::Zsh => print!("{}", generate_zsh_completion_with_dynamic()),
                CompletionShell::Bash => {
                    let mut cmd = Cli::command();
                    generate(Shell::Bash, &mut cmd, "dotfiles", &mut io::stdout());
                }
                CompletionShell::Fish => {
                    let mut cmd = Cli::command();
                    generate(Shell::Fish, &mut cmd, "dotfiles", &mut io::stdout());
                }
            }
            Ok(0)
        }
        Some(Commands::InternalComplete { kind }) => commands::cmd_complete(&kind),
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => ExitCode::from(code as u8),
        Err(err) => {
            eprintln!("dotfiles: error: {err:#}");
            ExitCode::from(1)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tui::theme::parse_hex;
    use ratatui::style::Color;

    #[test]
    fn cli_definition_valid() {
        Cli::command().debug_assert();
    }

    #[test]
    fn hex_parser_works() {
        assert_eq!(parse_hex("#eb6f92"), Some(Color::Rgb(0xeb, 0x6f, 0x92)));
        assert_eq!(parse_hex("#191724"), Some(Color::Rgb(0x19, 0x17, 0x24)));
        assert_eq!(parse_hex("invalid"), None);
    }

    #[test]
    fn zsh_completion_contains_dynamic_helpers() {
        let script = generate_zsh_completion_with_dynamic();
        assert!(script.starts_with("#compdef dotfiles"));
        assert!(script.contains("'*::args:_dotfiles_dynamic_themes'"));
        assert!(script.contains("'*::args:_dotfiles_dynamic_machines'"));
        assert!(script.contains("'*::args:_dotfiles_dynamic_fetch'"));
        assert!(script.contains("'*::args:_dotfiles_dynamic_jail'"));
        assert!(script.contains("'*::args:_dotfiles_dynamic_upgrade'"));
    }
}
