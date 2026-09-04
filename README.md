# omarchy-scripts

`omarchy-scripts` is an Omarchy plugin and small Python engine for browsing, editing, deleting, and running plain Bash scripts. Scripts describe themselves with `@script.*` and `@param` header comments, so the CLI and plugin can show them without per-script UI code. v1 intentionally does not require `check`/`apply`/`undo` verbs, backups, or AI authoring.

## Install

```bash
omarchy plugin add https://github.com/mdelgert/omarchy-scripts.git --enable
```

That clones the repository into `~/.config/omarchy/plugins/`, validates it, and offers to enable it. When it asks for a bar section, pick one — that is where the scripts icon lands.

Open it from the bar icon, or:

```bash
omarchy-shell shell toggle io.github.mdelgert.omarchy-scripts '{}'
```

Pass `{"fullscreen": true}` instead of `{}` to open it full-panel, and `{"script": "<id>"}` to jump straight to one script's detail view.

Optionally bind a key in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + F", "Scripts (fullscreen)",
  "omarchy-shell shell toggle io.github.mdelgert.omarchy-scripts '{\"fullscreen\":true}'")
```

Update later with:

```bash
omarchy plugin update io.github.mdelgert.omarchy-scripts
omarchy-restart-shell     # only needed when the plugin's QML changed
```

> A freshly installed third-party plugin lists as `disabled` until enabled, and
> a plugin enabled *without* a section stays out of the bar. If there is no
> icon:
> ```bash
> omarchy plugin disable io.github.mdelgert.omarchy-scripts
> omarchy plugin enable io.github.mdelgert.omarchy-scripts right
> ```

### Remove

```bash
omarchy plugin disable io.github.mdelgert.omarchy-scripts   # off, still installed
omarchy plugin remove io.github.mdelgert.omarchy-scripts --yes
```

`remove` disables it first. A plugin added with `omarchy plugin add` is a git clone and is deleted outright; one copied in by `omarchy-plugin/install.sh` (the development install, see below) is moved to a hidden backup beside it instead, which you can delete too:

```bash
rm -rf ~/.config/omarchy/plugins/.io.github.mdelgert.omarchy-scripts.bak.*
```

## Quick start (development)

The engine has no Python package dependencies beyond Python 3 and Bash. The development installer also needs `rsync`; using the plugin requires an Omarchy session. On Arch/Omarchy, install missing base tools with your normal package manager (for example, `python`, `bash`, and `rsync`). Qt 6's `qmllint` and an Omarchy shell tree are needed only for `make lint-qml`.

```bash
make test
./omarchy-plugin/install.sh
```

The installer copies this checkout into Omarchy's plugin directory, validates the installed scripts, and asks the running shell to rescan plugins when one is available. It prints the enable/open commands at completion. Use this instead of `omarchy plugin add` only when iterating on the code itself — it installs uncommitted changes too.

Try the engine directly from this checkout:

```bash
./bin/omarchy-scripts list
./bin/omarchy-scripts run hostname-info
./bin/omarchy-scripts run greet-user --param name=World --param shout=true
```

## Example scripts

- [`greet-user.sh`](scripts/examples/greet-user.sh) shows declared string and boolean parameters, plus the optional argument helper.
- [`hostname-info.sh`](scripts/examples/hostname-info.sh) is a no-parameter diagnostics script: it prints host, route, address, and DNS information.
- [`largest-directories.sh`](scripts/examples/largest-directories.sh) shows `path` and bounded integer metadata, including a runtime `$HOME` default.

## Documentation

- [Vision](docs/VISION.md) — why v1 stays intentionally small and what v2 may add.
- [Architecture](docs/ARCHITECTURE.md) — engine, CLI, plugin, JSON, and discovery boundaries.
- [Script specification](docs/SCRIPT_SPEC.md) — exact metadata and parameter format.
- [Agent workflow](docs/AGENT_WORKFLOW.md) — task files, branches, and completion checks.
- [Running a task](docs/RUNNING_A_TASK.md) — what to actually say to kick off and merge a task.
- [GitHub token setup](docs/GITHUB_TOKEN_SETUP.md) — repo-scoped `gh` authentication for opening PRs.
- [Contributor rules](AGENTS.md) — standing implementation and validation rules.
