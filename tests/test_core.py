"""Tests for the discovery/parsing/run engine.

Run with: PYTHONPATH=src python3 -m unittest discover -s tests -v
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

from omarchy_scripts import cli, core


SIMPLE_SCRIPT = """#!/usr/bin/env bash
# @script.id sample-script
# @script.title Sample script
# @script.description A script used only by tests.
# @script.category Testing
# @script.tags test,sample
# @param name string default=world label="Name"
echo "hello ${1:-}"
"""


class TestParsing(unittest.TestCase):
    def test_parses_required_metadata_and_param(self) -> None:
        script = core.parse_metadata(SIMPLE_SCRIPT, Path("/tmp/sample.sh"), "bundled")
        self.assertEqual(script.id, "sample-script")
        self.assertEqual(script.title, "Sample script")
        self.assertEqual(script.category, "Testing")
        self.assertEqual(script.tags, ["test", "sample"])
        self.assertEqual(len(script.params), 1)
        self.assertEqual(script.params[0].name, "name")
        self.assertEqual(script.params[0].type, "string")
        self.assertEqual(script.params[0].attrs.get("default"), "world")

    def test_missing_required_metadata_raises(self) -> None:
        text = "#!/usr/bin/env bash\n# @script.id only-id\necho hi\n"
        with self.assertRaises(core.ScriptError):
            core.parse_metadata(text, Path("/tmp/bad.sh"), "bundled")

    def test_bad_id_shape_raises(self) -> None:
        text = (
            "#!/usr/bin/env bash\n"
            "# @script.id Not_Kebab\n"
            "# @script.title T\n"
            "# @script.description D\n"
            "# @script.category C\n"
        )
        with self.assertRaises(core.ScriptError):
            core.parse_metadata(text, Path("/tmp/bad-id.sh"), "bundled")

    def test_unknown_param_type_raises(self) -> None:
        text = (
            "#!/usr/bin/env bash\n"
            "# @script.id x\n# @script.title T\n"
            "# @script.description D\n# @script.category C\n"
            "# @param thing secret\n"
        )
        with self.assertRaises(core.ScriptError):
            core.parse_metadata(text, Path("/tmp/bad-param.sh"), "bundled")

    def test_default_stays_a_literal_string(self) -> None:
        text = (
            "#!/usr/bin/env bash\n"
            "# @script.id x\n# @script.title T\n"
            "# @script.description D\n# @script.category C\n"
            '# @param path path default="$HOME"\n'
        )
        script = core.parse_metadata(text, Path("/tmp/literal.sh"), "bundled")
        self.assertEqual(script.params[0].attrs.get("default"), "$HOME")


class TestDiscoveryAndRun(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.engine_root = self.tmp / "engine"
        (self.engine_root / "scripts").mkdir(parents=True)
        (self.engine_root / "lib").mkdir(parents=True)
        shutil.copy(
            Path(__file__).resolve().parents[1] / "lib" / "scripts.sh",
            self.engine_root / "lib" / "scripts.sh",
        )
        self.workspace = self.tmp / "workspace"
        self._old_home = os.environ.get("OMARCHY_SCRIPTS_HOME")
        self._old_state = os.environ.get("OMARCHY_SCRIPTS_STATE")
        os.environ["OMARCHY_SCRIPTS_HOME"] = str(self.workspace)
        os.environ["OMARCHY_SCRIPTS_STATE"] = str(self.tmp / "state")

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)
        for key, value in (("OMARCHY_SCRIPTS_HOME", self._old_home),
                            ("OMARCHY_SCRIPTS_STATE", self._old_state)):
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value

    def _write(self, root: Path, name: str, text: str) -> Path:
        root.mkdir(parents=True, exist_ok=True)
        path = root / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_discover_finds_bundled_script(self) -> None:
        self._write(self.engine_root / "scripts", "a.sh", SIMPLE_SCRIPT)
        scripts, problems = core.discover(self.engine_root)
        self.assertEqual(problems, [])
        self.assertEqual([s.id for s in scripts], ["sample-script"])
        self.assertEqual(scripts[0].source, "bundled")

    def test_workspace_script_is_discovered_too(self) -> None:
        self._write(self.engine_root / "scripts", "a.sh", SIMPLE_SCRIPT)
        other = SIMPLE_SCRIPT.replace("sample-script", "other-script")
        self._write(self.workspace / "scripts", "b.sh", other)
        scripts, problems = core.discover(self.engine_root)
        self.assertEqual(problems, [])
        self.assertEqual(sorted(s.id for s in scripts), ["other-script", "sample-script"])
        self.assertEqual({s.id: s.source for s in scripts}["other-script"], "workspace")

    def test_external_script_directory_is_discovered_and_tagged(self) -> None:
        extra = self.tmp / "shared-scripts"
        external = SIMPLE_SCRIPT.replace("sample-script", "external-script")
        external = external.replace("Sample script", "External script")
        core.add_script_dir(str(extra))
        self._write(extra, "external.sh", external)
        scripts, problems = core.discover(self.engine_root)
        self.assertEqual(problems, [])
        self.assertEqual({s.id: s.source for s in scripts}["external-script"], "external")

    def test_duplicate_id_is_reported_as_a_problem_not_silently_shadowed(self) -> None:
        self._write(self.engine_root / "scripts", "a.sh", SIMPLE_SCRIPT)
        self._write(self.workspace / "scripts", "b.sh", SIMPLE_SCRIPT)
        scripts, problems = core.discover(self.engine_root)
        self.assertEqual([s.id for s in scripts], ["sample-script"])
        self.assertEqual(len(problems), 1)
        self.assertIn("duplicate id", problems[0]["error"])

    def test_workspace_wins_before_external_for_duplicate_ids(self) -> None:
        workspace_script = SIMPLE_SCRIPT.replace("Sample script", "Workspace script")
        self._write(self.workspace / "scripts", "a.sh", workspace_script)
        extra = self.tmp / "shared-scripts"
        core.add_script_dir(str(extra))
        self._write(extra, "b.sh", SIMPLE_SCRIPT)
        scripts, problems = core.discover(self.engine_root)
        self.assertEqual([s.id for s in scripts], ["sample-script"])
        self.assertEqual(scripts[0].source, "workspace")
        self.assertEqual(len(problems), 1)
        self.assertIn(str(self.workspace / "scripts" / "a.sh"), problems[0]["error"])

    def test_external_directory_order_decides_duplicate_precedence(self) -> None:
        first = self.tmp / "team-one"
        second = self.tmp / "team-two"
        first_script = SIMPLE_SCRIPT.replace("Sample script", "First external")
        second_script = SIMPLE_SCRIPT.replace("Sample script", "Second external")
        core.add_script_dir(str(first))
        core.add_script_dir(str(second))
        self._write(first, "a.sh", first_script)
        self._write(second, "b.sh", second_script)
        scripts, problems = core.discover(self.engine_root)
        self.assertEqual([s.id for s in scripts], ["sample-script"])
        self.assertEqual(scripts[0].path, str(first / "a.sh"))
        self.assertEqual(len(problems), 1)
        self.assertIn(str(first / "a.sh"), problems[0]["error"])

    def test_missing_external_directory_is_reported_as_a_problem(self) -> None:
        missing = self.tmp / "missing-shared-scripts"
        core.add_script_dir(str(missing))
        scripts, problems = core.discover(self.engine_root)
        self.assertEqual(scripts, [])
        self.assertEqual(len(problems), 1)
        self.assertEqual(problems[0]["path"], str(missing))
        self.assertEqual(problems[0]["source"], "external")
        self.assertIn("does not exist", problems[0]["error"])

    def test_run_executes_script_and_records_last_run(self) -> None:
        self._write(self.engine_root / "scripts", "a.sh", SIMPLE_SCRIPT)
        result = core.run(self.engine_root, "sample-script", {"name": "tester"})
        self.assertTrue(result["success"])
        self.assertIn("hello", result["stdout"])
        recorded = core.last_run("sample-script")
        self.assertEqual(recorded["script_id"], "sample-script")

    def test_run_rejects_unknown_param(self) -> None:
        self._write(self.engine_root / "scripts", "a.sh", SIMPLE_SCRIPT)
        with self.assertRaises(core.ScriptError):
            core.run(self.engine_root, "sample-script", {"nope": "x"})

    def test_delete_removes_the_file(self) -> None:
        path = self._write(self.engine_root / "scripts", "a.sh", SIMPLE_SCRIPT)
        core.delete(self.engine_root, "sample-script")
        self.assertFalse(path.exists())


class TestCliConfig(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.engine_root = self.tmp / "engine"
        (self.engine_root / "scripts").mkdir(parents=True)
        self.workspace = self.tmp / "workspace"
        self._old_home = os.environ.get("OMARCHY_SCRIPTS_HOME")
        self._old_root = os.environ.get("OMARCHY_SCRIPTS_ROOT")
        os.environ["OMARCHY_SCRIPTS_HOME"] = str(self.workspace)
        os.environ["OMARCHY_SCRIPTS_ROOT"] = str(self.engine_root)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)
        for key, value in (("OMARCHY_SCRIPTS_HOME", self._old_home),
                            ("OMARCHY_SCRIPTS_ROOT", self._old_root)):
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value

    def _run_cli(self, argv: list[str]) -> tuple[int, dict[str, object], str]:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = cli.main(argv)
        return code, json.loads(stdout.getvalue()), stderr.getvalue()

    def test_config_add_list_and_remove_dir(self) -> None:
        extra = self.tmp / "shared"
        expected = str(extra.resolve())

        code, added, stderr = self._run_cli(["config", "add-dir", str(extra)])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(added["added"], expected)
        self.assertEqual(added["scriptDirs"], [expected])
        self.assertEqual(added["configPath"], str(self.workspace / "config.json"))
        self.assertEqual(
            json.loads(core.config_path().read_text(encoding="utf-8")),
            {"scriptDirs": [expected]},
        )

        code, listed, stderr = self._run_cli(["config", "list-dirs"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(listed["scriptDirs"], [expected])

        code, removed, stderr = self._run_cli(["config", "remove-dir", str(extra)])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(removed["removed"], expected)
        self.assertEqual(removed["scriptDirs"], [])
        self.assertEqual(
            json.loads(core.config_path().read_text(encoding="utf-8")),
            {"scriptDirs": []},
        )


if __name__ == "__main__":
    unittest.main()
