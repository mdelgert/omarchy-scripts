# omarchy-scripts

`omarchy-scripts` is an Omarchy plugin and small Python engine for browsing, editing, deleting, and running plain Bash scripts. Scripts describe themselves with `@script.*` and `@param` header comments, so the CLI and plugin can show them without per-script UI code. v1 intentionally does not require `check`/`apply`/`undo` verbs, backups, or AI authoring.

## Quick start

The engine has no Python package dependencies beyond Python 3 and Bash. The development installer also needs `rsync`; using the plugin requires an Omarchy session. On Arch/Omarchy, install missing base tools with your normal package manager (for example, `python`, `bash`, and `rsync`). Qt 6's `qmllint` and an Omarchy shell tree are needed only for `make lint-qml`.

```bash
make test
./omarchy-plugin/install.sh
```

The installer copies this checkout into Omarchy's plugin directory, validates the installed scripts, and asks the running shell to rescan plugins when one is available. It prints the enable/open commands at completion. For ordinary installation from a Git repository, use Omarchy's plugin command shown in `omarchy-plugin/install.sh`.

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
- [Contributor rules](AGENTS.md) — standing implementation and validation rules.
