# Script Specification (v1)

A v1 script is a Bash file discovered by the engine. Metadata is read from comment lines; it describes the script but is not evaluated. The engine runs a selected script as `bash <path>` and passes declared values as `--name value` argv pairs. There are no required `check`, `apply`, or `undo` commands.

`omarchy-scripts copy <id> <new-id>` duplicates an existing script's file into the workspace under a new, unique id (validated the same kebab-case shape and cross-discovery uniqueness every `@script.id` already requires), rewriting only the copy's `@script.id` (and `@script.title`, appending " (copy)") lines — see `docs/ARCHITECTURE.md`'s CLI command list for the full command set.

## Metadata

All required fields must have a non-empty value:

```bash
# @script.id unique-kebab-case-id
# @script.title Human-readable title
# @script.description One-line description
# @script.category Category name
```

`id` must match `^[a-z0-9]+(-[a-z0-9]+)*$`: lowercase letters and digits, with single hyphens only between non-empty components. IDs are unique across discovery; a later duplicate is reported as a problem.

The optional supported field is `tags`, a comma-separated list. Whitespace around each tag is removed and empty entries are omitted:

```bash
# @script.tags network, diagnostics
```

The parser reads comment lines anywhere in the file, not only a contiguous opening header. It recognizes a line after `#` and surrounding whitespace begins with `@script.`; each metadata value is the text after its key's first space, with surrounding whitespace removed. If a key appears more than once, the last value wins. Unknown `@script.*` keys are retained while parsing but are not part of the normalized v1 output.

## Parameters

Declare one parameter per comment line:

```text
@param <name> <type> [key=value | key="quoted value" ...]
```

For example:

```bash
# @param count integer default=10 min=1 max=50 label="How many to show"
```

The five accepted types are `string`, `integer`, `boolean`, `choice`, and `path`. Parameter names must be unique within a script. The current parser does not impose an additional name regex; authors should choose names that are sensible long-option names because the runner emits `--<name>`.

Attributes are whitespace-separated `key=value` pairs parsed with Python's `shlex.split`. Quotes group a value containing spaces and are removed; unknown attributes are preserved in the JSON parameter object. A token without `=` is ignored. The engine currently interprets only these attributes:

- `default=<value>` supplies a value when the caller omits this parameter.
- `required=true` rejects an omitted parameter when no default exists.
- `choices=a,b,c` limits a `choice` value when the list is non-empty.

For an `integer`, the engine requires a value accepted by Python `int()`. For a `boolean`, it requires exactly `true` or `false`. `min`, `max`, `label`, and other attributes are emitted for a frontend but are not enforced by the v1 engine.

`placeholder=<value>` is one such frontend-only attribute: the QML menu shows it as greyed-out hint text inside an empty string field, purely cosmetic. Unlike `default=`, a `placeholder=` value is never part of what gets submitted when the field is left blank — use it to show a script's built-in default (or an example value) without it being silently applied on Run, which matters for a param whose own script logic treats "blank" as "leave unchanged" (see `scripts/examples/configure-omarchy-scripts.sh`).

### Attribute values are data, not shell

Attribute values, including `default=`, are never shell-expanded. For example, `default="$HOME"` becomes the literal string `$HOME`; it does not become the user's home directory. When a default needs runtime shell behavior, the script must implement it itself after parsing argv:

```bash
target="${SCRIPT_ARG_PATH:-$HOME}"
```

## Discovery configuration

The engine always scans its bundled `scripts/` directory plus the default
workspace directory at
`${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}/scripts`.
Users may add more local script roots with the JSON settings file at
`${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}/config.json`:

```json
{
  "scriptDirs": [
    "/path/one",
    "/path/two"
  ]
}
```

Those configured directories are additive only: they do not replace the
bundled or default workspace roots. Discovery precedence is scan order:
bundled first, workspace second, then each `scriptDirs` entry in the listed
order. The first script claiming an id wins; later collisions are reported as
problems. The CLI convenience commands `omarchy-scripts config list-dirs`,
`add-dir`, and `remove-dir` edit the same file, while the GUI remains a
read-only consumer of discovered scripts rather than a settings editor. See
"Settings file CLI" below for `config init`, which materializes this file
with its defaults rather than leaving it to spring into existence on first
write.

## Settings file CLI

The same `config.json` file is also exposed through generic scripting
commands:

```bash
omarchy-scripts config init          # materialize/fill in defaults; safe to re-run
omarchy-scripts config get <dotted.path>
omarchy-scripts config set <dotted.path> <value>
omarchy-scripts config unset <dotted.path>
```

`config init` writes a fully-populated `config.json` — every `keys.<action>`
default plus an empty `scriptDirs: []` — the first time it runs, and only
fills in whatever is still missing on later runs; it never overwrites a
value already present. Both `omarchy-plugin/install.sh` and the QML plugin's
first successful run after install call it, so the file is discoverable
without the user having to change a setting first. `config set` parses
`<value>` as JSON first and falls back to the raw string when JSON parsing
fails, so both of these work:

```bash
omarchy-scripts config set scriptDirs '["/path/one", "/path/two"]'
omarchy-scripts config set keys.moveDown j
```

Today the documented settings schema is:

- `scriptDirs`: JSON array of strings. The generic setter normalizes each path
  the same way `config add-dir`/`remove-dir` do, and those older commands are
  now just convenience wrappers for the same underlying read/write mechanism.
- `devSourcePath`: string path to a source checkout used by development helper
  scripts such as `reinstall-from-source`. The generic setter normalizes it to
  an absolute path relative to the caller's current working directory.
- `keys`: JSON object whose values are string key specs. A dotted path such as
  `keys.moveDown` targets one action override. Key specs use the same
  `"Modifier+Modifier+Key"` syntax and validation described by
  `docs/ARCHITECTURE.md`; invalid values are rejected and not written.

Unknown top-level config keys may still exist for forward compatibility, but
only `scriptDirs`, `devSourcePath`, and `keys` are part of the documented v1
schema today.

## Worked examples

### `greet-user.sh`

```bash
# @script.id greet-user
# @script.title Greet a user
# @script.description Minimal example showing how declared parameters arrive as shell variables.
# @script.category Examples
# @script.tags example
# @param name string required=true default=friend label="Name to greet"
# @param shout boolean default=false label="ALL CAPS"
```

The engine can invoke it as `bash …/greet-user.sh --name Ada --shout true`. It sources `lib/scripts.sh`, whose optional `script_parse_args "$@"` helper maps those arguments to `SCRIPT_ARG_NAME` and `SCRIPT_ARG_SHOUT`.

### `hostname-info.sh`

```bash
# @script.id hostname-info
# @script.title Hostname & network info
# @script.description Prints hostname, IP addresses, default route, and DNS resolvers.
# @script.category Diagnostics
# @script.tags network,diagnostics
```

It has no parameters and simply prints diagnostics. This is the intended v1 shape for a useful script with no reversible state or generated form.

### `largest-directories.sh`

```bash
# @script.id largest-directories
# @script.title Largest directories
# @script.description Lists the N largest directories under a given path.
# @script.category Diagnostics
# @script.tags disk,diagnostics
# @param path path label="Directory to scan (default: your home directory)"
# @param count integer default=10 min=1 max=50 label="How many to show"
```

`count` gets a literal metadata default of `10`. `path` intentionally has no metadata default: the script uses `${SCRIPT_ARG_PATH:-$HOME}` so `$HOME` is expanded by Bash at run time rather than by the metadata parser.
