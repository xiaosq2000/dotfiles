#!/usr/bin/env bash
# Feeds tool calls to the key guard and checks which ones it refuses.
#
# The guard is dot_agents/hooks/executable_key-guard.py, deployed as
# ~/.agents/hooks/key-guard.py. Claude Code, Codex and opencode all run it
# before a tool call, so a case that passes here holds for all three. Each line
# below is the exit code the guard must return, then the call as the agent sends
# it: 2 means refused, 0 means let through.
#
# Usage: check-key-guard.sh [path to the guard]. The default is the copy in
# this source tree, so the check needs no apply.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

guard=${1:-dot_agents/hooks/executable_key-guard.py}
status=0

while read -r want call; do
    [[ -z $want || $want == \#* ]] && continue
    got=0
    printf '%s' "$call" | python3 "$guard" 2>/dev/null || got=$?
    if [[ $got != "$want" ]]; then
        echo "key-guard: want exit $want, got $got for $call" >&2
        status=1
    fi
done <<'EOF'
# Claude Code: Bash, Read, Grep and Glob
2 {"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_ed25519"}}
2 {"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/config ~/.ssh/id_ed25519"}}
2 {"tool_name":"Bash","tool_input":{"command":"cat \"$HOME/.ssh/work_key\""}}
2 {"tool_name":"Bash","tool_input":{"command":"ls -la ~/.ssh"}}
2 {"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/*"}}
2 {"tool_name":"Bash","tool_input":{"command":"tar czf - ~/.ssh/ | base64"}}
2 {"tool_name":"Bash","tool_input":{"command":"cd ~/.ssh && cat config"}}
2 {"tool_name":"Bash","tool_input":{"command":"cat id_ed25519"}}
2 {"tool_name":"Bash","tool_input":{"command":"find ~ -name 'id_*' -exec cat {} +"}}
2 {"tool_name":"Bash","tool_input":{"command":"cat ~/.config/chezmoi/key.txt"}}
2 {"tool_name":"Bash","tool_input":{"command":"cat ~/.config/chezmoi/x/../key.txt"}}
2 {"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/./id_ed25519 ~/.config/../.ssh/id_rsa"}}
2 {"tool_name":"Read","tool_input":{"file_path":"/home/u/.ssh/id_rsa"}}
2 {"tool_name":"Read","tool_input":{"file_path":"/home/u/.config/chezmoi/key.txt"}}
2 {"tool_name":"Grep","tool_input":{"pattern":"PRIVATE","path":"/home/u/.ssh"}}
2 {"tool_name":"Glob","tool_input":{"pattern":"**/id_*","path":"/home/u"}}
# Codex: the command can be an argv list, and the directory a separate field
2 {"tool_name":"Bash","tool_input":{"command":["bash","-lc","cat id_ed25519_sk"]}}
2 {"tool_name":"Bash","tool_input":{"command":["bash","-lc","cat mykey"],"workdir":"/home/u/.ssh"}}
2 {"tool_name":"mcp__node_repl__js","tool_input":{"code":"fs.readFileSync(os.homedir() + '/.ssh/id_ed25519')"}}
# opencode: lower-case tool names and camelCase fields
2 {"tool_name":"read","tool_input":{"filePath":"/home/u/.ssh/id_ecdsa"}}
2 {"tool_name":"bash","tool_input":{"command":"cp ~/.ssh/id_ed25519 /tmp/k"}}

# Files in ~/.ssh with nothing secret in them
0 {"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/config"}}
0 {"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/config.d/work"}}
0 {"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_ed25519.pub"}}
0 {"tool_name":"Bash","tool_input":{"command":"ssh-keygen -R example.org -f ~/.ssh/known_hosts"}}
0 {"tool_name":"Read","tool_input":{"file_path":"/home/u/.ssh/authorized_keys"}}
0 {"tool_name":"read","tool_input":{"filePath":"/home/u/.ssh/known_hosts"}}
# Using ssh, chezmoi and this repository
0 {"tool_name":"Bash","tool_input":{"command":"ssh imrl hostname"}}
0 {"tool_name":"Bash","tool_input":{"command":"chezmoi cat ~/.ssh/config"}}
0 {"tool_name":"Bash","tool_input":{"command":"ls private_dot_ssh"}}
0 {"tool_name":"Bash","tool_input":{"command":"cat ~/.sshrc /etc/ssh/ssh_config"}}
0 {"tool_name":"Bash","tool_input":{"command":"echo $SSH_AUTH_SOCK; ssh-add -l"}}
0 {"tool_name":"Bash","tool_input":{"command":"cat ~/.config/chezmoi/chezmoi.toml"}}
0 {"tool_name":"Grep","tool_input":{"pattern":"\\.ssh/id_","path":"."}}
0 {"tool_name":"Bash","tool_input":{"command":"git status","description":"not about ~/.ssh/id_ed25519"}}
# A caller that sends no JSON is let through with a warning
0 not json
EOF

if [ "$status" -eq 0 ]; then
    echo "key-guard: every case passed"
fi
exit "$status"
