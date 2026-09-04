# Architecture

## Boundaries

```text
bundled scripts/ + workspace scripts/
                 |
          Python engine
        /                 \\
JSON CLI              JSON-consuming QML plugin
```

The Python engine in `src/omarchy_scripts/` is the single source of truth for script discovery, header metadata parsing, parameter validation, execution, last-run recording, creation, and deletion. It has no QML or Omarchy UI dependency.

`bin/omarchy-scripts` locates the repository-relative `src/`, `lib/`, and `scripts/` directories, then launches the CLI. The CLI is a thin JSON interface over the engine: `list`, `info`, `run`, `last-run`, `edit`, `new`, `delete`, and `validate`. `edit` replaces the CLI process with `$EDITOR` (falling back to `vi`); the QML frontend uses Omarchy's editor launcher for the same file-oriented action.

The plugin under `omarchy-plugin/` is likewise a consumer. `ScriptEngine.qml` never reads a script file, parses comments, or validates values; it calls the runner and presents its JSON. QML uses argv arrays for processes, and Python uses `subprocess.run()` with an argv list. Neither layer turns metadata or a parameter into executable shell text.

## Discovery and ownership

Discovery scans two roots, in this order:

1. `<engine-root>/scripts` — bundled scripts shipped with the checkout or installed plugin.
2. `${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}/scripts` — the user's workspace scripts.

Only `*.sh` files are considered. Malformed or unreadable files are returned as `problems`, so one bad script does not hide the others. A duplicate ID is also a problem: because bundled scripts are scanned first, a colliding workspace script is rejected rather than silently overriding the bundled one. The JSON `source` field is either `bundled` or `workspace`.

New scripts are created in the workspace. `delete` removes the discovered file directly; confirmation and recovery policy belong to the caller.

## Settings file

User-level `omarchy-scripts` preferences live in `${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}/config.json`, alongside the workspace `scripts/` directory. `OMARCHY_SCRIPTS_HOME` therefore relocates both workspace scripts and the shared settings file together.

The settings file is optional. Today it supports a `keys` object mapping menu actions to plain string key specs:

```json
{
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

## JSON contract

Every CLI response is one JSON object whose top-level object starts with `"schemaVersion": 1`. `schemaVersion` versions this machine-readable contract: a frontend must reject a response with a version it does not understand rather than trying to interpret a changed shape. The QML plugin checks that value before using a response.

Successful `list` returns `scripts`, `problems`, the resolved `keys` map, and any non-fatal `settingsProblems`; `info` returns `script`; `run` returns `result`; `last-run` returns `result` (or `null`); `new` returns `path`; and `delete` returns `deleted`. Engine request errors are emitted as `error`. Script execution failures still return a result, but `run` exits non-zero. Runs capture stdout, stderr, exit status, duration, and UTC start time in `${OMARCHY_SCRIPTS_STATE:-${XDG_STATE_HOME:-~/.local/state}/omarchy-scripts}/last-run/`.

## Execution

For a declared parameter, the engine supplies `--<name> <value>`. Omitted parameters use their metadata `default` when present; one marked `required=true` otherwise fails. Integer, boolean, and populated choice lists receive the engine's small validation checks. The runner executes `bash <script-path>` for real; there is no built-in dry-run, backup, undo, or action verb. It sets `OMARCHY_SCRIPTS_ROOT` and `OMARCHY_SCRIPTS_LIB` for the script.

## QML runner resolution

At startup, `ScriptEngine.qml` probes candidates with `test -x` and chooses the first executable. If `OMARCHY_SCRIPTS_BIN` is set, it is the complete candidate list (one path) and nothing else is tried. Otherwise the exact order is:

1. `<plugin-dir>/bin/omarchy-scripts` — the installed plugin's runner.
2. `<parent-of-plugin-dir>/bin/omarchy-scripts` — a checkout-adjacent runner.
3. `$HOME/.local/bin/omarchy-scripts` — a user installation.

If no candidate is executable, the plugin reports that it could not find the runner and does not make engine calls.
