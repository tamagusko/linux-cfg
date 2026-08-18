#!/usr/bin/env bash
# Stage 50 — keyboard input: cedilla on a US-International layout.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 50 — INPUT (CEDILLA)"

# Makes ' + c produce ç rather than ć on a US-International layout.
#
# Two bugs in the previous version of this fix:
#
#  1. It re-copied Compose to Compose.bak on every run. On the second run the
#     "original" backup was overwritten with the already-patched file, so the
#     real original was gone for good.
#  2. It never wrote GTK_IM_MODULE / QT_IM_MODULE to /etc/environment, which is
#     step 4 of the procedure. Without them the fix does not take effect at all,
#     so the script appeared to succeed while changing nothing observable.

COMPOSE=/usr/share/X11/locale/en_US.UTF-8/Compose
PRISTINE="${COMPOSE}.pristine"

if [[ ! -f "$COMPOSE" ]]; then
    warn "$COMPOSE not found — skipping cedilla fix"
    exit 0
fi

# Add :en to the cedilla module locale list, where the cache exists. gtk2 is
# absent on modern installs, so its absence is not an error.
for cache in /usr/lib/gtk-3.0/3.0.0/immodules.cache /usr/lib/gtk-2.0/2.10.0/immodules.cache; do
    if [[ -f "$cache" ]]; then
        if grep -q '"az:ca:co:fr:gv:oc:pt:sq:tr:wa:en"' "$cache"; then
            ok "already patched: $cache"
        else
            info "patching $cache"
            run sudo sed -i 's/"az:ca:co:fr:gv:oc:pt:sq:tr:wa"/"az:ca:co:fr:gv:oc:pt:sq:tr:wa:en"/' "$cache"
        fi
    else
        info "not present, skipping: $cache"
    fi
done

# Keep exactly one pristine copy, created only if it does not already exist.
if [[ -f "$PRISTINE" ]]; then
    ok "pristine Compose already preserved at $PRISTINE"
else
    info "preserving original Compose at $PRISTINE"
    run sudo cp -a "$COMPOSE" "$PRISTINE"
fi

# Rewrite from the pristine copy, not from the current file, so repeated runs
# are idempotent instead of compounding.
if grep -q 'ć' "$PRISTINE" 2>/dev/null; then
    info "applying ć -> ç substitution"
    tmp="$(mktemp)"
    sed -e 's/ć/ç/g' -e 's/Ć/Ç/g' "$PRISTINE" > "$tmp"
    run sudo install -m 0644 "$tmp" "$COMPOSE"
    command rm -f -- "$tmp"
    ok "Compose patched"
else
    ok "no ć in pristine Compose; nothing to substitute"
fi

# Step 4: the input-method environment variables. Without these, nothing above
# has any visible effect.
info "setting GTK_IM_MODULE / QT_IM_MODULE in /etc/environment"
for var in GTK_IM_MODULE QT_IM_MODULE; do
    if grep -qE "^${var}=cedilla$" /etc/environment 2>/dev/null; then
        ok "$var already set"
    else
        run sudo sed -i "/^${var}=/d" /etc/environment
        run_tty sudo tee -a /etc/environment <<<"${var}=cedilla"
        ok "$var=cedilla"
    fi
done

warn "cedilla needs a reboot (or full re-login) to take effect"
ok "input stage done"
