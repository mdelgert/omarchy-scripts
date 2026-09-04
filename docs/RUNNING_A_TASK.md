# Running a task end to end

This is what **you, the human**, actually do. It is short on purpose. If
you find yourself typing a branch name, a slug, or a git command to get a
task started or merged, something has gone wrong — that's the agent's job,
not yours.

For what the agent itself does once it picks up a task, see
`skills/task-workflow/SKILL.md`. You don't need to read that to use this
process; it's there so the agent doesn't need you to re-explain it.

## The whole process, in practice

1. **"Kick off `<task-name>`"** (or "kick off the next Ready task" if you
   don't have a specific one in mind). That's it — you don't create a
   branch, a worktree, or type a slug. The agent reads the task file,
   claims it, implements it, tests it, and opens a pull request.
2. **Wait.** You'll be told when the PR is open, with a link.
3. **"Merge `<PR>`"** (or "verify and merge `<PR>`" if you want it actually
   re-run and exercised before merging, not just diff-reviewed). Either
   way, this is one thing you say — not a checklist you run yourself.
4. Done. The agent/assistant moves the task file to `docs/tasks/done/` and
   cleans up branches/worktrees as part of finishing the merge.

That's the entire loop. Everything below is reference material for when
you want more control or are curious what's happening under the hood — you
never have to read it to use the process above.

## One-time setup

- SSH key auth to GitHub already works for pushes — nothing to do.
- `gh` needs to be authenticated with a repo-scoped token so PRs can be
  opened/merged — see `docs/GITHUB_TOKEN_SETUP.md`. You only do this once
  per machine.

## If you want to review a PR yourself instead of just saying "merge it"

You can always look at it directly, fully online, no terminal required:
open the PR link in your browser and read the diff there.

If you want it *re-tested*, not just read — say "verify and merge" and
whoever's driving (agent or assistant) will pull the branch into a
throwaway location, run `make test`/`make lint-qml`/`./bin/omarchy-scripts
validate`, exercise the actual change, and clean up afterward. You don't
need to know the commands for this; asking for it by name is enough.

## What "good" looks like, if you're ever checking up on it

- A claimed task shows up as a pushed `task/<slug>` branch before real
  implementation work starts — `git branch -a` (or `gh pr list` once a PR
  exists) shows what's in flight.
- The PR references the task file's Report section instead of re-explaining
  everything from scratch.
- Tests/lint/validate are already green in the PR by the time you're asked
  to look at it — a PR that skips this isn't done per
  `docs/AGENT_WORKFLOW.md`'s definition of done.
