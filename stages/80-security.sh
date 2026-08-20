#!/usr/bin/env bash
# Stage 80 — workstation security baseline.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 80 — SECURITY BASELINE"

# ------------------------------------------------------------------- firewall
#
# EndeavourOS has installed AND enabled firewalld on every install since the
# Apollo release (2022), running in the `public` zone. On a fresh install a
# working firewall therefore already exists before this script runs.
#
# This stage detects rather than assumes. Installing a second firewall on top of
# the first is not belt-and-braces: ufw and firewalld both drive the same
# nftables ruleset, they overwrite each other, and the result is unverifiable —
# each tool reports only its own view while the kernel holds some mixture.
#
# Precedence:
#   firewalld present  -> configure it, never touch ufw
#   ufw only           -> configure ufw
#   both active        -> stop and make the user choose
#   neither            -> install firewalld
#
# History worth keeping: the previous version of this repo ran its five `ufw`
# rule commands WITHOUT sudo, so every one failed, then enabled the service WITH
# sudo, which succeeded. The unit was active, no ruleset was ever applied, and
# `systemctl status ufw` looked healthy. That is worse than no firewall, because
# it defeats the check you would otherwise make. Every path below therefore ends
# by printing the live ruleset.

# Written as if-statements rather than `have x && ...` chains. Under set -e a
# bare && chain is safe as a standalone line but returns non-zero when the guard
# fails, which kills the caller the moment such a line ends a function. Putting
# the test in condition context removes that trap for good.
firewalld_active=0
ufw_active=0
if have firewalld && systemctl is-active --quiet firewalld.service; then
    firewalld_active=1
fi
if have ufw && systemctl is-active --quiet ufw.service; then
    ufw_active=1
fi

if ((firewalld_active == 1 && ufw_active == 1)); then
    error "both firewalld and ufw are running — they will fight over nftables"
    error "disable one before continuing, e.g.:"
    error "  sudo systemctl disable --now ufw.service"
    die "refusing to configure a firewall while two are active"
fi

configure_firewalld() {
    info "configuring firewalld"
    run sudo systemctl enable --now firewalld.service

    # public: deny inbound unless explicitly allowed, the correct default for a
    # workstation that serves nothing.
    run sudo firewall-cmd --set-default-zone=public

    # The zone ships with ssh open. With no sshd enabled nothing is listening,
    # so the opening is pointless exposure — close it. If sshd IS enabled that
    # was presumably deliberate, so leave it and say so.
    if systemctl is-enabled sshd.service >/dev/null 2>&1; then
        warn "sshd is enabled — leaving the ssh service open in the public zone"
    elif sudo firewall-cmd --zone=public --query-service=ssh >/dev/null 2>&1; then
        info "sshd is not enabled; closing ssh in the public zone"
        run sudo firewall-cmd --permanent --zone=public --remove-service=ssh
        run sudo firewall-cmd --reload
    fi

    info "firewalld ruleset:"
    run_tty sudo firewall-cmd --list-all
}

configure_ufw() {
    info "configuring ufw: deny incoming, allow outgoing"
    run sudo ufw --force default deny incoming
    run sudo ufw --force default allow outgoing

    # Rate-limited inbound ssh only if an sshd is actually enabled. No point
    # opening a port for a service that is not listening.
    if systemctl is-enabled sshd.service >/dev/null 2>&1; then
        warn "sshd is enabled — allowing rate-limited inbound ssh"
        run sudo ufw limit ssh
    else
        info "sshd not enabled; no inbound ports opened"
    fi

    run sudo ufw --force enable
    run sudo systemctl enable --now ufw.service

    info "ufw ruleset:"
    run_tty sudo ufw status verbose
}

if ((firewalld_active == 1)); then
    ok "firewalld is already running (EndeavourOS default) — using it"
    if have ufw; then
        warn "ufw is also installed but not running; leave it that way"
    fi
    configure_firewalld
elif ((ufw_active == 1)); then
    ok "ufw is already running — using it"
    configure_ufw
elif have firewalld; then
    info "firewalld installed but not running"
    configure_firewalld
elif have ufw; then
    info "ufw installed but not running"
    configure_ufw
else
    info "no firewall present — installing firewalld"
    pac firewalld
    configure_firewalld
fi

# ------------------------------------------------------------- docker caveat
#
# Applies to BOTH firewalls, so it belongs here rather than in either branch.
#
# Docker writes its own nftables/iptables chains (DOCKER, DOCKER-USER,
# DOCKER-ISOLATION) and its NAT rules are evaluated in FORWARD before the
# firewall's INPUT rules are consulted. A published port is reachable from the
# LAN regardless of what the firewall says:
#
#     docker run -p 8080:80 image             <- reachable by anyone on the LAN
#     docker run -p 127.0.0.1:8080:80 image   <- reachable only by you
#
# Switching firewalls does not fix this; Docker manages its own chains either
# way. Bind to loopback unless you intend to serve the network. See
# docs/MAINTENANCE.md for the DOCKER-USER approach if you ever need more.
if have docker; then
    warn "docker publishes ports around the firewall — bind to 127.0.0.1 unless you mean to expose them"
fi

# ----------------------------------------------------------------- ssh client
#
# Client-side hardening only. Applies when connecting out to other hosts.
#
# IdentityAgent names the agent socket here rather than relying on
# SSH_AUTH_SOCK. The export in .zshrc only reaches processes that source
# .zshrc — an interactive shell — so anything started from a desktop launcher,
# a systemd user unit, or a long-running program whose environment predates the
# export sees no agent at all, and an encrypted key with nowhere to ask for a
# passphrase fails as "Permission denied (publickey)". Naming the socket in the
# config makes every ssh find the agent, because ssh reads this file on each
# invocation. %i is the local uid, matching $XDG_RUNTIME_DIR. If the socket is
# absent the option costs nothing: ssh falls back to the key files on disk.
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
    IdentityAgent /run/user/%i/gcr/ssh
BLOCK
    chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
fi

# --------------------------------------------------------------------- fstrim
#
# Weekly SSD trim. The systemd timer is the supported route; do not put discard
# in fstab, which trims on every delete and costs throughput.
info "enabling weekly SSD trim"
# ------------------------------------------------------------- ssh-agent
#
# gcr-ssh-agent, a user socket, so no sudo: it runs as the user whose keys it
# holds. The point is to make an encrypted key practical. An unencrypted key on
# a machine with no disk encryption is a bearer token — whoever reads the file
# can authenticate as this user — but a passphrase prompt on every push is how
# people end up removing the passphrase again. Backed by the login keyring, the
# passphrase is supplied by the password already typed at the display manager.
#
# No PAM edit: EndeavourOS ships /etc/pam.d/lightdm with pam_gnome_keyring
# already listed behind a leading `-`, which skips the module silently when it
# is absent. Installing gnome-keyring (stage 30) is what activates it.
if have gcr-ssh-agent || [[ -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/gcr/ssh" ]] \
   || [[ -f /usr/lib/systemd/user/gcr-ssh-agent.socket ]]; then
    if systemctl --user is-enabled --quiet gcr-ssh-agent.socket 2>/dev/null; then
        ok "gcr-ssh-agent socket already enabled"
    else
        info "enabling the gcr-ssh-agent user socket"
        run systemctl --user daemon-reload
        run systemctl --user enable --now gcr-ssh-agent.socket
    fi

    if ! pacman -Qq gnome-keyring >/dev/null 2>&1; then
        warn "gnome-keyring is not installed — keys will still need a passphrase every boot"
    fi
else
    warn "gcr-ssh-agent not found (gcr-4 missing?) — skipping agent setup"
fi

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
