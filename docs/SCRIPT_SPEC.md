# Script Specification (v1)

A v1 script is a Bash file discovered by the engine. Metadata is read from comment lines; it describes the script but is not evaluated. The engine runs a selected script as `bash <path>` and passes declared values as `--name value` argv pairs. There are no required `check`, `apply`, or `undo` commands.

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
read-only consumer of discovered scripts rather than a settings editor.

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
