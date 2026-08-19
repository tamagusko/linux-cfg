#!/usr/bin/env bash
# Stage 55 — bluetooth: enable the stack so audio and input devices can pair.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 55 — BLUETOOTH"

# bluez, bluez-utils and blueman come from packages/pacman.txt (stage 30). This
# stage only turns the stack on: a fresh EndeavourOS install ships bluez with
# bluetooth.service disabled, so blueman starts, finds no adapter, and reports
# "Bluetooth is disabled" with no hint that a service is missing.

if ! have bluetoothctl; then
    warn "bluez-utils not installed — run stage 30 first"
    exit 0
fi

# No adapter at all (desktop without a dongle): enabling the service is
# harmless but pointless, and the message is worth seeing.
if [[ -z "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]]; then
    warn "no bluetooth adapter found — skipping"
    exit 0
fi

if systemctl is-enabled --quiet bluetooth.service; then
    ok "bluetooth.service already enabled"
else
    info "enabling bluetooth.service"
    run sudo systemctl enable --now bluetooth.service
fi

# A soft block survives reboots and silently defeats everything above.
if have rfkill && rfkill list bluetooth | grep -q 'Soft blocked: yes'; then
    info "bluetooth is soft-blocked by rfkill — unblocking"
    run sudo rfkill unblock bluetooth
fi

# Not done here: AutoEnable in /etc/bluetooth/main.conf. bluez defaults it to
# true ("Defaults to 'true'" in the shipped main.conf), so the adapter already
# powers on at boot and on hotplug. Uncommenting it would edit a system file for
# no change in behaviour.

ok "bluetooth stage done"
