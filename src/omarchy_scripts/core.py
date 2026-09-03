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
    tags: list[str]
    params: list[Param]
    path: str
    source: str  # "bundled" | "workspace"

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "category": self.category,
            "tags": self.tags,
            "params": [p.to_dict() for p in self.params],
            "path": self.path,
            "source": self.source,
        }


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


def state_root() -> Path:
    """Where last-run output is recorded. Convenience only, never required."""
    override = os.environ.get("OMARCHY_SCRIPTS_STATE")
    if override:
        return Path(override)
    base = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    return base / "omarchy-scripts"


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

    return Script(
        id=script_id,
        title=meta["title"],
        description=meta["description"],
        category=meta["category"],
        tags=_split_csv(meta.get("tags", "")),
        params=params,
        path=str(path),
        source=source,
    )


def _bundled_root(engine_root: Path) -> Path:
    return engine_root / "scripts"


def discover(engine_root: Path) -> tuple[list[Script], list[dict[str, Any]]]:
    """Find every script under the bundled and workspace roots.

    A script that fails to parse is reported in `problems`, never silently
    dropped — a malformed script is the author's bug and staying invisible is
    how it stays unnoticed. An id collision is reported the same way, with
    bundled scripts implicitly preferred simply by being scanned first: the
    second script claiming an id already taken becomes a problem, not a
    silent shadow.
    """
    scripts: list[Script] = []
    problems: list[dict[str, Any]] = []
    seen: dict[str, Script] = {}

    locations = [
        (_bundled_root(engine_root), "bundled"),
        (workspace_root() / "scripts", "workspace"),
    ]
    for root, source in locations:
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
