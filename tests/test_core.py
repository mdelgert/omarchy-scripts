"""Tests for the discovery/parsing/run engine.

Run with: PYTHONPATH=src python3 -m unittest discover -s tests -v
"""

from __future__ import annotations

import os
import shutil
import tempfile
import unittest
from pathlib import Path

from omarchy_scripts import core


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

    def test_duplicate_id_is_reported_as_a_problem_not_silently_shadowed(self) -> None:
        self._write(self.engine_root / "scripts", "a.sh", SIMPLE_SCRIPT)
        self._write(self.workspace / "scripts", "b.sh", SIMPLE_SCRIPT)
        scripts, problems = core.discover(self.engine_root)
        self.assertEqual([s.id for s in scripts], ["sample-script"])
        self.assertEqual(len(problems), 1)
        self.assertIn("duplicate id", problems[0]["error"])

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


if __name__ == "__main__":
    unittest.main()
