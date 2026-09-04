"""CLI for omarchy-scripts.

Every command prints one JSON object to stdout, stamped with `schemaVersion`,
so the GUI plugin and a human at a terminal read exactly the same contract.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from . import core


def engine_root() -> Path:
    override = os.environ.get("OMARCHY_SCRIPTS_ROOT")
    if override:
        return Path(override)
    # src/omarchy_scripts/cli.py -> repo root is two levels up from src/.
    return Path(__file__).resolve().parents[2]


def _emit(data: dict) -> None:
    print(json.dumps({"schemaVersion": core.SCHEMA_VERSION, **data}, indent=2))


def _parse_config_value(raw: str) -> object:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="omarchy-scripts")
    sub = p.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="list discovered scripts")

    ip = sub.add_parser("info", help="show metadata for one script")
    ip.add_argument("id")

    rp = sub.add_parser("run", help="run a script")
    rp.add_argument("id")
    rp.add_argument("--param", action="append", default=[], metavar="name=value",
                     help="repeatable: --param name=value")
    rp.add_argument("--raw", action="store_true",
                     help="print the script's own stdout/stderr instead of a JSON envelope "
                          "(for a real terminal, not the GUI)")

    lp = sub.add_parser("last-run", help="show the captured output of the most recent run")
    lp.add_argument("id")

    ep = sub.add_parser("edit", help="open a script's file in $EDITOR")
    ep.add_argument("id")

    np = sub.add_parser("new", help="scaffold a new script in the workspace")
    np.add_argument("--category", default="general")

    dp = sub.add_parser("delete", help="delete a script's file")
    dp.add_argument("id")

    cop = sub.add_parser("copy", help="duplicate a script into the workspace under a new id")
    cop.add_argument("id")
    cop.add_argument("new_id")

    sub.add_parser("validate", help="parse every script and report metadata problems")

    cp = sub.add_parser("config", help="manage settings")
    csub = cp.add_subparsers(dest="config_command", required=True)
    csub.add_parser("init", help="materialize a fully-populated config.json (existing values win)")
    csub.add_parser("list-dirs", help="list configured external script directories")
    ap = csub.add_parser("add-dir", help="add a configured external script directory")
    ap.add_argument("path")
    rp = csub.add_parser("remove-dir", help="remove a configured external script directory")
    rp.add_argument("path")
    gp = csub.add_parser("get", help="get a config value")
    gp.add_argument("path")
    sp = csub.add_parser("set", help="set a config value")
    sp.add_argument("path")
    sp.add_argument("value")
    up = csub.add_parser("unset", help="remove a config value")
    up.add_argument("path")

    return p


def _parse_params(pairs: list[str]) -> dict[str, str]:
    values: dict[str, str] = {}
    for pair in pairs:
        if "=" not in pair:
            raise core.ScriptError(f"--param must be name=value, got {pair!r}")
        name, _, value = pair.partition("=")
        values[name] = value
    return values


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = engine_root()

    try:
        if args.command == "list":
            scripts, problems = core.discover(root)
            keys, settings_problems = core.resolve_key_bindings()
            _emit({
                "scripts": [s.to_dict() for s in scripts],
                "problems": problems,
                "keys": keys,
                "settingsProblems": settings_problems,
            })
            return 0

        if args.command == "info":
            script = core.find(root, args.id)
            _emit({"script": script.to_dict()})
            return 0

        if args.command == "run":
            values = _parse_params(args.param)
            result = core.run(root, args.id, values)
            if args.raw:
                sys.stdout.write(result["stdout"])
                sys.stderr.write(result["stderr"])
                return result["exit_code"]
            _emit({"result": result})
            return 0 if result["success"] else 1

        if args.command == "last-run":
            result = core.last_run(args.id)
            _emit({"result": result})
            return 0 if result else 1

        if args.command == "edit":
            script = core.find(root, args.id)
            editor = os.environ.get("EDITOR", "vi")
            os.execvp(editor, [editor, script.path])
            return 0  # unreachable; execvp replaces this process

        if args.command == "new":
            path = core.create(args.category)
            _emit({"path": path})
            return 0

        if args.command == "delete":
            path = core.delete(root, args.id)
            _emit({"deleted": path})
            return 0

        if args.command == "copy":
            path = core.duplicate(root, args.id, args.new_id)
            _emit({"path": path})
            return 0

        if args.command == "validate":
            scripts, problems = core.discover(root)
            _emit({"scripts": len(scripts), "problems": problems})
            return 1 if problems else 0

        if args.command == "config":
            if args.config_command == "init":
                settings, changed = core.materialize_default_config()
                _emit({
                    "configPath": str(core.config_path()),
                    "changed": changed,
                    "keys": settings.get("keys", {}),
                    "scriptDirs": core.list_script_dirs(),
                })
                return 0

            if args.config_command == "list-dirs":
                _emit({
                    "configPath": str(core.config_path()),
                    "scriptDirs": core.list_script_dirs(),
                })
                return 0

            if args.config_command == "add-dir":
                script_dirs = core.add_script_dir(args.path)
                _emit({
                    "configPath": str(core.config_path()),
                    "added": core._normalize_path(args.path, relative_to=Path.cwd()),
                    "scriptDirs": script_dirs,
                })
                return 0

            if args.config_command == "remove-dir":
                removed = core._normalize_path(args.path, relative_to=Path.cwd())
                script_dirs = core.remove_script_dir(args.path)
                _emit({
                    "configPath": str(core.config_path()),
                    "removed": removed,
                    "scriptDirs": script_dirs,
                })
                return 0

            if args.config_command == "get":
                _emit({
                    "configPath": str(core.config_path()),
                    "path": args.path,
                    "value": core.get_config_value(args.path),
                })
                return 0

            if args.config_command == "set":
                _emit({
                    "configPath": str(core.config_path()),
                    "path": args.path,
                    "value": core.set_config_value(
                        args.path,
                        _parse_config_value(args.value),
                        cwd=Path.cwd(),
                    ),
                })
                return 0

            if args.config_command == "unset":
                _emit({
                    "configPath": str(core.config_path()),
                    "path": args.path,
                    "removed": core.unset_config_value(args.path),
                })
                return 0

    except core.ScriptError as e:
        _emit({"error": str(e)})
        print(str(e), file=sys.stderr)
        return 2

    return 2


if __name__ == "__main__":
    sys.exit(main())
