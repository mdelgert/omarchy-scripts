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

    def test_parse_key_spec_accepts_modifiers_and_aliases(self) -> None:
        parsed = core.parse_key_spec("ctrl+shift+enter")
        self.assertEqual(parsed.modifiers, ("Ctrl", "Shift"))
        self.assertEqual(parsed.key, "Return")
        self.assertEqual(parsed.to_spec(), "Ctrl+Shift+Return")

    def test_parse_key_spec_accepts_single_letter(self) -> None:
        parsed = core.parse_key_spec("j")
        self.assertEqual(parsed.modifiers, ())
        self.assertEqual(parsed.key, "J")
        self.assertEqual(parsed.to_spec(), "J")

    def test_parse_key_spec_rejects_unknown_modifier(self) -> None:
        with self.assertRaises(core.ScriptError):
            core.parse_key_spec("Hyper+J")


class TestBundledConfigureScript(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.repo_root = Path(__file__).resolve().parents[1]
        self.workspace = self.tmp / "workspace"
        self.state = self.tmp / "state"
        self._old_home = os.environ.get("OMARCHY_SCRIPTS_HOME")
        self._old_state = os.environ.get("OMARCHY_SCRIPTS_STATE")
        self._old_root = os.environ.get("OMARCHY_SCRIPTS_ROOT")
        os.environ["OMARCHY_SCRIPTS_HOME"] = str(self.workspace)
        os.environ["OMARCHY_SCRIPTS_STATE"] = str(self.state)
        os.environ["OMARCHY_SCRIPTS_ROOT"] = str(self.repo_root)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)
        for key, value in (
            ("OMARCHY_SCRIPTS_HOME", self._old_home),
            ("OMARCHY_SCRIPTS_STATE", self._old_state),
            ("OMARCHY_SCRIPTS_ROOT", self._old_root),
        ):
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

    def _run_script(self, values: dict[str, str]) -> dict[str, object]:
        result = core.run(self.repo_root, "configure-omarchy-scripts", values)
        self.assertTrue(result["success"], msg=result["stderr"])
        return result

    def test_configure_script_metadata_and_cli_visibility(self) -> None:
        path = self.repo_root / "scripts" / "examples" / "configure-omarchy-scripts.sh"
        script = core.parse_metadata(path.read_text(encoding="utf-8"), path, "bundled")
        self.assertEqual(script.id, "configure-omarchy-scripts")
        self.assertEqual(
            [param.name for param in script.params],
            [
                "scriptDirs",
                "moveUp",
                "moveDown",
                "open",
                "quickRun",
                "back",
                "reload",
                "run",
                "edit",
                "delete",
            ],
        )

        code, listed, stderr = self._run_cli(["list"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertIn(
            "configure-omarchy-scripts",
            [script["id"] for script in listed["scripts"]],
        )

        code, validated, stderr = self._run_cli(["validate"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(validated["problems"], [])

    def test_configure_script_updates_multiple_values_without_touching_others(self) -> None:
        existing_dir = self.tmp / "already-there"
        core._write_settings(
            {
                "keys": {"edit": "Ctrl+E"},
                "scriptDirs": [str(existing_dir)],
            }
        )
        first = self.tmp / "team-one"
        second = self.tmp / "team-two"

        result = self._run_script(
            {
                "moveDown": "j",
                "open": "Space",
                "scriptDirs": f"{first},{second}",
            }
        )

        stored = json.loads(core.config_path().read_text(encoding="utf-8"))
        self.assertEqual(
            stored,
            {
                "keys": {
                    "edit": "Ctrl+E",
                    "moveDown": "j",
                    "open": "Space",
                },
                "scriptDirs": [
                    str(first.resolve()),
                    str(second.resolve()),
                ],
            },
        )

        printed = json.loads(result["stdout"])
        self.assertEqual(printed["scriptDirs"], stored["scriptDirs"])
        self.assertEqual(printed["keys"]["moveDown"], "J")
        self.assertEqual(printed["keys"]["open"], "Space")
        self.assertEqual(printed["keys"]["edit"], "Ctrl+E")
        self.assertEqual(printed["keys"]["back"], core.KEY_ACTION_DEFAULTS["back"])

    def test_configure_script_default_unsets_override(self) -> None:
        core._write_settings(
            {
                "keys": {"moveDown": "j", "edit": "Ctrl+E"},
                "scriptDirs": [str((self.tmp / "scripts").resolve())],
            }
        )

        result = self._run_script({"moveDown": "default"})

        stored = json.loads(core.config_path().read_text(encoding="utf-8"))
        self.assertEqual(
            stored,
            {
                "keys": {"edit": "Ctrl+E"},
                "scriptDirs": [str((self.tmp / "scripts").resolve())],
            },
        )
        keys, problems = core.resolve_key_bindings()
        self.assertEqual(problems, [])
        self.assertEqual(keys["moveDown"], core.KEY_ACTION_DEFAULTS["moveDown"])

        printed = json.loads(result["stdout"])
        self.assertEqual(printed["keys"]["moveDown"], core.KEY_ACTION_DEFAULTS["moveDown"])

    def test_configure_script_with_blank_values_only_prints_current_config(self) -> None:
        result = self._run_script({})

        self.assertFalse(core.config_path().exists())
        printed = json.loads(result["stdout"])
        self.assertEqual(printed["scriptDirs"], [])
        self.assertEqual(printed["keys"], core.KEY_ACTION_DEFAULTS)

    def test_configure_script_surfaces_underlying_config_error(self) -> None:
        result = core.run(self.repo_root, "configure-omarchy-scripts", {"moveDown": "Shift+"})
        self.assertFalse(result["success"])
        self.assertIn("invalid key spec 'Shift+'", result["stderr"])
        self.assertFalse(core.config_path().exists())


class TestBundledReinstallScript(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.repo_root = Path(__file__).resolve().parents[1]
        self.workspace = self.tmp / "workspace"
        self.state = self.tmp / "state"
        self._old_home = os.environ.get("OMARCHY_SCRIPTS_HOME")
        self._old_state = os.environ.get("OMARCHY_SCRIPTS_STATE")
        self._old_root = os.environ.get("OMARCHY_SCRIPTS_ROOT")
        os.environ["OMARCHY_SCRIPTS_HOME"] = str(self.workspace)
        os.environ["OMARCHY_SCRIPTS_STATE"] = str(self.state)
        os.environ["OMARCHY_SCRIPTS_ROOT"] = str(self.repo_root)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)
        for key, value in (
            ("OMARCHY_SCRIPTS_HOME", self._old_home),
            ("OMARCHY_SCRIPTS_STATE", self._old_state),
            ("OMARCHY_SCRIPTS_ROOT", self._old_root),
        ):
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

    def _fake_source_checkout(self, *, exit_code: int = 0) -> Path:
        root = self.tmp / f"source-{exit_code}"
        install_dir = root / "omarchy-plugin"
        install_dir.mkdir(parents=True)
        install_path = install_dir / "install.sh"
        install_path.write_text(
            "#!/usr/bin/env bash\n"
            "set -Eeuo pipefail\n"
            "echo \"fake install from ${BASH_SOURCE[0]}\"\n"
            "echo \"fake install stderr\" >&2\n"
            f"exit {exit_code}\n",
            encoding="utf-8",
        )
        install_path.chmod(0o755)
        return root

    def test_reinstall_script_metadata_and_cli_visibility(self) -> None:
        path = self.repo_root / "scripts" / "examples" / "reinstall-from-source.sh"
        script = core.parse_metadata(path.read_text(encoding="utf-8"), path, "bundled")
        self.assertEqual(script.id, "reinstall-from-source")
        self.assertEqual(script.category, "Development")
        self.assertEqual([param.name for param in script.params], ["path"])
        self.assertEqual(script.params[0].type, "path")

        code, listed, stderr = self._run_cli(["list"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertIn(
            "reinstall-from-source",
            [script["id"] for script in listed["scripts"]],
        )

        code, validated, stderr = self._run_cli(["validate"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(validated["problems"], [])

    def test_reinstall_script_validates_missing_install_sh_clearly(self) -> None:
        bad_source = self.tmp / "not-a-checkout"
        bad_source.mkdir()

        result = core.run(self.repo_root, "reinstall-from-source", {"path": str(bad_source)})

        self.assertFalse(result["success"])
        self.assertEqual(result["exit_code"], 1)
        self.assertIn(
            f"source checkout must contain omarchy-plugin/install.sh: {bad_source.resolve()}",
            result["stderr"],
        )

    def test_reinstall_script_requires_path_when_no_default_is_configured(self) -> None:
        result = core.run(self.repo_root, "reinstall-from-source", {})

        self.assertFalse(result["success"])
        self.assertEqual(result["exit_code"], 1)
        self.assertIn(
            "path is required unless config devSourcePath is set",
            result["stderr"],
        )

    def test_reinstall_script_reports_nonexistent_source_directory_clearly(self) -> None:
        missing_source = self.tmp / "missing-checkout"

        result = core.run(self.repo_root, "reinstall-from-source", {"path": str(missing_source)})

        self.assertFalse(result["success"])
        self.assertEqual(result["exit_code"], 1)
        self.assertIn(
            f"source checkout directory does not exist: {missing_source.resolve(strict=False)}",
            result["stderr"],
        )

    def test_reinstall_script_uses_configured_default_path(self) -> None:
        source_checkout = self._fake_source_checkout()
        core.set_config_value("devSourcePath", str(source_checkout))

        result = core.run(self.repo_root, "reinstall-from-source", {})

        self.assertTrue(result["success"], msg=result["stderr"])
        self.assertIn("Using configured devSourcePath", result["stdout"])
        self.assertIn("fake install from", result["stdout"])
        self.assertIn("fake install stderr", result["stderr"])

    def test_reinstall_script_propagates_target_exit_code(self) -> None:
        source_checkout = self._fake_source_checkout(exit_code=7)

        result = core.run(self.repo_root, "reinstall-from-source", {"path": str(source_checkout)})

        self.assertFalse(result["success"])
        self.assertEqual(result["exit_code"], 7)
        self.assertIn("fake install from", result["stdout"])
        self.assertIn("fake install stderr", result["stderr"])


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

    def test_resolve_key_bindings_uses_configured_value(self) -> None:
        self.workspace.mkdir(parents=True, exist_ok=True)
        core.config_path().write_text(
            '{\n  "keys": {\n    "moveDown": "j",\n    "quickRun": "Ctrl+R"\n  }\n}\n',
            encoding="utf-8",
        )
        keys, problems = core.resolve_key_bindings()
        self.assertEqual(problems, [])
        self.assertEqual(keys["moveDown"], "J")
        self.assertEqual(keys["quickRun"], "Ctrl+R")
        self.assertEqual(keys["open"], "Return")

    def test_invalid_key_spec_falls_back_to_default(self) -> None:
        self.workspace.mkdir(parents=True, exist_ok=True)
        core.config_path().write_text(
            '{\n  "keys": {\n    "moveDown": "Shift+"\n  }\n}\n',
            encoding="utf-8",
        )
        keys, problems = core.resolve_key_bindings()
        self.assertEqual(keys["moveDown"], core.KEY_ACTION_DEFAULTS["moveDown"])
        self.assertEqual(len(problems), 1)
        self.assertIn("using default Down", problems[0])

    def test_set_get_and_unset_key_config_value(self) -> None:
        value = core.set_config_value("keys.moveDown", "j")
        self.assertEqual(value, "j")
        self.assertEqual(core.get_config_value("keys.moveDown"), "j")
        self.assertEqual(
            json.loads(core.config_path().read_text(encoding="utf-8")),
            {"keys": {"moveDown": "j"}},
        )

        keys, problems = core.resolve_key_bindings()
        self.assertEqual(problems, [])
        self.assertEqual(keys["moveDown"], "J")

        self.assertTrue(core.unset_config_value("keys.moveDown"))
        self.assertIsNone(core.get_config_value("keys.moveDown"))
        self.assertEqual(
            json.loads(core.config_path().read_text(encoding="utf-8")),
            {},
        )
        keys, problems = core.resolve_key_bindings()
        self.assertEqual(problems, [])
        self.assertEqual(keys["moveDown"], core.KEY_ACTION_DEFAULTS["moveDown"])

    def test_set_script_dirs_normalizes_json_list(self) -> None:
        extra = self.tmp / "shared"
        second = self.tmp / "nested" / ".." / "team"
        value = core.set_config_value(
            "scriptDirs",
            [str(extra.relative_to(self.tmp)), str(second)],
            cwd=self.tmp,
        )
        self.assertEqual(
            value,
            [str(extra.resolve()), str(second.resolve(strict=False))],
        )
        self.assertEqual(core.get_config_value("scriptDirs"), value)

    def test_set_dev_source_path_normalizes_string_path(self) -> None:
        value = core.set_config_value("devSourcePath", "checkouts/../source", cwd=self.tmp)
        self.assertEqual(
            value,
            str((self.tmp / "source").resolve(strict=False)),
        )
        self.assertEqual(core.get_config_value("devSourcePath"), value)

    def test_invalid_key_config_value_is_rejected_without_writing(self) -> None:
        with self.assertRaisesRegex(core.ScriptError, "invalid key spec"):
            core.set_config_value("keys.moveDown", "Shift+")
        self.assertFalse(core.config_path().exists())

    def test_invalid_dev_source_path_is_rejected_without_writing(self) -> None:
        with self.assertRaisesRegex(core.ScriptError, "devSourcePath must be a non-empty string path"):
            core.set_config_value("devSourcePath", "")
        self.assertFalse(core.config_path().exists())


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

    def test_config_set_get_and_unset_key(self) -> None:
        code, set_result, stderr = self._run_cli(["config", "set", "keys.moveDown", "j"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(set_result["path"], "keys.moveDown")
        self.assertEqual(set_result["value"], "j")

        code, get_result, stderr = self._run_cli(["config", "get", "keys.moveDown"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(get_result["value"], "j")

        code, unset_result, stderr = self._run_cli(["config", "unset", "keys.moveDown"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertTrue(unset_result["removed"])
        self.assertEqual(core.resolve_key_bindings()[0]["moveDown"], core.KEY_ACTION_DEFAULTS["moveDown"])

    def test_config_set_parses_json_for_script_dirs(self) -> None:
        relative = "shared"
        absolute = self.tmp / "absolute"
        expected = [
            str((Path.cwd() / relative).resolve()),
            str(absolute.resolve()),
        ]

        code, result, stderr = self._run_cli(
            ["config", "set", "scriptDirs", json.dumps([relative, str(absolute)])]
        )
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(result["value"], expected)

        code, get_result, stderr = self._run_cli(["config", "get", "scriptDirs"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(get_result["value"], expected)

        code, unset_result, stderr = self._run_cli(["config", "unset", "scriptDirs"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertTrue(unset_result["removed"])
        self.assertEqual(core.get_config_value("scriptDirs"), [])

    def test_config_set_rejects_invalid_key_spec(self) -> None:
        code, output, stderr = self._run_cli(["config", "set", "keys.moveDown", "Shift+"])
        self.assertEqual(code, 2)
        self.assertIn("invalid key spec", output["error"])
        self.assertIn("invalid key spec", stderr)
        self.assertFalse(core.config_path().exists())

    def test_config_init_materializes_full_defaults_on_fresh_install(self) -> None:
        self.assertFalse(core.config_path().exists())

        code, result, stderr = self._run_cli(["config", "init"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertTrue(result["changed"])
        self.assertEqual(result["keys"], core.KEY_ACTION_DEFAULTS)
        self.assertEqual(result["scriptDirs"], [])
        self.assertEqual(
            json.loads(core.config_path().read_text(encoding="utf-8")),
            {"keys": core.KEY_ACTION_DEFAULTS, "scriptDirs": []},
        )

    def test_config_init_is_idempotent_once_nothing_is_missing(self) -> None:
        self._run_cli(["config", "init"])
        before = core.config_path().read_text(encoding="utf-8")

        code, result, stderr = self._run_cli(["config", "init"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertFalse(result["changed"])
        self.assertEqual(core.config_path().read_text(encoding="utf-8"), before)

    def test_config_init_never_overwrites_existing_customizations(self) -> None:
        existing_dir = self.tmp / "already-there"
        core._write_settings(
            {
                "keys": {"edit": "Ctrl+E", "moveDown": "j"},
                "scriptDirs": [str(existing_dir)],
            }
        )

        code, result, stderr = self._run_cli(["config", "init"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertTrue(result["changed"])  # missing key actions got filled in
        self.assertEqual(result["keys"]["edit"], "Ctrl+E")
        self.assertEqual(result["keys"]["moveDown"], "j")
        self.assertEqual(result["keys"]["moveUp"], core.KEY_ACTION_DEFAULTS["moveUp"])
        self.assertEqual(result["scriptDirs"], [str(existing_dir)])

        stored = json.loads(core.config_path().read_text(encoding="utf-8"))
        self.assertEqual(stored["keys"]["edit"], "Ctrl+E")
        self.assertEqual(stored["keys"]["moveDown"], "j")
        self.assertEqual(stored["scriptDirs"], [str(existing_dir)])

    def test_materialize_default_config_reports_configPath(self) -> None:
        code, result, stderr = self._run_cli(["config", "init"])
        self.assertEqual(code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(result["configPath"], str(self.workspace / "config.json"))


if __name__ == "__main__":
    unittest.main()
