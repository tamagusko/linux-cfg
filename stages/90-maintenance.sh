#!/usr/bin/env bash
# Stage 90 — snapshots, memory tuning, and maintenance hooks.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 90 — MAINTENANCE & RECOVERY"

# ------------------------------------------------------------------ snapshots
#
# The highest-value addition in this repo. A rolling distro plus a GPU driver
# that builds kernel modules means a bad update can cost a bootable desktop.
# Snapshots turn that from an evening of recovery into a reboot.
#
# Requires btrfs. On any other filesystem snapper cannot work, and this says so
# rather than pretending.
root_fs="$(findmnt -no FSTYPE / 2>/dev/null || echo unknown)"

if [[ "$root_fs" == "btrfs" ]]; then
    info "btrfs root detected — setting up snapper"
    pac snapper snap-pac

    if sudo snapper list-configs 2>/dev/null | grep -qw root; then
        ok "snapper config 'root' already exists"
    else
        run sudo snapper -c root create-config /
        ok "created snapper config 'root'"
    fi

    # snap-pac takes a pre/post snapshot around every pacman transaction, which
    # is exactly the granularity that matters: it brackets the risky operation.
    run sudo systemctl enable --now snapper-timeline.timer
    run sudo systemctl enable --now snapper-cleanup.timer

    # grub-btrfs exposes snapshots in the boot menu, so recovery does not
    # require a live USB. Only useful with GRUB.
    if [[ -d /boot/grub ]]; then
        aur grub-btrfs
        run sudo systemctl enable --now grub-btrfsd
    else
        info "GRUB not detected — skipping grub-btrfs (systemd-boot users: see docs/MAINTENANCE.md)"
    fi

    ok "snapshots active: pre/post pacman, plus timeline"
else
    warn "root filesystem is '${root_fs}', not btrfs — snapper cannot be used"
    warn "options: reinstall on btrfs, or install timeshift for rsync-based snapshots"
    if confirm "install timeshift instead (rsync mode, works on ext4)?"; then
        aur timeshift
    fi
fi

# ----------------------------------------------------------------------- zram
#
# 12GB of VRAM and VLM inference means host RAM pressure is a real failure mode:
# dataloader workers plus a model being staged will find the ceiling. zram gives
# compressed swap in RAM, which is far faster than swapping to disk and usually
# prevents the OOM killer from taking the training run.
info "configuring zram swap"
pac zram-generator

if [[ "$DRY_RUN" == "1" ]]; then
    info "would write /etc/systemd/zram-generator.conf"
else
    printf '%s\n' \
        '[zram0]' \
        'zram-size = min(ram / 2, 16384)' \
        'compression-algorithm = zstd' \
        | sudo tee /etc/systemd/zram-generator.conf >/dev/null
    ok "wrote /etc/systemd/zram-generator.conf (half of RAM, capped at 16G, zstd)"
fi

# With zram present, leaning harder on swap is correct: it is RAM-backed.
if [[ "$DRY_RUN" == "1" ]]; then
    info "would write /etc/sysctl.d/99-vm-zram.conf"
else
    printf '%s\n' \
        'vm.swappiness = 180' \
        'vm.watermark_boost_factor = 0' \
        'vm.watermark_scale_factor = 125' \
        'vm.page-cluster = 0' \
        | sudo tee /etc/sysctl.d/99-vm-zram.conf >/dev/null
    ok "wrote /etc/sysctl.d/99-vm-zram.conf"
fi

# ------------------------------------------------------------- package cache
#
# Without this the pacman cache grows without bound; on a rolling distro it
# reaches tens of GB. Keep the last 3 versions of each package, which is enough
# to downgrade a broken update.
info "enabling weekly pacman cache cleanup"
pac pacman-contrib
run sudo systemctl enable --now paccache.timer

ok "maintenance stage done"
