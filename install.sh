#!/usr/bin/env bash
#
# linux-cfg — EndeavourOS / Arch workstation setup.
#
#   ./install.sh --dry-run          show every command without running it
#   ./install.sh                    run all stages
#   ./install.sh --only 20-gpu      run a single stage
#   ./install.sh --from 40-dev      resume from a stage onwards
#   ./install.sh --list             list stages
#
# Every stage is independently runnable and safe to run twice.

set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR

# Fail with an actionable message rather than a bare "No such file". A clone
# that is missing lib/ is not a broken install, it is an incomplete checkout —
# and the bare shell error for that reads like a bug in the script.
if [[ ! -r "$REPO_DIR/lib/common.sh" ]]; then
    printf 'ERROR: %s/lib/common.sh is missing.\n\n' "$REPO_DIR" >&2
    printf 'Every stage sources this file, so nothing can run without it.\n' >&2
    printf 'The checkout is incomplete. Re-clone with:\n\n' >&2
    printf '  git clone https://github.com/tamagusko/linux-cfg.git\n\n' >&2
    printf 'and confirm lib/common.sh is present before re-running.\n' >&2
    exit 1
fi

# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

usage() {
    # Print the leading comment block, stopping at the first non-comment line,
    # so this cannot drift out of sync with the header.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

list_stages() {
    local f
    for f in "$REPO_DIR"/stages/*.sh; do
        [[ -e "$f" ]] || continue
        basename "$f" .sh
    done | sort
}

ONLY=""
FROM=""

while (($# > 0)); do
    case "$1" in
        --dry-run) DRY_RUN=1; export DRY_RUN ;;
        --yes|-y)  ASSUME_YES=1; export ASSUME_YES ;;
        --only)    ONLY="${2:?--only needs a stage name}"; shift ;;
        --from)    FROM="${2:?--from needs a stage name}"; shift ;;
        --list)    list_stages; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *)         die "unknown argument: $1 (try --help)" ;;
    esac
    shift
done

mapfile -t all_stages < <(list_stages)
((${#all_stages[@]} > 0)) || die "no stages found in $REPO_DIR/stages"

# Build the list of stages to run.
declare -a to_run=()
if [[ -n "$ONLY" ]]; then
    printf '%s\n' "${all_stages[@]}" | grep -qx "$ONLY" || die "no such stage: $ONLY"
    to_run=("$ONLY")
else
    started=0
    for stage in "${all_stages[@]}"; do
        if [[ -n "$FROM" && $started -eq 0 ]]; then
            [[ "$stage" == "$FROM" ]] || continue
            started=1
        fi
        to_run+=("$stage")
    done
    if [[ -n "$FROM" && ${#to_run[@]} -eq 0 ]]; then
        die "no such stage: $FROM"
    fi
fi

banner "linux-cfg — $(date '+%Y-%m-%d %H:%M')"
[[ "$DRY_RUN" == "1" ]] && warn "DRY RUN — nothing will be changed"
log "repo:   $REPO_DIR"
log "log:    $LOG_FILE"
log "stages: $(printf '%s ' "${to_run[@]}")"

for stage in "${to_run[@]}"; do
    # Each stage runs in its own bash so that a stage calling `exit 0` to skip
    # itself (no NVIDIA GPU, no btrfs) does not end the whole run.
    if bash "$REPO_DIR/stages/${stage}.sh"; then
        ok "stage ${stage} completed"
    else
        error "stage ${stage} FAILED — stopping"
        error "fix it, then resume with: ./install.sh --from ${stage}"
        exit 1
    fi
done

print_summary

banner "NEXT STEPS"
log "1. Reboot — the NVIDIA driver and the cedilla input modules need it."
log "2. After reboot, verify:  nvidia-smi  &&  sudo firewall-cmd --list-all"
log "3. Activate Typora by hand (licence key is deliberately not scripted)."
log "4. Set your git identity:  git config --global user.name / user.email"
log "5. Read docs/MAINTENANCE.md for the update routine."
