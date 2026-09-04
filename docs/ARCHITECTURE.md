# Architecture

## Boundaries

```text
bundled scripts/ + workspace scripts/ + configured external dirs/
                                  |
                           Python engine
                         /                 \\
                 JSON CLI              JSON-consuming QML plugin
```

The Python engine in `src/omarchy_scripts/` is the single source of truth for script discovery, header metadata parsing, parameter validation, execution, last-run recording, creation, deletion, and settings-file reads/writes. It has no QML or Omarchy UI dependency.

`bin/omarchy-scripts` locates the repository-relative `src/`, `lib/`, and `scripts/` directories, then launches the CLI. The CLI is a thin JSON interface over the engine: `list`, `info`, `run`, `last-run`, `edit`, `new`, `delete`, `validate`, and `config` (`init`/`list-dirs`/`add-dir`/`remove-dir` plus generic `get`/`set`/`unset`). `edit` replaces the CLI process with `$EDITOR` (falling back to `vi`); the QML frontend uses Omarchy's editor launcher for the same file-oriented action.

The plugin under `omarchy-plugin/` is likewise a consumer. `ScriptEngine.qml` never reads a script file, parses comments, validates values, or edits settings; it calls the runner and presents its JSON. QML uses argv arrays for processes, and Python uses `subprocess.run()` with an argv list. Neither layer turns metadata or a parameter into executable shell text.

## Discovery and ownership

Discovery scans roots in this order:

1. `<engine-root>/scripts` — bundled scripts shipped with the checkout or installed plugin.
2. `${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}/scripts` — the user's workspace scripts.
3. Each configured external directory from `${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}/config.json`, in the listed `scriptDirs` order.

Only `*.sh` files are considered. Malformed or unreadable files are returned as `problems`, so one bad script does not hide the others. A duplicate ID is also a problem: first scanned wins, so later roots never silently override earlier ones. With the current order, bundled beats workspace, and both beat configured external directories; among external directories, the first `scriptDirs` entry wins. The JSON `source` field is `bundled`, `workspace`, or `external`.

The config file is a small JSON object, currently with an ordered `scriptDirs` array such as `{"scriptDirs": ["/path/one", "/path/two"]}`. `OMARCHY_SCRIPTS_HOME` relocates both this file and the default workspace root together. A configured external directory that is missing, unreadable, or not a directory is reported in `problems` rather than silently skipped. The generic `config get/set/unset <dotted.path>` CLI reads and writes this same file; `add-dir` and `remove-dir` are convenience wrappers over `config set scriptDirs ...`, not a separate storage path.

New scripts are created in the workspace. `delete` removes the discovered file directly; confirmation and recovery policy belong to the caller. Configuration is likewise file-oriented: the CLI can update `config.json`, but the GUI remains a read-only consumer of the merged discovery result and never grows its own settings UI.

## Settings file

User-level `omarchy-scripts` preferences live in `${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}/config.json`, alongside the workspace `scripts/` directory. `OMARCHY_SCRIPTS_HOME` therefore relocates both workspace scripts and the shared settings file together.

The settings file's *contents* are still optional — every key is meaningful missing (falls back to `KEY_ACTION_DEFAULTS`, an empty `scriptDirs`, or no `devSourcePath`) — but the *file itself* is materialized proactively rather than left to spring into existence on first write: `config init` (also called by `omarchy-plugin/install.sh` after installing, and once by the QML plugin on its first successful run after install) writes every `KEY_ACTION_DEFAULTS` entry under `keys` plus an empty `scriptDirs: []` if the file is missing any of them, so `~/.config/omarchy-scripts/config.json` is a real, readable file from the start instead of something a user has to write to before it appears. It never overwrites a value already present — an existing customization always wins over a default being filled in — and is safe to call repeatedly (a plugin update, or opening the menu again, both no-op once nothing is missing).

Today it supports a `keys` object mapping menu actions to plain string key specs, a `scriptDirs` array for additive discovery, and a `devSourcePath` string for development helpers that need a remembered checkout path:

```json
{
  "devSourcePath": "/home/you/Source/omarchy-scripts",
  "keys": {
    "moveUp": "Up",
    "moveDown": "Down",
    "open": "Return",
    "quickRun": "Shift+Return",
    "back": "Escape",
    "reload": "F5",
    "run": "R",
    "edit": "E",
    "delete": "D"
  }
}
```

Key specs are hand-editable `"Modifier+Modifier+Key"` strings rather than QML enums. Supported modifiers are `Ctrl`, `Alt`, `Shift`, `Super`, and `Meta`; common aliases such as `Enter`/`Return` and `Esc`/`Escape` normalize to one canonical form. Precedence is: built-in defaults first, then any valid `config.json` override for that action. Missing or invalid entries fall back to the built-in default so a typo in one key never breaks the menu. The built-in browse/detail defaults intentionally preserve today's secondary navigation companions too: `open` still accepts `Right` when left at its default, and `back` still accepts `Left` when left at its default, so an empty config behaves the same as the pre-remapping menu.

The generic CLI deliberately parses `config set` values as JSON first, then falls back to the raw argv string, so both `config set scriptDirs '["/path/one"]'` and `config set keys.moveDown j` work naturally. Validation still stays engine-owned: `keys.*` values must parse as key specs, `scriptDirs` values use the same path normalization as `add-dir`/`remove-dir`, and `devSourcePath` must be a non-empty string path normalized relative to the caller's current working directory, so the settings file cannot be mutated into a shape discovery or key resolution already rejects.

## JSON contract

Every CLI response is one JSON object whose top-level object starts with `"schemaVersion": 1`. `schemaVersion` versions this machine-readable contract: a frontend must reject a response with a version it does not understand rather than trying to interpret a changed shape. The QML plugin checks that value before using a response.

Successful `list` returns `scripts`, `problems`, the resolved `keys` map, and any non-fatal `settingsProblems`; `info` returns `script`; `run` returns `result`; `last-run` returns `result` (or `null`); `new` returns `path`; `delete` returns `deleted`; and `config` returns `configPath` plus subcommand-specific fields (`init` returns `changed`, `keys`, and `scriptDirs`; the rest return `scriptDirs`, `added`, `removed`, `path`, and/or `value`). Engine request errors are emitted as `error`. Script execution failures still return a result, but `run` exits non-zero. Runs capture stdout, stderr, exit status, duration, and UTC start time in `${OMARCHY_SCRIPTS_STATE:-${XDG_STATE_HOME:-~/.local/state}/omarchy-scripts}/last-run/`.

## Execution

For a declared parameter, the engine supplies `--<name> <value>`. Omitted parameters use their metadata `default` when present; one marked `required=true` otherwise fails. Integer, boolean, and populated choice lists receive the engine's small validation checks. The runner executes `bash <script-path>` for real; there is no built-in dry-run, backup, undo, or action verb. It sets `OMARCHY_SCRIPTS_ROOT` and `OMARCHY_SCRIPTS_LIB` for the script.

## QML runner resolution

At startup, `ScriptEngine.qml` probes candidates with `test -x` and chooses the first executable. If `OMARCHY_SCRIPTS_BIN` is set, it is the complete candidate list (one path) and nothing else is tried. Otherwise the exact order is:

1. `<plugin-dir>/bin/omarchy-scripts` — the installed plugin's runner.
2. `<parent-of-plugin-dir>/bin/omarchy-scripts` — a checkout-adjacent runner.
3. `$HOME/.local/bin/omarchy-scripts` — a user installation.

If no candidate is executable, the plugin reports that it could not find the runner and does not make engine calls.
