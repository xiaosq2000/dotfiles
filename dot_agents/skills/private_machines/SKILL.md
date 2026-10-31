---
name: machines
description: "Look up host-specific access, compute, storage, or service facts for the user's machines. Load only the target host and task. Use for remote access, transfers, job placement, or machine questions."
---

# Machines

Checked on 2026-10-31.

Run `machine` only if the current host is unknown. Do not infer it from the hostname.
Read `references/<host>.md` for access, resources, or host-wide boundaries.
For a public VPS, read its boundary page before acting.

Choose task references directly. Links are lookup choices, not required reading.

| Host | Task references |
| --- | --- |
| workstation | [storage](references/workstation-storage.md), [drivers and boot](references/workstation-drivers.md) |
| laptop | [network and browsers](references/laptop-network.md), [hardware](references/laptop-hardware.md), [power and displays](references/laptop-power.md) |
| imrl | [storage](references/imrl-storage.md), [compute](references/imrl-compute.md), [services](references/imrl-services.md) |
| sicc | [compute](references/sicc-compute.md), [storage and quota](references/sicc-storage.md) |
| vps | [services](references/vps-services.md), [manager](references/vps-manager.md), [recovery](references/vps-recovery.md) |
| vps-sg | [network evidence](references/vps-sg-network.md) |

| Shared task | Reference |
| --- | --- |
| SSH routes, tunnels, transfers | [network.md](references/network.md) |
| AI proxy or direct downloads | [network-proxy.md](references/network-proxy.md) |
| Off-campus university VPN | [network-vpn.md](references/network-vpn.md) |

If no topic fits, use that host's page. Do not load another host's references.
Cross-machine work needs only facts that affect the route or operation, not every source and destination page.
Use `command ssh` for noninteractive calls. Check remote PATH before running user-installed tools.
Run downloads without proxy variables. Ask the user if direct access fails.
Recheck changing facts before acting. Keep project procedures in their project.

## Editing references

Keep private references and identities off public VPS machines.
Edit decrypted pages under `~/.agents/skills/machines/references`, not plaintext files in the source repository.
Use `chezmoi re-add <path>` for existing pages. Use `chezmoi add --encrypt <path>` for new pages with mode 0600.
Read the source repository's `AGENTS.md` before editing. Date facts and keep only information that changes an action.
