# linux-cfg

Workstation setup for **EndeavourOS / Arch with i3wm**, aimed at research
computing: PyTorch and computer vision on an NVIDIA GPU, plus LaTeX, Quarto and
Zotero for writing.

> Personal configuration. It installs packages and changes system settings as
> root — read it before running it. Never pipe an installer straight from the
> internet into a shell.

## Install

```bash
git clone https://github.com/tamagusko/linux-cfg.git ~/repos/linux-cfg
cd ~/repos/linux-cfg
./scripts/verify-packages.sh
./install.sh --dry-run
./install.sh
```

Then reboot — the NVIDIA driver and the cedilla input modules both need it.

## Commands

| Command | What it does |
|---|---|
| `./install.sh` | Run every stage |
| `./install.sh --dry-run` | Print every command, change nothing |
| `./install.sh --list` | List the stages |
| `./install.sh --only 20-gpu` | Run a single stage |
| `./install.sh --from 40-dev` | Resume from a stage onwards |
| `./install.sh --yes` | Unattended: accept every prompt |
| `./scripts/verify-packages.sh` | Check every package name against the live repos and AUR |
| `./scripts/new-ml-project.sh myproject` | Scaffold a uv project with the matching CUDA wheels |
| `./scripts/monitors.sh` | Print the `set $mon_*` lines for the current display layout |
| `./scripts/check-i3-config.sh` | Static-check `dotfiles/i3/config` before reloading i3 |
| `./scripts/check-repo-hygiene.sh` | Audit this repo for credentials and stray state |
| `./scripts/export-claude-config.sh` | Re-export `~/.claude` into `dotfiles/claude/` |

Runs are logged to `~/.local/state/linux-cfg/install-<timestamp>.log`.

## Stages

Independently runnable, safe to run twice. Numbered in tens so a new stage slots
in without renumbering the rest.

| Stage | Does |
|---|---|
| `00-preflight` | Refuses non-Arch or root; checks network, sudo, disk, git hooks |
| `10-system` | Keyrings, full upgrade, `base-devel`, LTS fallback kernel, microcode, paru |
| `20-gpu` | `nvidia-open`, optional CUDA and cuDNN |
| `30-packages` | `packages/pacman.txt` as a batch, `packages/aur.txt` one at a time |
| `40-dev` | uv, docker, git defaults |
| `50-input` | Cedilla on a US-International layout |
| `55-bluetooth` | Enables `bluetooth.service`, clears rfkill blocks |
| `60-latex` | TeX Live, `pandoc-cli`, `pandoc-crossref`, Quarto |
| `70-dotfiles` | oh-my-zsh, powerlevel10k, `.zshrc`, symlinks into `~/.config` |
| `75-claude` | Claude Code CLI, nodejs for its hooks, `~/.claude` from `dotfiles/claude` |
| `80-security` | Firewall, ssh client hardening, fstrim, mirrors |
| `90-maintenance` | btrfs snapshots, zram, pacman cache cleanup |

Order matters: the GPU driver before anything that needs it, paru before the AUR
packages, dotfiles after the apps they configure, the firewall last.

## Worth knowing

- **`uv`, never system `pip`.** Arch marks system Python externally-managed
  (PEP 668) and bumps the interpreter often, breaking anything in site-packages.
  uv pins its own interpreter per project and picks the CUDA wheel index that
  matches the driver — choosing that by hand is how people train on CPU by
  accident.
- **Docker publishes ports around the firewall.** It writes its own nftables
  chains, evaluated first, so `-p 8080:80` is LAN-reachable whatever the
  firewall says. Use `-p 127.0.0.1:8080:80` unless you mean to serve the network.
- **Typora** is the paid AUR release. Activation is deliberately not scripted and
  no licence key belongs in this repo.
- **No automatic updates.** On a rolling release the safety net is snapshots plus
  an LTS kernel, not automation. See [docs/MAINTENANCE.md](docs/MAINTENANCE.md).
- **Re-running is safe.** Every stage is idempotent: `clone_or_pull` instead of
  `git clone`, `ensure_block` instead of `>>`, `backup_file` plus symlinks
  instead of `cp`. Failures are loud — `set -euo pipefail` and an `ERR` trap that
  names the stage, line and command.
- **`dotfiles/<pkg>` is symlinked to `~/.config/<pkg>`**, so it is not a
  boundary: whatever an app writes there is already in the working tree of a
  public repo. A pre-commit hook scans staged content for credentials.

Why anything is done a particular way is commented next to the code that does
it, not here.

## Maintenance

See **[docs/MAINTENANCE.md](docs/MAINTENANCE.md)** — updating, recovering from a
bad update, cleanup, backups.

---

Personal use. [Copyright](LICENSE) (c) 2022-2026,
[Tiago Tamagusko](https://github.com/tamagusko).
