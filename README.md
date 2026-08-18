# linux-cfg

Workstation setup for **EndeavourOS / Arch with i3wm**, aimed at research
computing: PyTorch and computer-vision work on an NVIDIA GPU, plus LaTeX,
Quarto and Zotero for writing.

> Personal configuration. Read it before running it — it installs packages and
> changes system settings as root.

## Install

Clone it, read it, then run it. **Do not pipe this into a shell from the
internet** — the previous version documented
`sh <(curl -s .../main/config.sh)`, which executes whatever happens to be on a
mutable branch, with root escalation and no integrity check.

```bash
git clone https://github.com/tamagusko/linux-cfg.git ~/repos/linux-cfg
cd ~/repos/linux-cfg

./scripts/verify-packages.sh   # confirm every package name still resolves
./install.sh --dry-run         # print every command without running it
./install.sh                   # run it
```

Then reboot. The NVIDIA driver and the cedilla input modules both need it.

### Options

| Flag | Effect |
|---|---|
| `--dry-run` | Print every command, change nothing |
| `--yes` | Accept every prompt (unattended) |
| `--only 20-gpu` | Run one stage |
| `--from 40-dev` | Resume from a stage onwards |
| `--list` | List stages |

## Stages

Each stage is independently runnable and safe to run twice.

| Stage | Does |
|---|---|
| `00-preflight` | Refuses to run as root or on a non-Arch system; checks network, sudo, disk, filesystem |
| `10-system` | Keyrings, full upgrade, `base-devel`, **LTS fallback kernel**, CPU microcode, paru |
| `20-gpu` | `nvidia-open` + optional CUDA/cuDNN |
| `30-packages` | `packages/pacman.txt` as a batch, `packages/aur.txt` one at a time |
| `40-dev` | uv, stow, docker, git defaults |
| `50-input` | Cedilla on a US-International layout |
| `60-latex` | TeX Live, `pandoc-cli`, `pandoc-crossref`, Quarto |
| `70-dotfiles` | oh-my-zsh, powerlevel10k, managed `.zshrc`, stow into `~/.config` |
| `80-security` | ufw, ssh client hardening, fstrim, mirrors |
| `90-maintenance` | btrfs snapshots, zram, pacman cache cleanup |

Order matters: the GPU driver installs before anything that needs it, paru
before the AUR packages, dotfiles after the apps they configure, and the
firewall last so it is not fighting the installs.

## Design notes

**Everything is idempotent.** Three rules, because breaking any of them is what
made the previous version unsafe to re-run:

1. Never `git clone` — `clone_or_pull` instead.
2. Never `>>` into a config file — `ensure_block` writes a delimited block that
   is rewritten in place, so aliases stop multiplying on every run.
3. Never blind `cp` over user files — `backup_file` takes a timestamped copy,
   then stow symlinks.

**Failure is loud.** Every script runs under `set -euo pipefail` with an `ERR`
trap that prints the stage, line and failing command. A failed run cannot
present itself as a successful one.

**Why the AUR loop tolerates failure.** One deliberate exception to the above.
A batched `paru -S a b c` aborts entirely if any single name is unresolvable —
which is exactly what happened when `skypeforlinux-stable-bin` outlived the
Skype product and silently prevented *every other* AUR package from installing.
AUR packages are therefore installed one at a time, failures are collected, and
the run ends with a summary of what did not install. Official repo names are
validated up front instead, where an unknown name is a bug worth stopping for.

**Everything is logged** to `~/.local/state/linux-cfg/install-<timestamp>.log`.

## Python

`uv` only. Do not use system `pip`.

Arch marks the system Python environment externally-managed (PEP 668), so
`pip install` outside a virtualenv fails by design. Arch also bumps system
Python quickly, and every bump breaks packages installed into site-packages.
uv sidesteps both by installing and pinning its own interpreters per project.

```bash
./scripts/new-ml-project.sh myproject             # PyTorch + Ultralytics
./scripts/new-ml-project.sh embedded tensorflow   # TensorFlow, for TFLite work
```

`--torch-backend=auto` picks the CUDA wheel index that matches the installed
driver. Selecting that index by hand is how people end up silently training on
CPU.

## Typora

Installed from the AUR as `typora` — the commercial release, not the
`typora-free*` packages, which are pinned to the old free beta.

Licensing is $14.99 once for three devices, with a trial period.
**Activation is deliberately not scripted**, and no licence key belongs in this
repository. Activate it by hand on first launch.

## Security choices

Made explicitly rather than by accident:

- **Firewall**: deny inbound, allow outbound. No ports opened. The previous
  version opened 80 and 443 on a machine running no server — and, because the
  rule commands ran without `sudo` while the service was enabled *with* it,
  produced an active ufw unit with no ruleset. Verify with
  `sudo ufw status verbose`.
- **AUR**: `paru` builds arbitrary user-submitted scripts. `--noconfirm` means
  no PKGBUILD is shown. The paru bootstrap itself pauses to display its PKGBUILD
  before building. For everything else, review with `paru -G <pkg>` when a
  package is new or unfamiliar.
- **Docker group**: root-equivalent — the socket can mount the host filesystem
  as root. Accepted for a single-user workstation, and prompted for rather than
  applied silently.
- **No automatic updates**: on a rolling release, unattended upgrades break
  systems. The safety net is snapshots plus an LTS fallback kernel, not
  automation. See `docs/MAINTENANCE.md`.

## Maintenance

See **[docs/MAINTENANCE.md](docs/MAINTENANCE.md)** for the update routine,
recovery from a bad update, and cleanup.

---

Personal use. [Copyright](LICENSE) (c) 2022-2026,
[Tiago Tamagusko](https://github.com/tamagusko).
