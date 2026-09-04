# Running a task end to end

What **you, the human**, get and do. Nothing more than this.

## What you get

- A notification that a task's pull request is open, with a link.
- The PR itself already has the implementation, passing
  `make test`/`make lint-qml`/`./bin/omarchy-scripts validate`, and the
  task file's Report section filled in.

## What you do

1. **"Kick off `<task-name>`"** — starts it. You never create a branch,
   worktree, or slug yourself.
2. **"Merge `<PR>`"** — merges it, deletes the branch, moves the task file
   to `docs/tasks/done/`, and updates its `Status: Done`. One sentence, one
   action, all of that happens as a result.
3. If you'd rather it be re-tested before merging instead of just merged on
   trust, say **"verify and merge `<PR>`"** instead of "merge" — same one
   sentence, just does the extra check first.

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
