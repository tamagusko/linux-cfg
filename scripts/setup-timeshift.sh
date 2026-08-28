#!/usr/bin/env bash
#
# Configure Timeshift as the OFF-DISK snapshot layer for this machine.
#
#   ./scripts/setup-timeshift.sh --list-targets
#   ./scripts/setup-timeshift.sh --device <UUID> [--include-home] [--dry-run]
#   ./scripts/setup-timeshift.sh --enable-schedule
#
# ---------------------------------------------------------------------------
# Read this before running it.
# ---------------------------------------------------------------------------
#
# This machine ALREADY snapshots `/`. Stage 90 installed snapper + snap-pac +
# grub-btrfs, root is btrfs with an @ subvolume, and snapper-timeline.timer and
# snapper-cleanup.timer are enabled. Every pacman transaction is bracketed by a
# pre/post snapshot and the snapshots appear in the GRUB menu.
#
# So Timeshift is NOT here to duplicate that, and this script deliberately does
# not put Timeshift in BTRFS mode. Two tools taking btrfs snapshots of the same
# @ subvolume, with two independent retention policies, is a way to make both
# harder to reason about and neither more trustworthy.
#
# What Timeshift adds that snapper cannot:
#
#   1. The snapshots land on a DIFFERENT PHYSICAL DISK. A btrfs snapshot is a
#      reflink inside the same filesystem. It survives a bad update, a bad rm
#      and a bad chown. It does not survive the SSD dying, because it was never
#      a second copy of the data — it is the same blocks, referenced twice.
#      This is the single most misunderstood thing about snapshots, so it is
#      worth being blunt: snapper on nvme0n1 protects you from yourself, not
#      from nvme0n1.
#
#   2. It can cover /home, which on this machine is ext4 on nvme0n1p3 and is
#      therefore invisible to snapper. See --include-home below, and read the
#      warning attached to it, because it is not a free win.
#
# What this script will NOT do:
#
#   * take the first snapshot. That is a full copy — roughly 23 GB of system,
#     plus ~21 GB if you opt into home — and it belongs in a terminal you are
#     watching, not in a script that has already scrolled past. The command is
#     printed at the end.
#   * install the cron entry. Same reason: an hourly `timeshift --check` that
#     fires before you have ever seen a snapshot complete is how you discover a
#     full destination disk at an inconvenient moment. Run the script again
#     with --enable-schedule once the first snapshot exists.
#   * touch snapper, grub-btrfs, or /etc/fstab.
#
# Idempotent: re-running with the same arguments rewrites the same config and
# reinstalls nothing. Any pre-existing /etc/timeshift/timeshift.json is saved
# next to itself as *.linux-cfg-bak.<timestamp> before the first write.

set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------- constants

CONF_DIR="/etc/timeshift"
CONF="$CONF_DIR/timeshift.json"
LEGACY_CONF="/etc/timeshift.json"
CRON_FILE="/etc/cron.d/timeshift-hourly"
PROBE_MNT="/run/timeshift-setup-probe"

# Retention. A personal workstation, not a server: the failure this protects
# against is "I broke something on Tuesday", not "reconstruct any minute of
# last month". Hourly is left off on purpose — with an rsync full-tree walk
# over ~23 GB it is noise that costs I/O and buys nothing snapper does not
# already give at finer granularity via snap-pac. Monthly is off too (0):
# snapper's pre/post pairs already cover "what did that update change", and a
# month-old full system image is rarely what anyone restores. A count of 0
# disables that schedule entirely.
COUNT_DAILY=2
COUNT_WEEKLY=1
COUNT_MONTHLY=0

DRY_RUN=0
INCLUDE_HOME=0
ALLOW_SAME_DISK=0
MODE=""
DEVICE_UUID=""

USER_HOME="$HOME"

# ------------------------------------------------------------------- output

ts()   { date '+%H:%M:%S'; }
info() { printf '%s [ .. ] %s\n' "$(ts)" "$*" >&2; }
ok()   { printf '%s [ OK ] %s\n' "$(ts)" "$*" >&2; }
warn() { printf '%s [WARN] %s\n' "$(ts)" "$*" >&2; }
die()  { printf '%s [FAIL] %s\n' "$(ts)" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# run CMD...  — executes, or prints what it would execute under --dry-run.
run() {
    if (( DRY_RUN )); then
        printf '%s [DRY ] %s\n' "$(ts)" "$(printf '%s ' "$@")" >&2
        return 0
    fi
    printf '%s [ -> ] %s\n' "$(ts)" "$(printf '%s ' "$@")" >&2
    "$@"
}

confirm() {
    local prompt="$1" reply
    if (( DRY_RUN )); then
        info "would ask: $prompt (dry run assumes yes)"
        return 0
    fi
    while true; do
        read -r -p "$prompt [y/n]: " reply
        case "$reply" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "please answer y or n" ;;
        esac
    done
}

usage() {
    sed -n '3,7p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
    cat <<'USAGE'

Options:
  --list-targets       Survey disks and print candidate destinations. Read-only.
  --device UUID        Filesystem UUID of the destination (from --list-targets).
  --include-home       Also back up ~/repos. Read the warning it prints first.
  --allow-same-disk    Permit a destination on the same physical disk as /.
                       Almost always wrong; see the header.
  --enable-schedule    Install the hourly cron check. Refuses until at least
                       one snapshot exists.
  --dry-run            Print every action without performing it.
  -h, --help           This text.
USAGE
}

# --------------------------------------------------------------- argument parse

(( $# )) || { usage; exit 2; }

while (( $# )); do
    case "$1" in
        --list-targets)    MODE="list" ;;
        --enable-schedule) MODE="schedule" ;;
        --device)          MODE="${MODE:-configure}"; DEVICE_UUID="${2:-}"; shift
                           [[ -n "$DEVICE_UUID" ]] || die "--device needs a UUID" ;;
        --include-home)    INCLUDE_HOME=1 ;;
        --allow-same-disk) ALLOW_SAME_DISK=1 ;;
        --dry-run)         DRY_RUN=1 ;;
        -h|--help)         usage; exit 0 ;;
        *)                 die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

[[ -n "$MODE" ]] || die "nothing to do; pass --list-targets, --device UUID or --enable-schedule"

[[ ${EUID} -ne 0 ]] || die "do not run this as root; it calls sudo where it needs to, and it needs \$HOME to be yours"

# ------------------------------------------------------------------ preflight

have pacman  || die "no pacman — this script is written for the Arch family (EndeavourOS here)"
have lsblk   || die "lsblk missing (util-linux)"
have findmnt || die "findmnt missing (util-linux)"
have python3 || die "python3 missing; it writes the config JSON"

ROOT_SRC="$(findmnt -no SOURCE / | sed 's/\[.*\]//')"          # /dev/nvme0n1p2
ROOT_DISK="$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null || true)" # nvme0n1
ROOT_FS="$(findmnt -no FSTYPE /)"

# ---------------------------------------------------------------- disk survey
#
# Read-only. Every candidate is mounted read-only under /run for long enough to
# read its free space and top-level entries, then unmounted. Nothing is written
# and no fstab entry is created — Timeshift mounts the destination by UUID on
# its own, under /run/timeshift/<pid>/backup, for the duration of a snapshot.

probe_device() {
    # probe_device <uuid> — prints "<avail-bytes>|<top-level entries>" or fails.
    local uuid="$1" dev
    dev="$(blkid -U "$uuid" 2>/dev/null || true)"
    [[ -n "$dev" ]] || { sudo -n true 2>/dev/null || true; dev="$(sudo blkid -U "$uuid" 2>/dev/null || true)"; }
    [[ -n "$dev" ]] || return 1

    sudo mkdir -p "$PROBE_MNT"
    # `-o ro` is the whole safety story here: a destination that turns out to
    # hold a live install of something else must come back unchanged.
    if ! sudo mount -o ro "$dev" "$PROBE_MNT" 2>/dev/null; then
        sudo rmdir "$PROBE_MNT" 2>/dev/null || true
        return 1
    fi
    local avail entries
    avail="$(df -B1 --output=avail "$PROBE_MNT" | tail -1 | tr -d ' ')"
    entries="$(sudo ls -A "$PROBE_MNT" 2>/dev/null | head -12 | tr '\n' ' ')"
    sudo umount "$PROBE_MNT"
    sudo rmdir "$PROBE_MNT" 2>/dev/null || true
    printf '%s|%s\n' "$avail" "$entries"
}

list_targets() {
    printf '\n=== this machine ===\n'
    printf '  root          : %s (%s, on disk %s)\n' "$ROOT_SRC" "$ROOT_FS" "${ROOT_DISK:-?}"
    printf '  /home         : %s (%s)\n' \
        "$(findmnt -no SOURCE /home | sed 's/\[.*\]//')" "$(findmnt -no FSTYPE /home)"
    if have snapper && systemctl is-enabled snapper-timeline.timer >/dev/null 2>&1; then
        printf '  snapper       : active on / (same disk — no protection against disk failure)\n'
    fi

    printf '\n=== candidate destinations ===\n'
    printf '  Only Linux filesystems on a disk other than %s are useful.\n' "${ROOT_DISK:-the root disk}"
    printf '  vfat/ntfs/exfat cannot hold Unix permissions or hardlinks, so rsync\n'
    printf '  snapshots on them are neither restorable nor space-efficient.\n\n'

    local name uuid fstype pk size
    while IFS=$'\t' read -r name fstype uuid size pk; do
        [[ -n "$uuid" ]] || continue
        case "$fstype" in
            ext2|ext3|ext4|btrfs|xfs) ;;
            *) continue ;;
        esac
        if [[ -n "$ROOT_DISK" && "$pk" == "$ROOT_DISK" ]]; then
            printf '  %-14s %-6s %-8s  SKIP: same physical disk as /\n' "$name" "$fstype" "$size"
            continue
        fi
        local probe avail entries
        if probe="$(probe_device "$uuid")"; then
            avail="${probe%%|*}"; entries="${probe#*|}"
            printf '  %-14s %-6s %-8s free=%-7s uuid=%s\n' \
                "$name" "$fstype" "$size" "$(numfmt --to=iec "$avail")" "$uuid"
            printf '  %-14s contains: %s\n' '' "${entries:-<empty>}"
        else
            printf '  %-14s %-6s %-8s  (could not probe) uuid=%s\n' "$name" "$fstype" "$size" "$uuid"
        fi
    done < <(lsblk -rno NAME,FSTYPE,UUID,SIZE,PKNAME | tr ' ' '\t')

    printf '\n  Re-run with:  %s --device <uuid>\n\n' "$0"
}

# --------------------------------------------------------------- size estimate

# dir_bytes <path> — apparent size in bytes, or 0.
#
# Not `du -sb ... | cut -f1 || echo 0`. du exits non-zero when it cannot read a
# subdirectory but still prints a total, so that form emits BOTH the number and
# the fallback, and the caller's $(( )) then dies on a two-line operand. Found
# by dry-running this function rather than by reading it.
dir_bytes() {
    local n
    n="$(du -sb "$1" 2>/dev/null | awk 'NR==1{print $1}')"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    printf '%s' "$n"
}

estimate_bytes() {
    # Everything Timeshift would copy on the first run, minus the obvious
    # excludes. Deliberately an over-estimate: it is used to refuse a
    # destination that is merely "probably" big enough.
    local root_used cache_used repos_used=0
    root_used="$(df -B1 --output=used / | tail -1 | tr -d ' ')"
    cache_used="$(dir_bytes /var/cache/pacman/pkg)"
    (( INCLUDE_HOME )) && repos_used="$(dir_bytes "$USER_HOME/repos")"
    echo $(( root_used - cache_used + repos_used ))
}

# ------------------------------------------------------------------ exclusions
#
# Order matters. Timeshift hands this list to rsync as --exclude-from, and rsync
# stops at the FIRST matching rule, so every narrow "+ include" and every narrow
# exclude has to appear before the broad rule it is carving out of.
#
# The `***` suffix in an include is the rsync idiom for "this directory and
# everything beneath it". A plain `/**` would match the contents but not the
# directory, and rsync would never descend into it.

build_exclude_list() {
    local -a ex=()

    if (( INCLUDE_HOME )); then
        # Carved out of ~/repos before ~/repos is included. All of these are
        # regenerable from a lockfile or a download, and all of them are large.
        ex+=(
            "$USER_HOME/repos/**/node_modules/**"
            "$USER_HOME/repos/**/.venv/**"
            "$USER_HOME/repos/**/venv/**"
            "$USER_HOME/repos/**/__pycache__/**"
            "$USER_HOME/repos/**/.mypy_cache/**"
            "$USER_HOME/repos/**/.ruff_cache/**"
            "$USER_HOME/repos/**/target/**"
            "$USER_HOME/repos/**/*.pt"
            "$USER_HOME/repos/**/*.pth"
            "$USER_HOME/repos/**/*.onnx"
            "$USER_HOME/repos/**/*.safetensors"
            "$USER_HOME/repos/**/*.ckpt"
            "+ $USER_HOME/repos/***"
        )
    fi

    # Everything else in this user's home. This is the line that keeps
    # ~/.claude, ~/.ssh, ~/.gnupg, ~/.config and ~/.cache off the destination
    # disk. The destination is not encrypted — nothing in lsblk shows LUKS —
    # so copying live OAuth tokens and SSH private keys onto a second drive
    # would turn one stolen or discarded disk into a full credential leak.
    # If you ever decide you want those, back them up somewhere encrypted
    # rather than widening this rule.
    ex+=( "$USER_HOME/**" )

    # /home/ollama-models is 39 GB of model blobs that `ollama pull` recreates.
    # It is not under any user's home, so the rule above does not cover it.
    ex+=( "/home/ollama-models/**" )

    # Any other user's home, present or future.
    ex+=( "/home/*/**" )
    ex+=( "/root/**" )

    # 8.1 GB of downloaded packages. pacman re-fetches them; paccache.timer is
    # already pruning them weekly. Copying them every snapshot is pure cost.
    ex+=( "/var/cache/pacman/pkg/**" )
    ex+=( "/var/tmp/**" )

    # snapper's own snapshots live here. Copying a snapshot tree into a backup
    # of the filesystem that contains it is a recursion Timeshift does not need
    # to discover at 3 a.m.
    ex+=( "/.snapshots/**" )

    printf '%s\n' "${ex[@]}"
}

# -------------------------------------------------------------- configure mode

configure() {
    # --- 1. sanity of the destination -------------------------------------
    local dev pk fstype
    dev="$(blkid -U "$DEVICE_UUID" 2>/dev/null || sudo blkid -U "$DEVICE_UUID" 2>/dev/null || true)"
    [[ -n "$dev" ]] || die "no filesystem with UUID $DEVICE_UUID (run --list-targets)"

    fstype="$(lsblk -no FSTYPE "$dev")"
    pk="$(lsblk -no PKNAME "$dev")"

    case "$fstype" in
        ext2|ext3|ext4|btrfs|xfs) ;;
        *) die "$dev is $fstype; rsync snapshots need a Unix filesystem (permissions + hardlinks)" ;;
    esac

    if [[ -n "$ROOT_DISK" && "$pk" == "$ROOT_DISK" ]]; then
        if (( ALLOW_SAME_DISK )); then
            warn "$dev is on $pk, the same physical disk as / — proceeding only because --allow-same-disk was passed"
            warn "this configuration does NOT protect against the disk failing"
        else
            die "$dev is on $pk, the same physical disk as /. That gives you a second copy that dies with the first. Pick another disk, or pass --allow-same-disk if you really mean it."
        fi
    fi

    if [[ "$(findmnt -no TARGET --source "$dev" 2>/dev/null || true)" == "/" ]]; then
        die "$dev is the root filesystem"
    fi

    # --- 2. space ---------------------------------------------------------
    local probe avail need
    probe="$(probe_device "$DEVICE_UUID")" || die "could not mount $dev read-only to inspect it"
    avail="${probe%%|*}"
    need="$(estimate_bytes)"

    info "destination : $dev ($fstype, disk $pk)"
    info "free there  : $(numfmt --to=iec "$avail")"
    info "first snapshot, estimated: $(numfmt --to=iec "$need")"
    info "already on that filesystem: ${probe#*|}"

    # 2x, not 1.1x: rsync snapshots after the first are hardlinked and cheap,
    # but "cheap" assumes files do not churn. A kernel update rewrites
    # /usr/lib/modules wholesale. Headroom is what stops a full destination
    # from turning a retention rotation into a failed snapshot.
    if (( avail < need * 2 )); then
        warn "less than 2x the first-snapshot size is free on the destination"
        confirm "continue anyway?" || die "aborted"
    fi

    # --- 3. tell the truth about what is being enabled --------------------
    printf '\n'
    printf '  This will configure Timeshift in RSYNC mode:\n'
    printf '    destination   %s  (uuid %s)\n' "$dev" "$DEVICE_UUID"
    printf '    scope         the root filesystem\n'
    if (( INCLUDE_HOME )); then
        printf '    plus          %s/repos  (%s)\n' "$USER_HOME" \
            "$(numfmt --to=iec "$(dir_bytes "$USER_HOME/repos")")"
        printf '    NOT included  ~/.claude, ~/.ssh, ~/.gnupg, ~/.config, ~/.cache, ~/.local\n'
        printf '\n'
        printf '    ! Restoring a Timeshift snapshot restores EVERYTHING in it.\n'
        printf '      With home included, rolling the system back to Tuesday also\n'
        printf '      rolls ~/repos back to Tuesday. Whatever you wrote since is\n'
        printf '      gone, and nothing warns you at restore time. Deselect home in\n'
        printf '      the restore dialog unless losing that work is the intent.\n'
    else
        printf '    NOT included  /home at all\n'
        printf '\n'
        printf '    ! /home is where the irreplaceable material is, and it has no\n'
        printf '      snapshot coverage on this machine at all: snapper cannot see\n'
        printf '      it (ext4), and this configuration excludes it. That is a\n'
        printf '      deliberate default, not an oversight — but it is a gap.\n'
    fi
    printf '    retention     %s daily, %s weekly, %s monthly (0 = off); no hourly, no boot\n' \
        "$COUNT_DAILY" "$COUNT_WEEKLY" "$COUNT_MONTHLY"
    printf '    schedule      written to the config but NOT armed (see --enable-schedule)\n'
    printf '    first snapshot NOT taken; the command is printed at the end\n'
    printf '\n'
    confirm "write this configuration?" || die "aborted, nothing changed"

    # --- 4. packages ------------------------------------------------------
    #
    # cronie is a hard dependency of the Arch timeshift package, but installing
    # it does not enable it, and Timeshift's scheduling is nothing but a cron
    # entry. A configured-but-unarmed cron daemon is the classic way to end up
    # with a backup config that has never once run.
    if have timeshift; then
        ok "timeshift already installed ($(timeshift --version 2>/dev/null | head -1))"
    else
        run sudo pacman -S --needed --noconfirm timeshift
    fi

    # --- 5. back up any existing config -----------------------------------
    if [[ -f "$LEGACY_CONF" ]]; then
        warn "$LEGACY_CONF exists (pre-20.x path). This script writes $CONF; check which one your timeshift reads."
    fi
    if [[ -f "$CONF" ]]; then
        local bak
        bak="$CONF.linux-cfg-bak.$(date +%Y%m%d-%H%M%S)"
        run sudo cp -a "$CONF" "$bak"
        ok "existing config saved to $bak"
    fi

    # --- 6. write the config ----------------------------------------------
    #
    # Written with python3 rather than a heredoc so the exclude list cannot be
    # broken by a path containing a quote, and so the file is valid JSON by
    # construction. Every value is a string: that is Timeshift's own format,
    # not an accident.
    local excludes tmp
    excludes="$(build_exclude_list)"
    tmp="$(mktemp)"
    # shellcheck disable=SC2064  # expand $tmp now, at trap-setting time
    trap "rm -f '$tmp'" EXIT

    EXCLUDES="$excludes" \
    UUID="$DEVICE_UUID" \
    CD="$COUNT_DAILY" CW="$COUNT_WEEKLY" CM="$COUNT_MONTHLY" \
    python3 - "$tmp" <<'PY'
import json, os, sys

excludes = [line for line in os.environ["EXCLUDES"].splitlines() if line.strip()]

conf = {
    "backup_device_uuid": os.environ["UUID"],
    "parent_device_uuid": "",
    "do_first_run": "false",
    # rsync mode, explicitly. btrfs mode would snapshot the @ subvolume in
    # place on the root disk, which is what snapper already does here.
    "btrfs_mode": "false",
    "include_btrfs_home_for_backup": "false",
    "include_btrfs_home_for_restore": "false",
    "stop_cron_emails": "true",
    # A schedule with a count of 0 is switched off, not "keep zero".
    "schedule_monthly": "true" if int(os.environ["CM"]) > 0 else "false",
    "schedule_weekly": "true" if int(os.environ["CW"]) > 0 else "false",
    "schedule_daily": "true" if int(os.environ["CD"]) > 0 else "false",
    "schedule_hourly": "false",
    "schedule_boot": "false",
    "count_monthly": os.environ["CM"],
    "count_weekly": os.environ["CW"],
    "count_daily": os.environ["CD"],
    "count_hourly": "0",
    "count_boot": "0",
    "snapshot_size": "0",
    "snapshot_count": "0",
    "date_format": "%Y-%m-%d %H:%M:%S",
    "exclude": excludes,
    "exclude-apps": [],
}

with open(sys.argv[1], "w") as fh:
    json.dump(conf, fh, indent=2)
    fh.write("\n")
PY

    run sudo mkdir -p "$CONF_DIR"
    run sudo install -m 0644 -o root -g root "$tmp" "$CONF"
    ok "wrote $CONF"

    # --- 7. verification ---------------------------------------------------
    printf '\n--- verification ---\n'
    if (( DRY_RUN )); then
        printf 'dry run: config not written, nothing to verify\n'
        printf 'the exclude list it would have written:\n'
        printf '%s\n' "$excludes" | sed 's/^/    /'
    else
        python3 -c 'import json,sys; json.load(open(sys.argv[1]))' <(sudo cat "$CONF") \
            && printf 'config parses as JSON      : yes\n'
        printf 'timeshift sees the device  :\n'
        sudo timeshift --list 2>&1 | sed 's/^/    /' | head -20
    fi

    # --- 8. what the user does next ---------------------------------------
    cat <<NEXT

--- next, in this order ---

1. Take the first snapshot yourself and watch it. It is a full copy of
   $(numfmt --to=iec "$need") and will take a while; a failure halfway
   through is worth seeing.

       sudo timeshift --create --comments "first full snapshot" --tags D

2. Confirm it landed, and how big it actually got:

       sudo timeshift --list
       sudo du -sh /run/timeshift/*/backup/timeshift/snapshots 2>/dev/null

3. Only then arm the schedule:

       $0 --enable-schedule

4. Some day soon, prove a restore works. An untested backup is a belief,
   not a backup. Restoring a single file is enough to prove the chain:

       sudo timeshift --restore --snapshot '<name>' --dry-run

NEXT
}

# ---------------------------------------------------------------- schedule mode
#
# Timeshift's "scheduling" is one cron entry that runs `timeshift --check` every
# hour; --check then creates whichever of the daily/weekly/monthly snapshots is
# actually due and rotates the old ones. Writing the file here rather than
# letting the GUI write it keeps it visible and greppable.

enable_schedule() {
    [[ -f "$CONF" ]] || die "$CONF does not exist; run --device <uuid> first"
    have timeshift || die "timeshift is not installed"

    # Refuse to arm a schedule that has never been proven to work once. The
    # first unattended run being also the first run ever is how you find out
    # about a full disk or a wrong UUID from a cron mail you do not read.
    if ! sudo timeshift --list 2>/dev/null | grep -qE '^[0-9]+\s'; then
        die "no snapshot exists yet. Take one by hand first:
    sudo timeshift --create --comments \"first full snapshot\" --tags D"
    fi

    run sudo pacman -S --needed --noconfirm cronie
    run sudo systemctl enable --now cronie.service

    local tmp
    tmp="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" EXIT
    cat > "$tmp" <<'CRON'
# Installed by linux-cfg/scripts/setup-timeshift.sh
#
# --check does not force a snapshot. It creates only what the schedule in
# /etc/timeshift/timeshift.json says is due, and rotates out what is past
# retention. Running it hourly is Timeshift's own design.
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
0 * * * * root /usr/bin/timeshift --check --scripted
CRON
    run sudo install -m 0644 -o root -g root "$tmp" "$CRON_FILE"
    ok "installed $CRON_FILE"

    printf '\n--- verification ---\n'
    if (( DRY_RUN )); then
        printf 'dry run: nothing installed\n'
    else
        printf 'cronie                     : %s\n' "$(systemctl is-active cronie.service)"
        printf 'cron entry                 :\n'
        sudo sed -n '4,$p' "$CRON_FILE" | sed 's/^/    /'
        printf '\nCheck tomorrow that a daily snapshot appeared:  sudo timeshift --list\n'
    fi
}

# ---------------------------------------------------------------------- main

case "$MODE" in
    list)      list_targets ;;
    configure) configure ;;
    schedule)  enable_schedule ;;
    *)         die "internal: unhandled mode '$MODE'" ;;
esac
