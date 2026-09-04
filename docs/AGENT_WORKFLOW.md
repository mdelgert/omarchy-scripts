# Agent Workflow

This is a small project. Keep its workflow small too: one protected `main` branch and short-lived `task/<slug>` branches. Create each task branch from an up-to-date `main`, make the change and its tests there, and open a PR directly back to `main`. Do not add a permanent integration branch unless the project actually develops a sustained need for one.

## Task files

Each assignable unit of work lives at `docs/tasks/<slug>.md`; the branch name should match its slug. Copy `docs/tasks/TEMPLATE.md` to start one. A task is **Draft** while it is still an idea or lacks enough scope and acceptance criteria to implement safely — keep Draft files in `docs/tasks/draft/`. Mark it **Ready** when a human or agent can take it without inventing product decisions; Ready (and claimed/In progress, pre-PR) files live at the top level of `docs/tasks/`. Once a PR is open, move the file to `docs/tasks/in-review/`. Finished files move to `docs/tasks/done/` with their report completed. See `docs/tasks/README.md` for the full folder-to-status table.

## Completion loop

1. Write or update the task file and mark it Ready.
2. Create `task/<slug>` from `main`; implement the bounded scope and commit.
3. Review the diff and open a PR to `main`; move the task file to `docs/tasks/in-review/`.
4. Merge only after the definition of done below is satisfied; then mark the task Done and move the file to `docs/tasks/done/`.

## Definition of done

- Tests pass: `make test`.
- `make lint-qml` introduces no warning categories beyond the documented pre-existing `missing-property`, `uncreatable-type`, `unqualified`, and `signal-handler-parameters` warnings from the external Omarchy/Quickshell types and current QML style.
- `make validate` passes (it runs `./bin/omarchy-scripts validate`).
- Documentation and this specification are updated when the public contract, script metadata, or architecture changed.
- The task file's acceptance criteria and Report are completed when a task file was assigned.
