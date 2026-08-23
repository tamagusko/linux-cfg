#!/usr/bin/env bash
# Open the academic dashboard in a chrome-less Firefox window.
#
# A dedicated profile is deliberate: without it, Firefox reuses the running
# session and the dashboard opens as a tab in an existing window (or refuses
# to start with "profile in use"), which defeats the i3 placement rule below.
# --class sets WM_CLASS, which is what i3 matches on.
set -euo pipefail

URL="http://127.0.0.1:8787"
PROFILE="${XDG_DATA_HOME:-$HOME/.local/share}/academic-dashboard/firefox"

mkdir -p "$PROFILE"

# Wait for the server: i3 exec fires before the user service is listening.
for _ in $(seq 1 40); do
  if exec 3<>/dev/tcp/127.0.0.1/8787 2>/dev/null; then exec 3>&-; break; fi
  sleep 0.25
done

# Chrome-less WITHOUT --kiosk: kiosk forces the window fullscreen, and i3 then
# refuses to resize it, which breaks every window button on the page. A
# userChrome.css in a dedicated profile hides the toolbars and leaves the
# window an ordinary, resizable one.
mkdir -p "$PROFILE/chrome"
cat > "$PROFILE/user.js" <<'JS'
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("datareporting.policy.firstRunURL", "");
user_pref("browser.startup.homepage_override.mstone", "ignore");
JS
cat > "$PROFILE/chrome/userChrome.css" <<'CSS'
#navigator-toolbox { display: none !important; }
CSS

firefox --class=AcademicDash --profile "$PROFILE" --new-window "$URL" &

# Placing the window on a workspace is not the same as showing it: i3 assigns
# it to 20:dash, but whatever workspace is already visible on that output stays
# visible. Switch to it once the window exists, so the dashboard is actually on
# screen at login rather than hidden one workspace away.
for _ in $(seq 1 60); do
  if xdotool search --class AcademicDash >/dev/null 2>&1; then
    i3-msg "workspace 20:dash" >/dev/null 2>&1 || true
    break
  fi
  sleep 0.5
done

wait
