// Managed by chezmoi from private_dot_pi/private_agent/extensions/dotfiles-guard.ts.
// Delegates Pi tool_call security checks to ~/.agents/hooks/key-guard.py and
// agent_settled notifications to ~/.agents/hooks/agent-notify.py so Pi shares
// the exact same rule engine as Claude Code, Codex, and Antigravity CLI.

import { execFile } from "node:child_process";
import os from "node:os";
import path from "node:path";
import type { ExtensionAPI, ToolCallEvent } from "@earendil-works/pi-coding-agent";

const HOME = os.homedir();
const KEY_GUARD = path.join(HOME, ".agents/hooks/key-guard.py");
const AGENT_NOTIFY = path.join(HOME, ".agents/hooks/agent-notify.py");
const GUARD_TIMEOUT_MS = 5_000;

type GuardResult = {
  code: number;
  stderr: string;
};

function runKeyGuard(payload: Record<string, unknown>): Promise<GuardResult> {
  return new Promise((resolve) => {
    const child = execFile(
      "python3",
      [KEY_GUARD],
      { timeout: GUARD_TIMEOUT_MS, maxBuffer: 64 * 1024 },
      (error, _stdout, stderr) => {
        if (!error) {
          resolve({ code: 0, stderr: "" });
          return;
        }
        const code = typeof (error as NodeJS.ErrnoException & { code?: number }).code === "number"
          ? ((error as unknown as { code: number }).code)
          : 1;
        resolve({ code, stderr: stderr.trim() });
      },
    );
    child.stdin?.end(JSON.stringify(payload));
  });
}

function buildGuardPayload(event: ToolCallEvent): Record<string, unknown> | null {
  const input = (event.input ?? {}) as Record<string, unknown>;
  switch (event.toolName) {
    case "bash": {
      if (typeof input.command !== "string") return null;
      return { tool_name: "Bash", tool_input: { command: input.command } };
    }
    case "read":
    case "ls":
    case "find":
    case "write":
    case "edit": {
      // Only inspect path fields (not file contents) so editing dotfiles docs
      // or hook tests that mention protected filenames stays allowed.
      const pathVal = input.path ?? input.file_path;
      if (typeof pathVal !== "string") return null;
      return { tool_name: "Read", tool_input: { file_path: pathVal } };
    }
    case "grep": {
      const pathVal = input.path;
      if (typeof pathVal !== "string") return null;
      return { tool_name: "Grep", tool_input: { path: pathVal } };
    }
    default: {
      if (event.toolName.startsWith("mcp")) {
        return { tool_name: event.toolName, tool_input: input };
      }
      return null;
    }
  }
}

export default function (pi: ExtensionAPI) {
  const marker = "__dotfilesGuardExtensionLoaded";
  if ((globalThis as Record<string, unknown>)[marker]) {
    return;
  }
  (globalThis as Record<string, unknown>)[marker] = true;

  pi.on("tool_call", async (event) => {
    const payload = buildGuardPayload(event);
    if (!payload) return undefined;

    const result = await runKeyGuard(payload);
    if (result.code === 2) {
      return {
        block: true,
        reason: result.stderr || "Blocked by ~/.agents/hooks/key-guard.py",
      };
    }
    return undefined;
  });

  pi.on("agent_settled", (event, ctx) => {
    if ((event as { aborted?: boolean })?.aborted) return;
    if ((ctx as { mode?: string })?.mode !== "tui") return;
    const project = path.basename(process.cwd());
    const body = project ? `Ready in ${project}` : "Ready for input";
    const child = execFile("python3", [AGENT_NOTIFY, "--agent", "Pi", "--body", body], {
      timeout: 2_000,
    });
    child.unref?.();
  });
}
