#!/usr/bin/env bash
# Stage 80 — workstation security baseline.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 80 — SECURITY BASELINE"

# ----------------------------------------------------------------------- ufw
#
# Two bugs in the previous version:
#
#  1. The five `ufw` rule commands ran WITHOUT sudo, so every one failed, while
#     `systemctl enable ufw` ran WITH sudo and succeeded. The unit was active,
#     the ruleset was never applied, and `systemctl status ufw` looked healthy.
#     That is worse than no firewall, because it defeats the check you would
#     otherwise make.
#  2. It opened inbound 80/tcp and 443/tcp on a workstation that runs no server.
#     Those rules are gone.
#
# Policy: deny everything inbound, allow everything outbound. Outbound-initiated
# connections still get their replies, so this does not break browsing, updates,
# ssh *to* other hosts, or Docker.
info "configuring ufw: deny incoming, allow outgoing"
run sudo ufw --force default deny incoming
run sudo ufw --force default allow outgoing

# Rate-limited inbound ssh, only if an sshd is actually installed and enabled.
# No point opening a port for a service that is not listening.
if systemctl is-enabled sshd.service >/dev/null 2>&1; then
    warn "sshd is enabled — allowing rate-limited inbound ssh"
    run sudo ufw limit ssh
else
    info "sshd not enabled; no inbound ports opened"
fi

run sudo ufw --force enable
run sudo systemctl enable --now ufw.service

# Verify rather than assume. This is the check the old script made impossible.
info "ufw status:"
run_tty sudo ufw status verbose

# ----------------------------------------------------------------- ssh client
#
# Client-side hardening only. Applies when connecting out to other hosts.
if [[ -d "$HOME/.ssh" ]] || confirm "create ~/.ssh and write a hardened client config?"; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ensure_block "$HOME/.ssh/config" "ssh-client" <<'BLOCK'
Host *
    HashKnownHosts yes
    VisualHostKey yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
BLOCK
    chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
fi

# --------------------------------------------------------------------- fstrim
#
# Weekly SSD trim. The systemd timer is the supported route; do not put discard
# in fstab, which trims on every delete and costs throughput.
info "enabling weekly SSD trim"
run sudo systemctl enable --now fstrim.timer

# -------------------------------------------------------------------- mirrors
#
# Stale mirrors are the most common cause of slow or failing updates.
if have reflector; then
    info "refreshing pacman mirrorlist (fastest 20, HTTPS only)"
    run sudo reflector --latest 20 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
    run sudo systemctl enable reflector.timer
fi

# ------------------------------------------------------------------- updates
#
# Deliberately NOT automating updates.
#
# On a rolling release, unattended upgrades are a bad idea: partial upgrades
# break systems, some updates need manual intervention announced on the Arch
# news page, and an automatic kernel update can leave you without a working GPU
# driver on next boot. What is automated here is the *safety net* around a
# manual update — snapshots in stage 90 and the LTS fallback kernel from stage
# 10. Update deliberately; see docs/MAINTENANCE.md.
warn "automatic updates are intentionally NOT enabled — see docs/MAINTENANCE.md"

ok "security baseline done"
