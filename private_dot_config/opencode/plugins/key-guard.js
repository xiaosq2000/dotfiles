// Runs ~/.agents/hooks/key-guard.py before every opencode tool call, so opencode
// refuses the same calls as Claude Code and Codex, which run that script as a
// PreToolUse hook. The script exits 2 when a call names an ssh private key or the
// chezmoi age identity, and its message tells the agent to ask the user instead.
//
// opencode has no sandbox, so this and the read rules in opencode.json are its
// only guards: a command that builds a key path at run time gets through. See
// docs/secrets.md in the dotfiles repository.
//
// This lives in ~/.config/opencode/plugins, the global plugin directory the
// opencode docs name. `opencode debug config` lists it from any directory,
// checked on 2026-09-21.
import { spawnSync } from "node:child_process"
import { homedir } from "node:os"
import { join } from "node:path"

const GUARD = join(homedir(), ".agents", "hooks", "key-guard.py")

export const KeyGuard = async () => {
    return {
        "tool.execute.before": async (input, output) => {
            const call = JSON.stringify({ tool_name: input.tool, tool_input: output.args })
            const run = spawnSync(GUARD, { input: call, encoding: "utf8", timeout: 10000 })
            if (run.status === 2) {
                throw new Error(run.stderr.trim())
            }
            // Anything else lets the call through, including a machine with no
            // python3 or no guard script, so a broken guard never blocks work.
        },
    }
}
