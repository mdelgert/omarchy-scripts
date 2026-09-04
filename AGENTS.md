# AGENTS.md

## Standing rules

Before an architectural, contract, metadata, engine, or frontend change, read `docs/VISION.md`, `docs/ARCHITECTURE.md`, and `docs/SCRIPT_SPEC.md`. Read the assigned `docs/tasks/<slug>.md` too, when one exists.

- Keep the Python engine frontend-neutral; CLI and QML consume its normalized, versioned JSON rather than parsing script comments themselves.
- Scripts are plain Bash files. There is no required action-dispatch or undo protocol in v1, and parameter metadata is never shell-expanded.
- Use argv arrays, not command strings: no Python `shell=True`, no `eval` for user input, and no QML `Process` command assembled from metadata or values.
- Preserve the existing small, standard-library Python approach and the straightforward QML style. Add tests for parser, validation, JSON-contract, or execution changes.

## Verify before handoff

Run `make test`, `make lint-qml`, and `make validate`. `make lint-qml` may retain the documented pre-existing `missing-property`, `uncreatable-type`, `unqualified`, and `signal-handler-parameters` warnings, but must introduce no new warning categories. Update docs when a contract changed, and complete the assigned task's acceptance criteria and Report. These are the definition of done in `docs/AGENT_WORKFLOW.md`.
