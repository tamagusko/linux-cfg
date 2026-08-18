# Maintenance

The routine that keeps a rolling-release workstation boring. Written for
future-me, who will have forgotten all of it.

## Updating

**Do not automate this.** On a rolling release, unattended upgrades break
systems: partial upgrades leave mismatched libraries, some updates need manual
intervention announced on the Arch news page, and an automatic kernel update can
leave you at a black screen with no GPU driver.

Roughly weekly:

```bash
# 1. Read the news first. This is the step people skip and regret.
#    https://archlinux.org/news/
#
# 2. Full upgrade. NEVER `pacman -Sy <pkg>` — a partial upgrade is how you
#    break a system.
sudo pacman -Syu

# 3. AUR separately, so you can see what is rebuilding.
paru -Sua
```

After a kernel update, reboot before doing GPU work — the running kernel and
the installed NVIDIA modules will not match until you do.

Check what an update is about to do:

```bash
paru -Qua           # AUR updates available
pacman -Qu          # repo updates available
```

## When an update breaks something

Two layers of safety net, in order of preference.

**1. Boot the previous snapshot.** `snap-pac` takes a pre/post snapshot around
every pacman transaction, so the state from immediately before the update
exists.

```bash
sudo snapper list                    # find the pre-transaction snapshot
sudo snapper rollback <number>       # then reboot
```

With `grub-btrfs` installed, snapshots also appear in the GRUB boot menu, so
this works even when the system will not boot.

**2. Boot the LTS kernel.** If the problem is a mainline kernel or its NVIDIA
module, pick `linux-lts` from the boot menu. Installed by stage 10 for exactly
this.

**3. Downgrade one package.** The pacman cache keeps the last three versions.

```bash
ls /var/cache/pacman/pkg/ | grep <package>
sudo pacman -U /var/cache/pacman/pkg/<package>-<oldversion>.pkg.tar.zst
```

## Cleanup

Monthly is plenty.

```bash
# Orphaned dependencies — packages nothing depends on any more.
pacman -Qtdq                              # review first
pacman -Qtdq | sudo pacman -Rns -          # then remove

# Package cache. paccache.timer already does this weekly, keeping 3 versions.
paccache -d                               # dry run
sudo paccache -r                          # keep 3
sudo paccache -ruk0                       # drop uninstalled packages entirely

# Old snapshots. snapper-cleanup.timer handles this, but to check:
sudo snapper list
sudo btrfs filesystem usage /

# uv caches.
uv cache prune
```

Check what is actually eating disk:

```bash
sudo du -xh --max-depth=1 / 2>/dev/null | sort -h | tail -20
journalctl --disk-usage
sudo journalctl --vacuum-size=500M
```

## Health checks

```bash
nvidia-smi                        # GPU visible, driver version
sudo firewall-cmd --list-all      # firewall rules ACTUALLY applied (firewalld)
sudo ufw status verbose           # ...or this, if you are on ufw instead
systemctl --failed                # anything broken
zramctl                           # zram active
sudo snapper list | tail          # snapshots being taken
findmnt -no FSTYPE /              # btrfs?
```

## Docker and the firewall

Docker publishes ports **around** the firewall. It writes its own nftables
chains (`DOCKER`, `DOCKER-USER`, `DOCKER-ISOLATION`) and its NAT rules are
evaluated in FORWARD before the firewall's INPUT rules are consulted. This is a
Docker design decision, not a bug, and it applies to firewalld and ufw alike —
switching firewalls does not fix it.

```bash
docker run -p 8080:80 image             # reachable by anyone on the LAN
docker run -p 127.0.0.1:8080:80 image   # reachable only by you
```

**Loopback binding is the fix for 95% of cases.** On a workstation, containers
almost always serve only you, so make `127.0.0.1:` the habit.

If you genuinely need a container reachable from the network but still filtered,
use the `DOCKER-USER` chain, which is evaluated before Docker's own rules:

```bash
# Default-drop forwarded traffic, allowing only an explicit source range.
sudo nft insert rule inet filter DOCKER-USER ip saddr != 192.168.1.0/24 drop
```

Make it persistent with your firewall's own config, not an ad-hoc script — an
un-persisted rule vanishes on reboot and takes your assumptions with it.

To check what is actually exposed right now:

```bash
sudo ss -tulpn | grep -v '127.0.0.1\|::1'   # anything not bound to loopback
docker ps --format '{{.Names}}\t{{.Ports}}'
```

## Backups

Snapshots are **not** backups — they live on the same disk, and they do not
survive a dead drive or a mistaken `rm` that gets snapshotted along with
everything else.

What actually needs backing up:

| What | Where |
|---|---|
| `~/repos` | Already on GitHub, but only what you pushed |
| `~/Documents`, papers, datasets | Nothing else has these |
| `~/.ssh`, GPG keys | Losing these is a bad day |
| `~/Zotero` | The library database, not just the PDFs |
| This repo | Reproduces the machine, not the data |

Set up one of these to an external drive and a remote:

```bash
paru -S restic        # fast, deduplicating, encrypted
# or
paru -S borg          # same idea, older and very well tested
```

A backup you have never restored from is a hypothesis. Test it once.

## Re-running the installer

Safe at any time. Every stage is idempotent.

```bash
./install.sh --dry-run          # see what would change
./install.sh --only 80-security # re-apply just one stage
./scripts/verify-packages.sh    # check for renamed/removed packages
```

Run `verify-packages.sh` before any fresh install. Package names drift:
`texlive-most` was reorganised out of existence, `skypeforlinux-stable-bin`
outlived Skype, `python39` outlived Python 3.9. A name that worked in 2022 is
not evidence that it works now.
