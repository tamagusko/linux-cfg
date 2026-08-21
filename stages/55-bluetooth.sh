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

# ------------------------------------------------------------- trusting audio
#
# Pairing a device is not the same as trusting it, and the difference only
# shows when the *device* opens the connection. Power on a headset and it calls
# the host; bluetoothd asks an agent to authorise the A2DP service, blueman's
# prompt goes unanswered, and the attempt dies with
#
#     profiles/audio/a2dp.c:auth_cb() Access denied: org.bluez.Error.Canceled
#
# leaving a headset that reports Connected but carries no audio. Clicking
# Connect in blueman works because that connection is outgoing and needs no
# authorisation at all — which is why the workaround looks like "disconnect and
# reconnect it every single time".
#
# Trusted devices skip service authorisation, so the headset simply works when
# switched on. Scoped deliberately to devices advertising an audio profile:
# having once paired a phone should not silently let it open services
# unprompted.
#
# A fresh machine has nothing paired yet, so this is a no-op there and takes
# effect on the next run, after the headset has been paired once by hand.
if [[ "$DRY_RUN" == "1" ]]; then
    info "dry run — not changing device trust"
else
    trusted_any=0
    # IFS is $'\n\t' from common.sh, so a plain `read` would swallow the whole
    # line into the first variable. Space matters here and only here.
    while IFS=' ' read -r _ mac rest; do
        [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || continue
        dev_info="$(bluetoothctl info "$mac" 2>/dev/null)" || continue
        grep -qE 'UUID: (Audio Sink|Headset|Handsfree)' <<<"$dev_info" || continue
        trusted_any=1
        if grep -q 'Trusted: yes' <<<"$dev_info"; then
            ok "already trusted: $rest ($mac)"
        elif bluetoothctl trust "$mac" >/dev/null 2>&1; then
            ok "trusted: $rest ($mac)"
        else
            warn "could not trust $rest ($mac)"
        fi
    done < <(bluetoothctl devices Paired 2>/dev/null)

    ((trusted_any)) || info "no paired audio devices yet — pair one, then re-run this stage"
fi

ok "bluetooth stage done"
