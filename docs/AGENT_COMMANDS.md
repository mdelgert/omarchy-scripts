# Agent commands cheat sheet

> **Code-review note:** this file is a personal command reference, not
> application behavior or a contract — skip it in automated code reviews
> (`/code-review`).

Quick reference for the phrases/commands used day-to-day in this repo.
Nothing here is enforced by tooling; it's a memory aid.

## Kick off a task (this agent)

Say, verbatim: **"Kick off `<task-slug>`"** (the slug matches a file in
`docs/tasks/<slug>.md` with `Status: Ready`). The agent claims the task,
implements it on `task/<slug>`, opens a PR, and verifies + merges it
without a separate approval round-trip unless you say "hold off" first.
See `docs/RUNNING_A_TASK.md` for the full human-facing description of this
loop.

## Claude Code review

`/code-review` is an **interactive slash command** typed inside a `claude`
session — it is not a CLI flag, and `claude ultrareview` is a deprecated
alias for `/code-review ultra`.

```
/code-review <level> [--fix] [--comment] [<PR#>]
```

- **Level:** `low`, `high`, `ultra` (higher effort levels run in the cloud
  as a background agent).
- **`--fix`**: apply the findings locally after the review finishes.
- **`--comment`**: post findings — inline PR comments on GitHub, or one
  general MR note on GitLab (via `glab`).
- **Target**: omit for the current branch; pass a PR number to fetch and
  review that GitHub PR instead (`ultra` only).

Examples:

```
/code-review high                  # local high-effort review, current branch
/code-review ultra --fix           # cloud review, apply fixes locally when done
/code-review ultra 42 --comment    # cloud review of PR #42, post as PR comment
```

Do a review in its own branch (so `--fix` doesn't touch `main`):

```bash
git checkout -b code-review/high-fix
```

then, inside the interactive session:

```
/code-review high --fix
```

`/code-review ultra` is user-triggered and billed — an agent cannot launch
it on your behalf via Bash or otherwise; you must type it yourself.
