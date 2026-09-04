# Task: add a script capability showcase with defaults

Status: In progress
Type: feature

## Problem

The repository has small examples for individual script features, but no
single script that lets a user or frontend developer exercise the complete v1
parameter surface in one place. This makes it harder to demonstrate the form
UI, verify normalized JSON, and quickly confirm that default values reach a
real Bash script.

## Scope

- Add `scripts/examples/script-capability-showcase.sh` as a safe, run-only
  demonstration script. It must use the normal script metadata and
  `script_parse_args` helper, with `set -Eeuo pipefail`.
- Declare exactly one parameter of each supported v1 type, and give every
  parameter a usable metadata default:
  - `message` (`string`, default `Hello from omarchy-scripts!`).
  - `count` (`integer`, default `3`, with `min=1` and `max=10`).
  - `enabled` (`boolean`, default `true`).
  - `format` (`choice`, default `summary`, with choices `summary,details`).
  - `output` (`path`, default `.`).
- Include human-readable labels and a useful description; tag the script as
  an example/demo. Metadata may include a placeholder where it improves the
  empty-field experience, but the defaults must be the values submitted by a
  default Run.
- Print the parsed values and a small deterministic demonstration using them:
  repeat the message `count` times, show whether the feature is enabled, and
  vary the amount of detail based on `format`. Treat `output` as a displayed
  destination only; do not create, modify, or delete files.
- Add focused tests only if needed to cover new behavior; this task should
  not require engine, CLI, QML, or JSON-contract changes.

## What done looks like

- [ ] The new script is discovered with valid metadata and no duplicate ID.
- [ ] Its normalized metadata exposes one parameter of each v1 type, and all
      five parameters have defaults, labels, and the intended integer/choice
      constraints.
- [ ] Running with no explicit values succeeds and visibly demonstrates all
      defaults.
- [ ] Running with overridden values demonstrates string, integer, boolean,
      choice, and path values without shell evaluation or file-system writes.
- [ ] Invalid integer, boolean, and choice values are rejected by the engine;
      the script itself remains frontend-neutral.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.

## Out of scope

- Changes to the parser, runner, QML form controls, JSON contract, or
  parameter types.
- Writing output files, executing user-provided commands, or adding an undo
  protocol.
- Replacing or consolidating the existing focused example scripts.

## Testing notes

- Exercise `info`/`list` and `run` through the CLI using defaults and a full
  set of overrides.
- Confirm a path containing spaces is passed and displayed as one value.
- Confirm out-of-range integers, an invalid boolean, and a choice outside the
  declared list fail validation before the script runs.
- If verifying the form manually, confirm each control is populated with its
  metadata default and that the selected values arrive unchanged in output.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful
follow-ups. Set Status to Done after merge, then move the completed file to
`docs/tasks/done/`.
