#!/usr/bin/env python3
"""Academic dashboard — a local, read-only view of teaching and research state.

Serves one page on 127.0.0.1 built from files already on disk: the course build
tracker, the manuscript tracker, and git recency. Nothing is written anywhere
and nothing leaves the machine.

Sized for a 900x1600 portrait monitor.
"""

from __future__ import annotations

import html
import importlib.util
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOME = Path.home()
REPOS = HOME / "repos"
COURSE = REPOS / "classes/ime/ai_applied_transport_2026"
PIPELINE = (REPOS / "linux-cfg/dotfiles/claude/skills/manuscript-pipeline"
            / "scripts/pipeline_status.py")
PORT = 8787
REFRESH_SECONDS = 600

STATE: dict[str, object] = {"tldr": -1}


def open_path(target: Path) -> None:
    """Hand a file or directory to the desktop's default handler."""
    try:
        subprocess.Popen(["xdg-open", str(target)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, ValueError):
        pass


@dataclass(frozen=True)
class ClassRow:
    number: int
    state: str
    raw: str
    when: date | None


def run(cmd: list[str], cwd: Path | None = None, timeout: int = 20) -> str:
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           timeout=timeout, check=False)
    except (subprocess.SubprocessError, OSError):
        return ""
    return p.stdout


def norm_state(raw: str) -> str:
    low = raw.lower()
    for s in ("taught", "approved", "gated", "partial", "built", "briefed"):
        if s in low:
            return s
    return "briefed"


def class_dates() -> dict[int, date]:
    """Scheduled dates from timing_actuals.md (day/month, current year)."""
    out: dict[int, date] = {}
    f = COURSE / "timing_actuals.md"
    if not f.exists():
        return out
    year = date.today().year
    for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"\|\s*(\d+)\s*\|\s*(\d{2})/(\d{2})\s*\|", line)
        if m:
            n, dd, mm = int(m.group(1)), int(m.group(2)), int(m.group(3))
            try:
                out[n] = date(year, mm, dd)
            except ValueError:
                continue
    return out


def classes() -> list[ClassRow]:
    f = COURSE / "tracker.md"
    if not f.exists():
        return []
    dates = class_dates()
    rows: list[ClassRow] = []
    for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"\|\s*(\d+)\s*\|\s*([^|]+)\|", line)
        if not m:
            continue
        n = int(m.group(1))
        raw = m.group(2).replace("*", "").strip()
        rows.append(ClassRow(n, norm_state(raw), raw, dates.get(n)))
    return sorted(rows, key=lambda r: r.number)


def next_class(rows: list[ClassRow], today: date) -> ClassRow | None:
    upcoming = [r for r in rows if r.when and r.when >= today]
    return min(upcoming, key=lambda r: r.when) if upcoming else None


def pipeline_report() -> str:
    """Run the manuscript reconciler in-process and capture its markdown."""
    if not PIPELINE.exists():
        return ""
    spec = importlib.util.spec_from_file_location("pipeline_status", PIPELINE)
    if spec is None or spec.loader is None:
        return ""
    mod = importlib.util.module_from_spec(spec)
    # Register before exec: @dataclass resolves sys.modules[cls.__module__],
    # which is None for a module loaded via module_from_spec alone (py3.14).
    sys.modules[spec.name] = mod
    try:
        spec.loader.exec_module(mod)
        # Call the library functions, not main(): main() parses sys.argv, which
        # here belongs to the dashboard and makes argparse exit.
        tracker = REPOS / "applications/Professor/paper_tracker.xlsx"
        papers = REPOS / "papers"
        if not tracker.exists() or not papers.is_dir():
            return ""
        aliases = mod.load_aliases(PIPELINE.parent.parent / "aliases.json")
        matches, updated, orphans = mod.build(tracker, papers, aliases)
        return mod.report(matches, updated, orphans, date.today())
    except Exception:  # noqa: BLE001 - the dashboard must never die on one panel
        return ""


def parse_pipeline(md: str) -> tuple[str | None, int, list[str], list[str]]:
    """Pull the banner, row count, movers and unmatched titles out of the report."""
    banner = None
    m = re.search(r"Tracker last updated \*\*(.+?)\*\* \((\d+) days ago\) — (\w+)", md)
    if m:
        banner = f"{m.group(1)} · {m.group(2)}d ago · {m.group(3)}"
    rows = len(re.findall(r"^\| \d+ \|", md, re.M))
    movers = re.findall(r"^- \*\*(.+?)\*\* — `(.+?)` commit (\d{4}-\d{2}-\d{2}), "
                       r"tracker says \*(.+?)\*", md, re.M)
    unmatched = re.findall(r"^- ([A-Z][^:\n]{0,30}): (.+)$", md, re.M)
    return (banner, rows,
            [f"{a} · {c} · {d}" for a, _b, c, d in movers[:5]],
            [f"{a}: {b.strip()}" for a, b in unmatched[:6]])


def repo_activity() -> list[tuple[str, str, str]]:
    out = []
    for name in ("papers", "classes", "applications", "linux-cfg"):
        d = REPOS / name
        if not (d / ".git").exists():
            continue
        last = run(["git", "-C", str(d), "log", "-1", "--format=%ad|%s",
                    "--date=short"]).strip()
        dirty = run(["git", "-C", str(d), "status", "--porcelain"]).strip()
        when, _, subj = last.partition("|")
        mark = "●" if dirty else "○"
        out.append((f"{mark} {name}", when, subj[:60]))
    return out


def esc(t: str) -> str:
    return html.escape(t, quote=True)


def render() -> str:
    today = date.today()
    rows = classes()
    nxt = next_class(rows, today)
    md = pipeline_report()
    banner, n_rows, movers, unmatched = parse_pipeline(md)

    items: list[tuple[str, str, Path]] = []   # (label, tldr, path to open)
    gated = [r for r in rows if r.state == "gated"]
    partial = [r for r in rows if r.state == "partial"]
    if gated:
        nums = ", ".join(f"class {r.number}" for r in gated)
        items.append((
            f"{len(gated)} deck(s) gated, awaiting your approval: {nums}",
            "These decks passed the pattern gate and are waiting on your "
            "sign-off before they count as approved. Read the deck, then move "
            "the row in tracker.md from gated to approved. Nothing else is "
            "blocked on them, but they stay unshippable until you look.",
            COURSE / "slides_en"))
    if partial:
        nums = ", ".join(f"class {r.number}" for r in partial)
        items.append((
            f"partial build on disk: {nums}",
            "A build was interrupted mid-way, so the deck on disk is neither "
            "the old version nor a finished new one. Finish the build or "
            "revert it; leaving it half-built is the state most likely to be "
            "taught by accident.",
            COURSE / "slides_en"))
    if banner and "STALE" in banner:
        items.append((
            f"manuscript tracker is stale ({banner.split(' · ')[1]})",
            "The tracker workbook has not been updated since its banner date, "
            "while the repos have moved on. Statuses shown for submissions and "
            "review rounds may be months out of date. Run the "
            "manuscript-pipeline skill for a row-by-row reconciliation.",
            REPOS / "applications/Professor"))
    if unmatched:
        items.append((
            f"{len(unmatched)} tracker row(s) unresolved to a directory",
            "These rows could not be matched to a folder in papers/ — either "
            "the work has no directory yet, or the names differ. A wrong match "
            "is worse than none, so ambiguous ones are declined. Map them once "
            "in the skill's aliases.json.",
            REPOS / "papers"))
    needs = [t for t, _w, _p in items]

    STATE["need_paths"] = [str(pp) for _t, _w, pp in items]
    if nxt:
        deck = COURSE / "slides_en" / f"class{nxt.number}.qmd"
        STATE["next_deck"] = str(deck if deck.exists() else COURSE / "slides_en")
    footer = (f"<footer>read-only · local files only · refreshes every "
              f"{REFRESH_SECONDS // 60} min</footer>")

    chips = "".join(
        f'<i class="s-{esc(r.state)}" title="class {r.number}: {esc(r.raw[:120])}">'
        f'{r.number}</i>' for r in rows
    )

    if nxt:
        days = (nxt.when - today).days
        when = "TODAY" if days == 0 else ("TOMORROW" if days == 1 else f"in {days} days")
        nxt_html = (f'<div class="big">Class {nxt.number}</div>'
                    f'<div class="sub">{esc(nxt.when.strftime("%a %d %b"))} · '
                    f'<b>{when}</b> · {esc(nxt.state)}</div>')
    else:
        nxt_html = '<div class="sub">No scheduled class ahead.</div>'

    tldr_i = int(STATE["tldr"])
    if items:
        parts = []
        for i, (label, why, _path) in enumerate(items):
            detail = (f"<div class='tldr'>{esc(why)}"
                      f"<button class='go' onclick=\"ev(event);go('need/{i}')\">"
                      f"open</button></div>") if i == tldr_i else ""
            parts.append(f"<li onclick=\"go('tldr/{i}')\" class='clk'>"
                         f"{esc(label)}{detail}</li>")
        needs_html = "".join(parts)
    else:
        needs_html = "<li class='ok'>Nothing waiting on you.</li>"
    movers_html = "".join(f"<li>{esc(m)}</li>" for m in movers) or "<li class='ok'>—</li>"
    unmatched_html = "".join(f"<li>{esc(u)}</li>" for u in unmatched) or ""
    repo_html = "".join(
        f"<li><b>{esc(n)}</b> <span class='dim'>{esc(w)}</span><br>"
        f"<span class='dim'>{esc(s)}</span></li>" for n, w, s in repo_activity()
    )

    detail = f"""<section class="clk" onclick="go('open/nextclass')" title="open this deck"><h1>Next class ›</h1>{nxt_html}</section>

<section><h1>Needs you</h1><ul class="needs">{needs_html}</ul></section>

<section class="clk" onclick="go('open/course')" title="open the decks folder"><h1>Course build · 14 classes ›</h1>
  <div class="chips">{chips}</div>
  <div class="legend">green taught/approved · amber gated · red partial · outline briefed</div>
</section>

<section class="clk" onclick="go('open/papers')" title="open the papers repo"><h1>Manuscripts{f" · {n_rows}" if n_rows else ""} ›</h1>
  <div class="sub">{esc(banner or "tracker unavailable")}</div>
  <ul>{movers_html}</ul>
  {f"<div class='legend'>unresolved rows</div><ul class='dim'>{unmatched_html}</ul>" if unmatched_html else ""}
</section>

<section class="clk" onclick="go('open/repos')" title="open the repos folder"><h1>Repositories ›</h1><ul>{repo_html}</ul></section>
"""

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta http-equiv="refresh" content="{REFRESH_SECONDS}">
<title>Academic Dashboard</title>
<style>
:root {{
  --bg:#101215; --panel:#161a1f; --line:#232a32; --fg:#e6e9ee;
  --dim:#8b95a3; --accent:#7aa2f7; --warn:#e0af68; --ok:#9ece6a; --hot:#f7768e;
}}
@media (prefers-color-scheme: light) {{
  :root {{ --bg:#f7f8fa; --panel:#fff; --line:#e3e6ea; --fg:#1a1d21;
           --dim:#697280; --accent:#3b5bdb; --warn:#b7791f; --ok:#2f855a; --hot:#c53030; }}
}}
* {{ box-sizing:border-box; }}
body {{ margin:0; padding:10px 14px 16px; background:var(--bg); color:var(--fg);
  font:15px/1.5 "Inter","Segoe UI",system-ui,sans-serif; }}
h1 {{ font-size:13px; letter-spacing:.14em; text-transform:uppercase;
  color:var(--dim); font-weight:600; margin:0 0 6px; }}
section {{ background:var(--panel); border:1px solid var(--line); border-radius:10px;
  padding:14px 16px; margin-bottom:14px; }}
.bar {{ display:flex; align-items:center; gap:4px; margin:-6px -4px 8px; }}
.bar .when {{ color:var(--dim); font-size:12px; letter-spacing:.04em; }}
.grow {{ flex:1; }}
.wb {{ width:24px; height:22px; border:1px solid var(--line); background:transparent;
  color:var(--dim); border-radius:5px; cursor:pointer; font-size:12px; line-height:1;
  display:grid; place-items:center; padding:0; }}
.wb:hover {{ color:var(--fg); border-color:var(--dim); }}
.wb.x:hover {{ color:#fff; background:var(--hot); border-color:var(--hot); }}
.summary {{ cursor:pointer; padding:2px 2px 8px; }}
.summary .l1 {{ font-size:17px; font-weight:650; letter-spacing:-.01em; }}
.summary .l2 {{ font-size:13px; color:var(--warn); margin-top:1px;
  white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }}
.big {{ font-size:30px; font-weight:650; letter-spacing:-.02em; }}
.sub {{ color:var(--dim); font-size:14px; margin-top:2px; }}
.sub b {{ color:var(--accent); }}
ul {{ margin:0; padding-left:18px; }}
li {{ margin:5px 0; }}
li.ok {{ color:var(--ok); list-style:none; margin-left:-18px; }}
.dim {{ color:var(--dim); font-size:12.5px; }}
.chips {{ display:flex; flex-wrap:wrap; gap:6px; margin-top:4px; }}
.chips i {{ font-style:normal; width:30px; height:30px; border-radius:7px;
  display:grid; place-items:center; font-size:13px; font-weight:600;
  border:1px solid var(--line); color:var(--dim); background:transparent; }}
.chips i.s-taught {{ background:var(--ok); color:#0d1117; border-color:transparent; }}
.chips i.s-approved {{ background:var(--ok); opacity:.55; color:#0d1117; border-color:transparent; }}
.chips i.s-gated {{ background:var(--warn); color:#0d1117; border-color:transparent; }}
.chips i.s-partial {{ background:var(--hot); color:#0d1117; border-color:transparent; }}
.legend {{ margin-top:10px; font-size:12px; color:var(--dim); }}
.clk {{ cursor:pointer; }}
section.clk:hover {{ border-color:var(--dim); }}
.needs li.clk:hover {{ text-decoration:underline; }}
.tldr {{ margin:6px 0 2px; padding:8px 10px; background:var(--bg);
  border:1px solid var(--line); border-radius:7px; color:var(--fg);
  font-size:13px; line-height:1.45; }}
.go {{ display:block; margin-top:7px; background:transparent; cursor:pointer;
  border:1px solid var(--line); color:var(--accent); border-radius:5px;
  padding:3px 9px; font-size:12px; }}
.go:hover {{ border-color:var(--accent); }}
.needs li {{ color:var(--warn); }}
.needs li.ok {{ color:var(--ok); }}
footer {{ color:var(--dim); font-size:11.5px; text-align:center; margin-top:6px; }}
</style></head><body>

<div class="bar">
  <span class="when">{esc(today.strftime("%a %d %B"))} · {esc(datetime.now().strftime("%H:%M"))}</span>
</div>

{detail}

{footer}
<script>
function go(p) {{
  fetch('/' + p, {{method: 'POST'}}).then(function () {{
    setTimeout(function () {{ location.reload(); }}, 120);
  }});
}}
function ev(e) {{ e.stopPropagation(); }}
</script>
</body></html>"""


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:  # noqa: N802
        route, _, action = self.path.strip("/").partition("/")

        if route == "tldr":
            idx = int(action) if action.isdigit() else -1
            STATE["tldr"] = -1 if STATE["tldr"] == idx else idx
            return self._no_content()

        if route == "need":
            idx = int(action) if action.isdigit() else -1
            paths = list(STATE.get("need_paths") or [])
            if 0 <= idx < len(paths):
                open_path(Path(paths[idx]))
            return self._no_content()

        if route == "open":
            targets = {
                "course": COURSE / "slides_en",
                "papers": REPOS / "papers",
                "repos": REPOS,
                "nextclass": Path(str(STATE.get("next_deck") or COURSE)),
            }
            open_path(targets.get(action, REPOS))
            return self._no_content()

        # Window geometry is the page's job now (window.resizeTo/moveTo), so
        # the server only tracks how much content to render.
        self._no_content()

    def _no_content(self) -> None:
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        try:
            body = render().encode("utf-8")
        except Exception as exc:  # noqa: BLE001 - never show a blank screen
            body = (f"<body style='font:14px monospace;padding:2rem'>"
                    f"dashboard error: {html.escape(str(exc))}</body>").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args) -> None:
        return


def main() -> int:
    if "--once" in sys.argv:
        print(render())
        return 0
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"academic dashboard on http://127.0.0.1:{PORT}", file=sys.stderr)
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
