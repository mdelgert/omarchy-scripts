# Task: Example script that installs an Omarchy plugin (self-referential default)

Status: Ready
Type: feature

## Problem

None of the current example scripts demonstrate driving Omarchy's own
plugin management (`omarchy plugin add/enable`) from inside a script —
even though that is exactly the command documented in this repo's own
`README.md` Install section and `omarchy-plugin/install.sh`. As with
`example-clone-repository.md`, this is a good demonstration of a safe,
always-valid **static** `@param default=` value: defaulting to *this
plugin's own* repository URL and plugin id means the script can be run
immediately with zero required input, and either reinstalls/updates the
running plugin itself or demonstrates the exact command a user would
run for any other Omarchy plugin.

## Scope

- Add `scripts/examples/install-omarchy-plugin.sh`.
- Parameters:
  - `repoUrl` (`string`,
    `default=https://github.com/mdelgert/omarchy-scripts.git`,
    required) — defaults to this repository, matching the URL already
    documented in `README.md`'s Install section.
  - `pluginId` (`string`, `default=io.github.mdelgert.omarchy-scripts`,
    required) — defaults to this plugin's own id, matching the id used
    throughout `README.md` and `omarchy-plugin/install.sh`.
  - `section` (`choice`, e.g. `choices=left,center,right`,
    `default=right`) for the bar section passed to
    `omarchy plugin enable`, matching the existing convention used in
    `README.md` (`omarchy plugin enable <id> right`).
- Behavior: run `omarchy plugin add <repoUrl> --enable`, then
  `omarchy plugin enable <pluginId> <section>` (mirroring exactly the
  two-step sequence already documented in `README.md`'s Install
  section and troubleshooting note). Print the resulting output so the
  user sees Omarchy's own success/failure messages, and propagate the
  exit code.
- Handle the "already installed" case gracefully — `omarchy plugin add`
  against an id that already exists should surface Omarchy's own
  message clearly rather than a confusing wrapped error.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly, matching the style of the other
  example scripts.
- Add/extend a test in `tests/test_core.py` confirming the new script
  parses correctly and appears in `list`/`validate` output. Since
  `omarchy` itself is only available on a real Omarchy install, the
  automated test should cover metadata/argument parsing only — actual
  `omarchy plugin add` execution is a manual/live verification step,
  same as other Omarchy-session-dependent behavior in this repo (see
  how `reinstall-from-source.sh`'s tests handle running
  `omarchy-shell` optionally).
- Update `README.md`'s Example scripts list with a one-line description,
  and note this script's relationship to the Install section it mirrors
  (link back, don't duplicate the explanation).

## What done looks like

- [ ] `scripts/examples/install-omarchy-plugin.sh` exists, is
      executable, and parses via `./bin/omarchy-scripts list` /
      `validate` with no errors.
- [ ] Running it with all defaults on a real Omarchy session installs
      (or confirms already-installed) this very plugin and enables it
      in the default section, matching the documented manual command
      sequence exactly.
- [ ] Running it with a different `repoUrl`/`pluginId` installs a
      different plugin, proving the defaults are just defaults, not
      hardcoded behavior.
- [ ] Tests are added or updated where behavior changed (metadata
      parsing at minimum; live `omarchy` execution documented as a
      manual verification step if `omarchy` isn't available in CI).
- [ ] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.
- [ ] `README.md`'s Example scripts section documents the new script.

## Out of scope

- Any handling of `omarchy plugin remove/disable/update` — this script
  is scoped to install+enable only, matching the task title. A removal
  counterpart could be a separate future task if wanted.
- Reimplementing anything `omarchy plugin add`/`enable` already does —
  this script is a thin, well-described wrapper, not a reimplementation.

## Testing notes

- On a real Omarchy session, run with all defaults and confirm it
  matches running the two documented commands
  (`omarchy plugin add https://github.com/mdelgert/omarchy-scripts.git --enable`
  and `omarchy plugin enable io.github.mdelgert.omarchy-scripts right`)
  by hand.
- Confirm the already-installed case (running it twice) reports
  Omarchy's own message clearly instead of a confusing wrapped error.
- Confirm a non-default `repoUrl`/`pluginId` pair installs a different,
  real plugin (for example a small, harmless public one, or skip this
  case if none is safe to test against and note that limitation in the
  Report).

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
