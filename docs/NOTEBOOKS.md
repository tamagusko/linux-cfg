# Notebooks: double-click to open

Double-click any `.ipynb` in Thunar. It opens in JupyterLab, bound to the
environment of whichever project contains it. No terminal, no activation step.

Installed by [`scripts/setup-jupyter-desktop.sh`](../scripts/setup-jupyter-desktop.sh).
Re-run it any time; it repairs rather than duplicates.

## How it works

One global JupyterLab, many project kernels.

| Piece | Where | Role |
|---|---|---|
| JupyterLab 4.6 | `uv tool install jupyterlab` | The single server binary on `PATH` |
| `notebook-open` | `~/.local/bin/` | Decides *which* environment and *whether* to start a server |
| `notebook-open.desktop` | `~/.local/share/applications/` | Registers the launcher for `application/x-ipynb+json` |
| Per-project kernel | `~/.local/share/jupyter/kernels/<name>/` | Points at that project's `.venv` |
| Log | `~/.local/state/notebook-launcher/launcher.log` | Every open, every failure |

On a double-click the launcher walks **up** from the notebook to the nearest
`pyproject.toml` or `.venv` and treats that as the project root. Three outcomes,
all deliberate:

1. **Notebook in a project** → serve from the project root, using its kernel.
2. **Notebook outside any project** → serve from the notebook's own directory,
   using the global environment. It opens; it does not fail cryptically.
3. **A live server already covers the file** → reuse it, open a tab, start
   nothing. No duplicate servers, no port creep.

Because the walk finds the *nearest* marker, a nested project keeps its own
environment: a notebook in `papers/in-progress/ltpp-iri/` uses that project, not
the `papers/` root.

First launch takes a few seconds while the server boots — a "Starting Jupyter…"
notification appears so the pause is not mysterious. Subsequent opens against
that server are instant. Notebooks open in the default browser.

## Projects wired up

| Repo | Kernel | Notes |
|---|---|---|
| `UCD` | `ucd` | pandas, scikit-learn, statsmodels, shap, openpyxl |
| `papers` | `papers` | base + opt-in groups: `boost`, `geo`, `dl`, `tf`, `cloud`, `docs` |
| `classes` | `classes` | base + opt-in groups: `geo`, `dl`, `app` |
| `applications` | `applications` | includes OpenCV and the geo stack |

All pinned to Python 3.13 with a committed `uv.lock`.

## Everyday use

Add a dependency — this updates `pyproject.toml` and `uv.lock`, so the change is
reproducible:

```bash
cd ~/repos/papers
uv add polars
```

Install an opt-in group (these are locked but not installed, because the deep
learning and geospatial stacks are large):

```bash
uv sync --group geo        # geopandas, osmnx, rasterio, pysal…
uv sync --group dl         # torch, torchvision
uv sync --all-groups       # everything
```

From inside a notebook, use `!uv add <pkg>` rather than `!pip install` — pip
would install into the wrong place and not persist.

## Binding a notebook to its kernel

A notebook stores which kernel it wants. Ones without that metadata open on
whatever Jupyter picks, which may be the global environment rather than the
project's. Set it once:

```bash
cd ~/repos/papers
uv run jupytext --set-kernel papers notebooks/analysis.ipynb
```

Or switch kernel in the Lab UI and save — the choice is written into the file.

## Pointing a new repo at this flow

```bash
~/repos/linux-cfg/scripts/setup-jupyter-desktop.sh --project ~/repos/newthing
cd ~/repos/newthing && uv add pandas matplotlib
```

That creates the uv project if missing, adds `ipykernel` and `jupytext`, and
registers a `--user` kernel named after the directory.

## When a double-click does nothing

```bash
tail -30 ~/.local/state/notebook-launcher/launcher.log
~/repos/linux-cfg/scripts/setup-jupyter-desktop.sh --status
```

The launcher also raises a desktop notification on failure, with the log path —
a silent double-click is treated as a defect, not a normal outcome.

Check the association with **`gio mime application/x-ipynb+json`**. Do not use
`xdg-mime query filetype`: it reports `application/json` for notebooks because it
stops at the parent type. GIO is what Thunar consults, and it answers correctly.

List running servers and their roots:

```bash
ls ~/.local/share/jupyter/runtime/jpserver-*.json
```

## Undo

```bash
~/repos/linux-cfg/scripts/setup-jupyter-desktop.sh --uninstall
```

Removes the association, the desktop entry and the launcher. It deliberately
leaves the JupyterLab tool, the project environments and the registered kernels
alone — those are useful without the double-click wiring. Remove them by hand:

```bash
uv tool uninstall jupyterlab
rm -rf ~/.local/state/notebook-launcher
rm -rf ~/.local/share/jupyter/kernels/<name>
```
