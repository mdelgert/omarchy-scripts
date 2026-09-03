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

    lp = sub.add_parser("last-run", help="show the captured output of the most recent run")
    lp.add_argument("id")

    ep = sub.add_parser("edit", help="open a script's file in $EDITOR")
    ep.add_argument("id")

    dp = sub.add_parser("delete", help="delete a script's file")
    dp.add_argument("id")

    sub.add_parser("validate", help="parse every script and report metadata problems")

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
            _emit({"scripts": [s.to_dict() for s in scripts], "problems": problems})
            return 0

        if args.command == "info":
            script = core.find(root, args.id)
            _emit({"script": script.to_dict()})
            return 0

        if args.command == "run":
            values = _parse_params(args.param)
            result = core.run(root, args.id, values)
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

        if args.command == "delete":
            path = core.delete(root, args.id)
            _emit({"deleted": path})
            return 0

        if args.command == "validate":
            scripts, problems = core.discover(root)
            _emit({"scripts": len(scripts), "problems": problems})
            return 1 if problems else 0

    except core.ScriptError as e:
        _emit({"error": str(e)})
        print(str(e), file=sys.stderr)
        return 2

    return 2


if __name__ == "__main__":
    sys.exit(main())
