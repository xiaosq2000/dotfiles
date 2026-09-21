---
name: machines
description: Facts about the user's own machines (workstation, laptop, imrl, sicc, vps), covering what each is for, how to reach it over ssh, accounts, hardware, storage, job and sharing rules, and known quirks. Use before running anything over ssh, moving files between machines, choosing where to run a job, or answering what a machine has or can reach.
---

# Machines

The pages in `references/` describe each machine the user works on. They hold
addresses, account names and network layout, so the dotfiles repository keeps
them age-encrypted, and `chezmoi apply` decrypts them here. They exist only on
machines that hold the age key. The vps never does.

## Before you start

1. Run `machine` to find out which machine you are on. Hostnames do not settle
   it, because sicc's login nodes answer as `login01`, `login02` and so on.
2. For anything that crosses machines, read `references/network.md` first. It
   covers who reaches whom, the reverse tunnel into the workstation, and how to
   relay transfers.
3. Read the page for each machine involved.

| Page | Covers |
| --- | --- |
| `references/network.md` | SSH aliases, reachability, the reverse tunnel, trusted keys, ssh from an agent, moving data |
| `references/workstation.md` | the user's desktop and network hub; storage, services, out-of-tree drivers |
| `references/laptop.md` | the personal laptop, used off campus over the university VPN |
| `references/imrl.md` | the shared lab GPU server; storage, GPU etiquette and health, Gitea |
| `references/sicc.md` | the university HPC login node; shell, Slurm, proxy variables, storage and quota |
| `references/vps.md` | the public VPS for network plumbing; what runs there, and why to leave it alone |

## Running ssh

On the workstation and the laptop, inside kitty, `ssh` is a shell function that
runs `kitten ssh`, which fails without a terminal. Call `command ssh` instead.
On imrl and sicc, a command passed over ssh runs without `~/.pixi/bin` on
`PATH`, so export it in the command. `network.md` has both in full.

## How far to trust a page

Facts carry the date they were checked. Machines change, so re-check an old
fact before relying on it when a check is cheap, and say which facts you
checked and which you took from the page.

These pages hold facts about the machines. Facts about one project, such as its
datasets, environments and job records, belong in that project's own
documentation. For embodied-ai that is its
`docs/shared/reference/compute-resources/` directory.

## Correcting or adding a page

Edit the decrypted page in place, then hand it back to chezmoi, which encrypts
it again. Use the path under `~/.agents/skills/machines`, not the links under
`~/.claude/skills` or `~/.codex/skills`, because chezmoi only knows the first.

```sh
chezmoi re-add ~/.agents/skills/machines/references/imrl.md
git -C "$(chezmoi source-path)" diff     # plaintext diff where the key is
```

Then commit in the source repository, following its `AGENTS.md`. Other machines
pick the change up on their next `chezmoi update`.

A new page needs `--encrypt`:

```sh
chezmoi add --encrypt ~/.agents/skills/machines/references/<name>.md
```

The dotfiles repository is public. Never write a page into the source tree
yourself, and never `chezmoi add` one without `--encrypt`. Either would publish
the plaintext on the next push. A pre-commit hook refuses both, but only in a
clone where the hooks are installed.
