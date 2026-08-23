#!/usr/bin/env python3
"""Academic dashboard as a system-tray / menu-bar applet.

Click the icon for a menu built from the same local data the web dashboard
uses: next class, what needs you, manuscript state, and shortcuts that open the
relevant folder. Nothing overlaps other windows and there is no window to place.

Backends, chosen at runtime:
  Linux  AppIndicator3 via PyGObject  (no extra packages on this machine)
  macOS  pystray                      (pip install pystray pillow)
"""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import serve  # noqa: E402  - same data layer as the web dashboard

REFRESH_MS = 10 * 60 * 1000


def collect() -> dict:
    """Everything the menu needs, in one pass over the local files."""
    rows = serve.classes()
    nxt = serve.next_class(rows, date.today())
    md = serve.pipeline_report()
    banner, n_rows, movers, unmatched = serve.parse_pipeline(md)

    if nxt:
        days = (nxt.when - date.today()).days
        when = "TODAY" if days == 0 else ("TOMORROW" if days == 1
                                          else f"in {days} days")
        head = f"Class {nxt.number} · {when} · {nxt.state}"
    else:
        head = "No class scheduled"

    needs: list[str] = []
    gated = [r for r in rows if r.state == "gated"]
    partial = [r for r in rows if r.state == "partial"]
    if gated:
        needs.append(f"{len(gated)} deck(s) await your approval: "
                     + ", ".join(str(r.number) for r in gated))
    if partial:
        needs.append("partial build: class "
                     + ", ".join(str(r.number) for r in partial))
    if banner and "STALE" in banner:
        needs.append(f"tracker stale · {banner.split(' · ')[1]}")
    if unmatched:
        needs.append(f"{len(unmatched)} tracker row(s) unresolved")

    return {"head": head, "needs": needs, "movers": movers,
            "banner": banner or "tracker unavailable", "n_rows": n_rows}


def open_path(p: Path) -> None:
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    try:
        subprocess.Popen([opener, str(p)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def open_panel() -> None:
    """The full web dashboard, for when the menu is not enough."""
    open_path(Path("http://127.0.0.1:8787"))


ACTIONS: list[tuple[str, Path]] = [
    ("Open course decks", serve.COURSE / "slides_en"),
    ("Open papers repo", serve.REPOS / "papers"),
    ("Open tracker folder", serve.REPOS / "applications/Professor"),
    ("Open repos", serve.REPOS),
]


# ----------------------------------------------------------------- Linux ----
def run_appindicator() -> int:
    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("AppIndicator3", "0.1")
    from gi.repository import AppIndicator3, GLib, Gtk

    ind = AppIndicator3.Indicator.new(
        "academic-dashboard", "x-office-calendar",
        AppIndicator3.IndicatorCategory.APPLICATION_STATUS)
    ind.set_status(AppIndicator3.IndicatorStatus.ACTIVE)

    def build() -> Gtk.Menu:
        d = collect()
        menu = Gtk.Menu()

        def item(label: str, cb=None, enabled: bool = True) -> None:
            mi = Gtk.MenuItem(label=label)
            if cb:
                mi.connect("activate", lambda _w: cb())
            mi.set_sensitive(enabled and cb is not None)
            mi.show()
            menu.append(mi)

        def sep() -> None:
            s = Gtk.SeparatorMenuItem()
            s.show()
            menu.append(s)

        item(d["head"], open_panel)
        sep()
        if d["needs"]:
            for n in d["needs"]:
                item(f"  {n}", open_panel)
        else:
            item("  Nothing waiting on you", None, enabled=False)
        sep()
        item(f"Manuscripts · {d['n_rows']} · {d['banner']}", open_panel)
        for m in d["movers"][:4]:
            item(f"  {m}", None, enabled=False)
        sep()
        for label, path in ACTIONS:
            item(label, lambda p=path: open_path(p))
        sep()
        item("Open full dashboard", open_panel)
        item("Refresh now", lambda: ind.set_menu(build()))
        item("Quit", Gtk.main_quit)
        return menu

    ind.set_menu(build())
    # The label puts the headline in the bar itself, where a tray supports it.
    try:
        ind.set_label(collect()["head"][:40], "")
    except Exception:  # noqa: BLE001 - label support is optional
        pass

    def tick() -> bool:
        ind.set_menu(build())
        try:
            ind.set_label(collect()["head"][:40], "")
        except Exception:  # noqa: BLE001
            pass
        return True

    GLib.timeout_add(REFRESH_MS, tick)
    Gtk.main()
    return 0


# ----------------------------------------------------------------- macOS ----
def run_pystray() -> int:
    import pystray
    from PIL import Image, ImageDraw

    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.rounded_rectangle((6, 6, 58, 58), 12, outline=(120, 160, 240, 255), width=6)
    dr.line((20, 30, 44, 30), fill=(120, 160, 240, 255), width=5)
    dr.line((20, 42, 36, 42), fill=(120, 160, 240, 255), width=5)

    def menu() -> pystray.Menu:
        d = collect()
        items = [pystray.MenuItem(d["head"], lambda: open_panel()),
                 pystray.Menu.SEPARATOR]
        items += [pystray.MenuItem(n, lambda: open_panel())
                  for n in d["needs"]] or [
            pystray.MenuItem("Nothing waiting on you", None, enabled=False)]
        items += [pystray.Menu.SEPARATOR]
        items += [pystray.MenuItem(label, (lambda p=path: open_path(p)))
                  for label, path in ACTIONS]
        items += [pystray.Menu.SEPARATOR,
                  pystray.MenuItem("Open full dashboard", lambda: open_panel()),
                  pystray.MenuItem("Quit", lambda icon: icon.stop())]
        return pystray.Menu(*items)

    pystray.Icon("academic-dashboard", img, "Academic Dashboard", menu()).run()
    return 0


def ensure_server() -> None:
    """Start the data server if nothing is listening.

    Keeps the applet self-contained: one thing to autostart on either platform,
    rather than a service plus an applet that depend on each other.
    """
    import socket
    with socket.socket() as sock:
        sock.settimeout(0.4)
        if sock.connect_ex(("127.0.0.1", serve.PORT)) == 0:
            return
    try:
        subprocess.Popen([sys.executable, str(HERE / "serve.py")],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except OSError:
        pass


def main() -> int:
    ensure_server()
    if sys.platform != "darwin" and importlib.util.find_spec("gi"):
        try:
            return run_appindicator()
        except (ImportError, ValueError) as exc:
            print(f"AppIndicator unavailable ({exc}); trying pystray",
                  file=sys.stderr)
    if importlib.util.find_spec("pystray"):
        return run_pystray()
    print("No tray backend. Linux: PyGObject + libappindicator. "
          "macOS: pip install pystray pillow", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
