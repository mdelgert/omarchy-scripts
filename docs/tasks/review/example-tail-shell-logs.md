# Task: Example script that tails a running plugin's shell logs

Status: Ready
Type: feature

## Problem

Live-debugging a running Omarchy plugin (QML errors, `console.log`
output, crashes) currently means knowing, from memory or docs, how the
Omarchy shell surfaces its logs (journal, a log file, or stdout of a
supervising process) and constructing the right `journalctl`/`tail`
command by hand each time. There is no script that just does this for a
given plugin id.

## Scope

- Add `scripts/examples/tail-shell-logs.sh`.
- Parameters: `pluginId` (`string`, `default=io.github.mdelgert.omarchy-scripts`),
  `lines` (`integer`, `default=200`, min=1) for how much history to show
  before following.
- Behavior: investigate how the running Omarchy shell actually surfaces
  logs on this machine (check `journalctl --user -u <unit>` conventions,
  or wherever `omarchy-shell`/Quickshell writes output — do not guess;
  find the real mechanism first, e.g. by checking what `omarchy-shell`
  itself does or its own docs/help) and tail/follow that output, ideally
  filtered to lines mentioning the given `pluginId` if the log stream
  isn't already scoped per-plugin.
- If logs turn out not to be filterable by plugin id at all, document
  that limitation plainly in the script's own description and in the
  Report, rather than pretending to filter and silently showing
  everything.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; actual log tailing is a manual verification step (also
  inherently long-running/streaming, like
  `example-watch-and-reload-plugin.md` — note the same UI
  long-running-script consideration there if relevant here too).
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run on this real machine while the shell is running: shows
      genuinely relevant recent log output, not an empty/wrong stream.
- [ ] Any filtering limitation (if per-plugin filtering isn't actually
      possible) is documented, not silently absent.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Any change to how Omarchy itself logs — this script only reads
  whatever mechanism already exists.

## Testing notes

- Trigger a real QML error or `console.log` in this plugin's own code
  while the script is tailing, and confirm it appears.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
