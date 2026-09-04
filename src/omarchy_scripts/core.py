"""Discover, parse, and run header-comment scripts.

Deliberately small. A script is a plain, directly-runnable bash file; the
engine's only job is to read its header comments, turn declared `@param`
lines into a form a frontend can generate, run the script with those values,
and report what happened.

There is no required action-dispatch protocol (no check/apply/undo) and no
mandatory backup/undo machinery. See docs/VISION.md for why: this project is
the deliberately simpler sibling of omarchy-recipes, and reversibility is out
of scope for v1 on purpose, not by oversight.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# Bumped when the JSON shape changes incompatibly. A frontend should refuse
# output stamped with anything else rather than half-understand it.
SCHEMA_VERSION = 1

META_PREFIX = "@script."
PARAM_PREFIX = "@param"

REQUIRED_KEYS = ("id", "title", "description", "category")
PARAM_TYPES = ("string", "integer", "boolean", "choice", "path")

# Same id shape used elsewhere in the ecosystem: lowercase, kebab-case.
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

DEFAULT_RUN_TIMEOUT = 120
CONFIG_FILENAME = "config.json"

KEY_ACTION_DEFAULTS = {
    "moveUp": "Up",
    "moveDown": "Down",
    "open": "Return",
    "quickRun": "Shift+Return",
    "back": "Escape",
    "reload": "F5",
    "run": "R",
    "edit": "E",
    "delete": "D",
}
KEY_MODIFIER_ALIASES = {
    "alt": "Alt",
    "control": "Ctrl",
    "ctrl": "Ctrl",
    "meta": "Meta",
    "shift": "Shift",
    "super": "Super",
}
KEY_NAME_ALIASES = {
    "backspace": "Backspace",
    "delete": "Delete",
    "down": "Down",
    "end": "End",
    "enter": "Return",
    "esc": "Escape",
    "escape": "Escape",
    "f1": "F1",
    "f2": "F2",
    "f3": "F3",
    "f4": "F4",
    "f5": "F5",
    "f6": "F6",
    "f7": "F7",
    "f8": "F8",
    "f9": "F9",
    "f10": "F10",
    "f11": "F11",
    "f12": "F12",
    "f13": "F13",
    "f14": "F14",
    "f15": "F15",
    "f16": "F16",
    "f17": "F17",
    "f18": "F18",
    "f19": "F19",
    "f20": "F20",
    "f21": "F21",
    "f22": "F22",
    "f23": "F23",
    "f24": "F24",
    "f25": "F25",
    "f26": "F26",
    "f27": "F27",
    "f28": "F28",
    "f29": "F29",
    "f30": "F30",
    "f31": "F31",
    "f32": "F32",
    "f33": "F33",
    "f34": "F34",
    "f35": "F35",
    "home": "Home",
    "left": "Left",
    "pagedown": "PageDown",
    "pageup": "PageUp",
    "return": "Return",
    "right": "Right",
    "space": "Space",
    "tab": "Tab",
    "up": "Up",
}
KEY_MODIFIER_ORDER = ("Ctrl", "Alt", "Shift", "Super", "Meta")

# `@script.icon` is written as a `\uXXXX` escape rather than the literal glyph,
# same convention as omarchy-recipes: a private-use-area character does not
# survive every editor/shell/diff round-trip, and a silently emptied icon
# collapses to blank rather than erroring.
ICON_ESCAPE_RE = re.compile(r"^\\[uU]([0-9A-Fa-f]{4,6})$")

# Fallback glyph per category, kept in the engine (not each frontend) so every
# client draws the same icon without reimplementing the table. Chosen from
# JetBrainsMono Nerd Font, the font Omarchy ships and renders these menus in.
CATEGORY_ICONS = {
    "Diagnostics": "\uf188",   # bug
    "Examples": "\uf0eb",      # lightbulb
    "Networking": "\uf0e8",    # sitemap
    "System": "\uf085",        # gears
    "General": "\uf013",       # cog
}
DEFAULT_ICON = "\uf013"        # cog


def resolve_icon(declared: str | None, category: str) -> str:
    """The glyph to draw for a script: what it declared, or its category's.

    Returns a single character, always. Raises when a declared value cannot
    be one, because an icon that silently renders blank is worse than a
    refusal — the script looks broken and nothing says why.
    """
    raw = (declared or "").strip()
    if not raw:
        return CATEGORY_ICONS.get(category, DEFAULT_ICON)
    match = ICON_ESCAPE_RE.match(raw)
    if match:
        code = int(match.group(1), 16)
        if not (0 < code <= 0x10FFFF):
            raise ValueError(f"{raw} is not a usable codepoint")
        return chr(code)
    # A pasted glyph still works, but the escape is the documented form.
    if len(raw) == 1:
        return raw
    raise ValueError(
        f"expected a single glyph or a \\uXXXX escape such as \\uf085, got {raw!r}")


class ScriptError(RuntimeError):
    """A discovery, validation, or execution problem worth reporting verbatim."""


@dataclass
class Param:
    name: str
    type: str
    attrs: dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {"name": self.name, "type": self.type, **self.attrs}


@dataclass
class Script:
    id: str
    title: str
    description: str
    category: str
    icon: str
    tags: list[str]
    params: list[Param]
    path: str
    source: str  # "bundled" | "workspace" | "external"

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "category": self.category,
            "icon": self.icon,
            "tags": self.tags,
            "params": [p.to_dict() for p in self.params],
            "path": self.path,
            "source": self.source,
        }


@dataclass(frozen=True)
class ParsedKeySpec:
    modifiers: tuple[str, ...]
    key: str

    def to_spec(self) -> str:
        parts = [m for m in KEY_MODIFIER_ORDER if m in self.modifiers]
        parts.append(self.key)
        return "+".join(parts)


def workspace_root() -> Path:
    """User-writable root holding scripts the user added or edited.

    `OMARCHY_SCRIPTS_HOME` relocates it, so tests never read or write the
    developer's own scripts.
    """
    override = os.environ.get("OMARCHY_SCRIPTS_HOME")
    if override:
        return Path(override)
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return base / "omarchy-scripts"


def config_path() -> Path:
    """Settings file storing additive configuration such as extra script dirs."""
    return workspace_root() / CONFIG_FILENAME


def state_root() -> Path:
    """Where last-run output is recorded. Convenience only, never required."""
    override = os.environ.get("OMARCHY_SCRIPTS_STATE")
    if override:
        return Path(override)
    base = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    return base / "omarchy-scripts"


def _normalize_path(value: str, *, relative_to: Path) -> str:
    path = Path(value.strip()).expanduser()
    if not path.is_absolute():
        path = relative_to / path
    return str(path.resolve(strict=False))


def _load_settings() -> dict[str, Any]:
    path = config_path()
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ScriptError(f"{path}: unreadable config: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ScriptError(
            f"{path}: invalid config JSON at line {exc.lineno} column {exc.colno}: {exc.msg}"
        ) from exc
    if not isinstance(data, dict):
        raise ScriptError(f"{path}: config must be a JSON object")
    return data


def _load_settings_file() -> tuple[dict[str, Any], list[str]]:
    """Same settings file as `_load_settings()`, but as a (data, problems)
    pair for callers (key-binding resolution) that want to degrade to
    defaults on a bad file rather than raise."""
    try:
        return _load_settings(), []
    except ScriptError as exc:
        return {}, [str(exc)]


def _configured_dir_strings(settings: dict[str, Any]) -> list[str]:
    raw_dirs = settings.get("scriptDirs", [])
    if raw_dirs is None:
        return []
    if not isinstance(raw_dirs, list) or any(not isinstance(item, str) for item in raw_dirs):
        raise ScriptError(f"{config_path()}: scriptDirs must be a JSON array of strings")
    base = config_path().parent
    return [_normalize_path(item, relative_to=base) for item in raw_dirs if item.strip()]


def configured_script_dirs() -> list[Path]:
    return [Path(path) for path in _configured_dir_strings(_load_settings())]


def list_script_dirs() -> list[str]:
    return _configured_dir_strings(_load_settings())


def _write_settings(settings: dict[str, Any]) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")


def _split_config_key_path(path: str) -> tuple[str, ...]:
    raw = str(path).strip()
    if not raw:
        raise ScriptError("config path must not be empty")
    parts = tuple(piece.strip() for piece in raw.split("."))
    if any(not piece for piece in parts):
        raise ScriptError(f"invalid config path {path!r}: empty segment")
    return parts


def _setting_at_path(settings: dict[str, Any], path: tuple[str, ...]) -> Any:
    current: Any = settings
    for index, piece in enumerate(path):
        if not isinstance(current, dict):
            joined = ".".join(path[:index])
            raise ScriptError(
                f"config path {'.'.join(path)!r} cannot descend into non-object value at {joined!r}"
            )
        if piece not in current:
            return None
        current = current[piece]
    return current


def _validated_setting_value(path: tuple[str, ...], value: Any, *, cwd: Path) -> Any:
    if path == ("scriptDirs",):
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            raise ScriptError("scriptDirs must be a JSON array of strings")
        return [_normalize_path(item, relative_to=cwd) for item in value if item.strip()]

    if path == ("devSourcePath",):
        if not isinstance(value, str) or not value.strip():
            raise ScriptError("devSourcePath must be a non-empty string path")
        return _normalize_path(value, relative_to=cwd)

    if path and path[0] == "keys":
        if len(path) == 1:
            if not isinstance(value, dict):
                raise ScriptError("keys must be a JSON object mapping action names to key specs")
            validated: dict[str, str] = {}
            for action, spec in value.items():
                if not isinstance(action, str):
                    raise ScriptError("keys must use string action names")
                if not isinstance(spec, str):
                    raise ScriptError(f"keys.{action} must be a string key spec")
                parse_key_spec(spec)
                validated[action] = spec
            return validated

        if not isinstance(value, str):
            raise ScriptError(f"{'.'.join(path)} must be a string key spec")
        parse_key_spec(value)
        return value

    return value


def get_config_value(path_value: str) -> Any:
    settings = _load_settings()
    path = _split_config_key_path(path_value)
    if path == ("scriptDirs",):
        return _configured_dir_strings(settings)
    return _setting_at_path(settings, path)


def set_config_value(path_value: str, value: Any, *, cwd: Path | None = None) -> Any:
    settings = _load_settings()
    path = _split_config_key_path(path_value)
    validated = _validated_setting_value(path, value, cwd=cwd or Path.cwd())

    if len(path) == 1:
        settings[path[0]] = validated
    else:
        current: dict[str, Any] = settings
        for piece in path[:-1]:
            next_value = current.get(piece)
            if next_value is None:
                next_value = {}
                current[piece] = next_value
            elif not isinstance(next_value, dict):
                raise ScriptError(
                    f"config path {'.'.join(path)!r} cannot descend into non-object value at {piece!r}"
                )
            current = next_value
        current[path[-1]] = validated

    _write_settings(settings)
    return get_config_value(path_value)


def unset_config_value(path_value: str) -> bool:
    settings = _load_settings()
    path = _split_config_key_path(path_value)

    chain: list[tuple[dict[str, Any], str]] = []
    current: Any = settings
    for piece in path[:-1]:
        if not isinstance(current, dict):
            raise ScriptError(
                f"config path {'.'.join(path)!r} cannot descend into non-object value at {piece!r}"
            )
        next_value = current.get(piece)
        if next_value is None:
            return False
        chain.append((current, piece))
        current = next_value

    if not isinstance(current, dict):
        raise ScriptError(
            f"config path {'.'.join(path)!r} cannot descend into non-object value at {path[-1]!r}"
        )
    if path[-1] not in current:
        return False

    del current[path[-1]]
    for parent, key in reversed(chain):
        child = parent.get(key)
        if isinstance(child, dict) and not child:
            del parent[key]
        else:
            break

    _write_settings(settings)
    return True


def add_script_dir(path_value: str, *, cwd: Path | None = None) -> list[str]:
    script_dirs = list_script_dirs()
    normalized = _normalize_path(path_value, relative_to=cwd or Path.cwd())
    if normalized not in script_dirs:
        script_dirs.append(normalized)
    return set_config_value("scriptDirs", script_dirs, cwd=cwd or Path.cwd())


def remove_script_dir(path_value: str, *, cwd: Path | None = None) -> list[str]:
    normalized = _normalize_path(path_value, relative_to=cwd or Path.cwd())
    script_dirs = [path for path in list_script_dirs() if path != normalized]
    return set_config_value("scriptDirs", script_dirs, cwd=cwd or Path.cwd())


def parse_key_spec(spec: str) -> ParsedKeySpec:
    raw = str(spec).strip()
    if not raw:
        raise ScriptError("key spec must not be empty")

    pieces = [piece.strip() for piece in raw.split("+")]
    if any(not piece for piece in pieces):
        raise ScriptError(f"invalid key spec {spec!r}: empty token")

    modifiers: list[str] = []
    seen_modifiers: set[str] = set()
    for piece in pieces[:-1]:
        modifier = KEY_MODIFIER_ALIASES.get(piece.lower())
        if modifier is None:
            raise ScriptError(f"invalid key spec {spec!r}: unknown modifier {piece!r}")
        if modifier in seen_modifiers:
            raise ScriptError(f"invalid key spec {spec!r}: duplicate modifier {piece!r}")
        seen_modifiers.add(modifier)
        modifiers.append(modifier)

    key_token = pieces[-1]
    key_alias = KEY_NAME_ALIASES.get(key_token.lower())
    if key_alias is not None:
        key = key_alias
    elif len(key_token) == 1 and not key_token.isspace():
        key = key_token.upper() if key_token.isalpha() else key_token
    else:
        raise ScriptError(f"invalid key spec {spec!r}: unknown key {key_token!r}")

    return ParsedKeySpec(modifiers=tuple(modifiers), key=key)


def resolve_key_bindings() -> tuple[dict[str, str], list[str]]:
    settings, problems = _load_settings_file()
    resolved = dict(KEY_ACTION_DEFAULTS)
    raw_keys = settings.get("keys")
    if raw_keys is None:
        return resolved, problems
    if not isinstance(raw_keys, dict):
        return resolved, [
            *problems,
            f"{config_path()}: keys must be a JSON object mapping action names to key specs",
        ]

    extra_problems = list(problems)
    for action, default_spec in KEY_ACTION_DEFAULTS.items():
        raw_spec = raw_keys.get(action)
        if raw_spec is None:
            continue
        if not isinstance(raw_spec, str):
            extra_problems.append(
                f"{config_path()}: keys.{action} must be a string; using default {default_spec}"
            )
            continue
        try:
            resolved[action] = parse_key_spec(raw_spec).to_spec()
        except ScriptError as exc:
            extra_problems.append(f"{config_path()}: {exc}; using default {default_spec}")
    return resolved, extra_problems


def _split_csv(value: str) -> list[str]:
    return [v.strip() for v in value.split(",") if v.strip()]


def _parse_kv(rest: str) -> dict[str, str]:
    """Parse `key=value key="quoted value"` pairs after a metadata/param line.

    Values are kept as plain data, never evaluated or shell-expanded — a
    default like `default="$HOME"` is stored as the literal two characters
    `$H...`, not expanded. A script that wants a runtime default expands it
    itself, in its own shell, e.g. `${SCRIPT_ARG_PATH:-$HOME}`.
    """
    attrs: dict[str, str] = {}
    for token in shlex.split(rest):
        if "=" not in token:
            continue
        key, _, value = token.partition("=")
        attrs[key] = value
    return attrs


def parse_metadata(text: str, path: Path, source: str) -> Script:
    meta: dict[str, str] = {}
    params: list[Param] = []
    seen_params: set[str] = set()

    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("#"):
            continue
        body = stripped[1:].strip()

        if body.startswith(META_PREFIX):
            key, _, value = body[len(META_PREFIX):].partition(" ")
            meta[key.strip()] = value.strip()

        elif body.startswith(PARAM_PREFIX):
            rest = body[len(PARAM_PREFIX):].strip()
            parts = rest.split(None, 2)
            if len(parts) < 2:
                raise ScriptError(f"{path}: malformed @param line: {stripped!r}")
            name, ptype = parts[0], parts[1]
            if ptype not in PARAM_TYPES:
                raise ScriptError(
                    f"{path}: @param {name} has unknown type {ptype!r}; "
                    f"expected one of {', '.join(PARAM_TYPES)}"
                )
            if name in seen_params:
                raise ScriptError(f"{path}: @param {name} declared more than once")
            seen_params.add(name)
            attrs = _parse_kv(parts[2]) if len(parts) > 2 else {}
            params.append(Param(name=name, type=ptype, attrs=attrs))

    missing = [k for k in REQUIRED_KEYS if not meta.get(k)]
    if missing:
        raise ScriptError(
            f"{path}: missing metadata: " + ", ".join(META_PREFIX + m for m in missing)
        )

    script_id = meta["id"]
    if not ID_RE.match(script_id):
        raise ScriptError(f"{path}: @script.id {script_id!r} must be lowercase kebab-case")

    try:
        icon = resolve_icon(meta.get("icon"), meta["category"])
    except ValueError as exc:
        raise ScriptError(f"{path}: invalid @script.icon: {exc}") from exc

    return Script(
        id=script_id,
        title=meta["title"],
        description=meta["description"],
        category=meta["category"],
        icon=icon,
        tags=_split_csv(meta.get("tags", "")),
        params=params,
        path=str(path),
        source=source,
    )


def _bundled_root(engine_root: Path) -> Path:
    return engine_root / "scripts"


def _dir_problem(root: Path) -> str | None:
    if not root.exists():
        return "configured script directory does not exist"
    if not root.is_dir():
        return "configured script directory is not a directory"
    if not os.access(root, os.R_OK | os.X_OK):
        return "configured script directory is not readable"
    return None


def discover(engine_root: Path) -> tuple[list[Script], list[dict[str, Any]]]:
    """Find every script under the bundled, workspace, and configured roots.

    A script that fails to parse is reported in `problems`, never silently
    dropped — a malformed script is the author's bug and staying invisible is
    how it stays unnoticed. An id collision is reported the same way, with
    first scanned script preferred by scan order: bundled, then workspace,
    then configured external directories in the order listed in config.json.
    Any later script claiming an id already taken becomes a problem, not a
    silent shadow.
    """
    scripts: list[Script] = []
    problems: list[dict[str, Any]] = []
    seen: dict[str, Script] = {}

    locations = [
        (_bundled_root(engine_root), "bundled"),
        (workspace_root() / "scripts", "workspace"),
    ]
    try:
        locations.extend((root, "external") for root in configured_script_dirs())
    except ScriptError as exc:
        problems.append({"path": str(config_path()), "error": str(exc)})

    for root, source in locations:
        if source == "external":
            problem = _dir_problem(root)
            if problem:
                problems.append({"path": str(root), "source": source, "error": problem})
                continue
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.sh")):
            try:
                text = path.read_text(encoding="utf-8")
            except OSError as e:
                problems.append({"path": str(path), "error": f"unreadable: {e}"})
                continue
            try:
                script = parse_metadata(text, path, source)
            except ScriptError as e:
                problems.append({"path": str(path), "error": str(e)})
                continue
            existing = seen.get(script.id)
            if existing is not None:
                problems.append({
                    "path": str(path),
                    "error": f"duplicate id {script.id!r}; already provided by {existing.path}",
                })
                continue
            seen[script.id] = script
            scripts.append(script)

    scripts.sort(key=lambda s: (s.category.lower(), s.title.lower()))
    return scripts, problems


def find(engine_root: Path, script_id: str) -> Script:
    scripts, _ = discover(engine_root)
    for s in scripts:
        if s.id == script_id:
            return s
    raise ScriptError(f"unknown script id: {script_id!r}")


def validate_param_value(param: Param, raw: str) -> None:
    if param.type == "integer":
        try:
            int(raw)
        except ValueError:
            raise ScriptError(f"--{param.name} must be an integer, got {raw!r}") from None
    elif param.type == "boolean":
        if raw not in ("true", "false"):
            raise ScriptError(f"--{param.name} must be true or false, got {raw!r}")
    elif param.type == "choice":
        choices = _split_csv(param.attrs.get("choices", ""))
        if choices and raw not in choices:
            raise ScriptError(f"--{param.name} must be one of {choices}, got {raw!r}")


def _build_argv(script: Script, values: dict[str, str]) -> list[str]:
    declared = {p.name for p in script.params}
    unknown = set(values) - declared
    if unknown:
        raise ScriptError(f"{script.id} has no parameter(s) named {sorted(unknown)}")

    argv = ["bash", script.path]
    for param in script.params:
        raw = values.get(param.name)
        if raw is None:
            raw = param.attrs.get("default")
        if raw is None:
            if param.attrs.get("required") == "true":
                raise ScriptError(f"--{param.name} is required")
            continue
        validate_param_value(param, raw)
        argv += [f"--{param.name}", raw]
    return argv


def run(engine_root: Path, script_id: str, values: dict[str, str]) -> dict[str, Any]:
    """Run a script with the given parameter values, capturing its output.

    No dry-run, no backup, no undo: this executes the script for real. A
    script that wants a read-only preview implements that itself (e.g. an
    optional `--check` it defines and documents on its own), the engine does
    not require or assume one.
    """
    script = find(engine_root, script_id)
    argv = _build_argv(script, values)

    env = os.environ.copy()
    env["OMARCHY_SCRIPTS_LIB"] = str(engine_root / "lib")
    env["OMARCHY_SCRIPTS_ROOT"] = str(engine_root)

    started = time.time()
    try:
        proc = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            env=env,
            timeout=int(os.environ.get("OMARCHY_SCRIPTS_RUN_TIMEOUT", str(DEFAULT_RUN_TIMEOUT))),
        )
        exit_code = proc.returncode
        stdout, stderr = proc.stdout, proc.stderr
    except subprocess.TimeoutExpired as e:
        exit_code = 124
        stdout = e.stdout or ""
        stderr = (e.stderr or "") + "\n[omarchy-scripts] timed out"

    duration = time.time() - started
    result = {
        "script_id": script_id,
        "exit_code": exit_code,
        "success": exit_code == 0,
        "stdout": stdout,
        "stderr": stderr,
        "duration_seconds": round(duration, 3),
        "ran_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(started)),
    }
    _record_last_run(script_id, result)
    return result


def _record_last_run(script_id: str, result: dict[str, Any]) -> None:
    root = state_root() / "last-run"
    root.mkdir(parents=True, exist_ok=True)
    (root / f"{script_id}.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


def last_run(script_id: str) -> dict[str, Any] | None:
    path = state_root() / "last-run" / f"{script_id}.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def delete(engine_root: Path, script_id: str) -> str:
    """Delete a script's file. No confirmation, no recovery — the caller
    (CLI or GUI) owns confirming with the user before calling this."""
    script = find(engine_root, script_id)
    Path(script.path).unlink()
    return script.path


NEW_SCRIPT_TEMPLATE = """#!/usr/bin/env bash
# @script.id {id}
# @script.title New script
# @script.description Describe what this does.
# @script.category {category}
# @script.icon \\uf120
set -euo pipefail

echo "Hello from {id}. Edit this file to make it do something real."
"""


def create(category: str = "general") -> str:
    """Scaffold a new, editable script in the workspace and return its path.

    Deliberately minimal: one placeholder id/title the user renames while
    editing, not a naming form. There is no template registry to keep in
    sync — one string, one file. The caller is expected to open the
    returned path in an editor immediately.
    """
    root = workspace_root() / "scripts"
    root.mkdir(parents=True, exist_ok=True)
    n = 1
    while True:
        script_id = f"new-script-{n}"
        path = root / f"{script_id}.sh"
        if not path.exists():
            break
        n += 1
    path.write_text(
        NEW_SCRIPT_TEMPLATE.format(id=script_id, category=category), encoding="utf-8"
    )
    path.chmod(0o755)
    return str(path)
