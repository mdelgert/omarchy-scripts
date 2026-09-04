# Tasks

Each `docs/tasks/<slug>.md` file is one small, assignable unit of work: copy `TEMPLATE.md`, give it a kebab-case slug that matches its `task/<slug>` branch, and mark it Draft until its problem, scope, out-of-scope boundaries, and done criteria make it safe to hand off. Mark it Ready when it is implementable; after merge, complete its report, set Status to Done, and move the file into `done/` for history/reference — a finished task file should not be left in this top-level directory. See `docs/AGENT_WORKFLOW.md` for the lightweight branch and review loop.

## Folder = status

A task file's folder mirrors its `Status:` field so you can tell what's safe to pick up at a glance:

| Folder | Status | Meaning |
| --- | --- | --- |
| `draft/` | Draft | Idea only; not yet scoped enough to hand off. |
| *(top level)* | Ready | Implementable now, unclaimed. |
| *(top level)* | In progress | Claimed; `task/<slug>` branch exists, no PR yet. |
| `in-review/` | In progress | PR is open, awaiting verify-and-merge. |
| `done/` | Done | Merged; kept for history/reference. |

Move the file between folders as its status changes; the `Status:` line inside the file must always agree with the folder it's in.

> Note: `docs/tasks/review/` (no hyphen) is a *pre-existing, unrelated* folder of example scripts (`Status: Ready`) — it predates this scheme and is not part of the Draft/Ready/In-review/Done lifecycle above. Don't confuse it with `in-review/`.
