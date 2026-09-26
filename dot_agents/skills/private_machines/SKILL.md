---
name: machines
description: Facts about the user's own machines (workstation, laptop, imrl, sicc, vps), covering what each is for, how to reach it over ssh, accounts, hardware, storage, job and sharing rules, and known quirks. Use before running anything over ssh, moving files between machines, choosing where to run a job, or answering what a machine has or can reach.
---

# Machines

`references/` has one page per machine plus `network.md`. The pages hold
addresses and account names, so the dotfiles repository keeps them
age-encrypted. They exist only on machines with the age key, never on the vps.

1. Run `machine` to find out which machine you are on. Hostnames do not settle
   it, because sicc's login nodes answer as `login01`, `login02` and so on.
2. For anything that crosses machines, read `references/network.md`.
3. Read the page for each machine involved.

| Page | Covers |
| --- | --- |
| `network.md` | SSH aliases, reachability, the reverse tunnel, trusted keys, ssh from an agent, the proxy, moving data |
| `workstation.md` | the desktop and network hub; storage, services, out-of-tree drivers |
| `laptop.md` | the personal laptop, used off campus; VPN, power toggles |
| `imrl.md` | the shared lab GPU server; storage, GPU sharing and health, Gitea |
| `sicc.md` | the university HPC login node; shell, Slurm, storage and quota |
| `vps.md` | the public server that runs the proxy; leave it alone |

## Rules on every machine

- Run downloads without the proxy. Every machine reaches AI services such as
  Claude and ChatGPT through a proxy whose traffic is metered. Interactive
  shells start with the proxy variables set, and git has a global proxy.
  `network.md` shows how to clear both. If a download fails without the proxy,
  ask the user instead of retrying through it.
- If `ssh` fails with "The SSH kitten is meant for interactive use only", use
  `command ssh`.
- On imrl and sicc, a command passed over ssh gets only the system `PATH`, so
  export what it needs in the command: `~/.pixi/bin` for pixi and chezmoi,
  `~/.local/bin` for claude, `~/.local/share/pnpm/bin` for codex.

## Trusting and editing a page

Facts carry the date they were checked. When a check is cheap, re-check an old
fact before relying on it, and tell the user which facts you checked. Facts
about one project belong in that project; for embodied-ai, see its
`docs/shared/reference/compute-resources/`.

To correct a page, edit the decrypted copy under `~/.agents/skills/machines`, not
the links under `~/.claude` or `~/.codex`. Then re-encrypt it and commit in the
source repository, following its `AGENTS.md`:

```sh
chezmoi re-add ~/.agents/skills/machines/references/imrl.md
chezmoi add --encrypt ~/.agents/skills/machines/references/<new>.md
```

The dotfiles repository is public. Never write a page into the source tree, and
never `chezmoi add` one without `--encrypt`.

Keep pages short. State the current fact and leave history to git.
