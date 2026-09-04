# Running a task end to end

> **Code-review note:** this file documents a human's manual process
> (what you type/click), not application behavior or a contract — skip it
> in automated code reviews (`/code-review`), it has nothing to verify.

What **you, the human**, get and do. Nothing more than this.

## What you get

- A notification that a task's pull request is open, with a link, a
  summary of what it does, and the offer to verify and merge it.
- By default that verify-and-merge happens right away, without a
  separate "yes"/"merge" round-trip: re-run the test suite in a
  throwaway worktree, manually exercise the actual change (run the
  new/changed script or CLI command for real, not just trust the PR
  description), then merge, delete the branch, move the task file to
  `docs/tasks/done/`, and set `Status: Done`.
- The PR itself already has the implementation, passing
  `make test`/`make lint-qml`/`./bin/omarchy-scripts validate`, and the
  task file's Report section filled in.

## What you do

1. **"Kick off `<task-name>`"** — starts it. You never create a branch,
   worktree, or slug yourself.
2. Say **"hold off"** (or similar) only if you want to review the PR
   yourself before it's merged. Otherwise you don't need to say
   anything else — a "yes"/"merge `<PR>`" is still honored the same way
   if you'd rather explicitly trigger it, but it is no longer required.

That's the whole process. You are never expected to type git/gh commands,
branch names, or a task slug — if that's ever what's happening, something
went off script.

## One-time setup

- SSH key auth to GitHub already works for pushes — nothing to do.
- `gh` needs a repo-scoped token authenticated once per machine so PRs can
  be opened/merged — see `docs/GITHUB_TOKEN_SETUP.md`.

## Reference (not something you need to do)

For what the agent itself does to earn that "already tested, already
documented" PR, see `skills/task-workflow/SKILL.md`. For what merging
actually runs under the hood, see `docs/AGENT_WORKFLOW.md`'s definition of
done. Neither is required reading to use this process.
