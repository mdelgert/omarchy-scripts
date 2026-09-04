# Running a task end to end

This is the human-facing walkthrough: what you actually do to get one
`docs/tasks/<slug>.md` file implemented, reviewed, and merged. For the
rules an agent itself follows once assigned, see
`skills/task-workflow/SKILL.md` — this doc is "what do I, the human, click
and watch," that one is "what does the agent do."

## Prerequisites (one-time)

- SSH key auth to GitHub already works for `git push`/`pull` (nothing to
  set up).
- `gh` authenticated with a repo-scoped fine-grained PAT — see
  `docs/GITHUB_TOKEN_SETUP.md`. Only needed for opening PRs / `/delegate`,
  not for the agent to claim a branch or commit.

## Step 1 — Pick or write the task

Look in `docs/tasks/` for a file with `Status: Ready`. If the thing you
want done doesn't have a task file yet, write one from `TEMPLATE.md` and
leave it `Status: Draft` until it has real scope and acceptance criteria,
then flip it to `Ready`.

```bash
sed -i 's/^Status: Draft/Status: Ready/' docs/tasks/<slug>.md
git add docs/tasks/<slug>.md && git commit -m "docs: mark <slug> Ready" && git push
```

## Step 2 — Kick it off

Two ways, pick one per task:

**A. An agent in this session** (what was used to build v1 itself): ask for
it directly — "work on `docs/tasks/<slug>.md`, follow
`skills/task-workflow/SKILL.md`." It will:
1. Check the task isn't already claimed (`git branch -a --list 'task/<slug>*'`).
2. Create a worktree + branch off `main`, commit `Status: In progress`,
   push immediately — that push *is* the claim other agents/humans check
   for.
3. Implement within the task's stated scope.
4. Run `make test`, `make lint-qml`, `make validate`.
5. Fill in the task file's Report, set `Status: Done`.
6. Push and open a PR back to `main` with `gh pr create` (needs the token
   from step 0).

**B. GitHub's cloud Coding Agent** (`/delegate` in an interactive Copilot
CLI session): hands the whole thing to GitHub — it creates its own branch
and opens the PR with zero local worktree management on your end at all.
Best for "kick it off and walk away," worse for watching it happen live.

## Step 3 — Watch it happen

```bash
git fetch origin
git branch -a --list 'task/*'        # see what's claimed right now
gh pr list                            # see what's open for review
gh pr view <number>                   # read the diff/description
```

## Step 4 — Review and merge

You review the diff yourself — the agent does not merge its own PR. Once
satisfied:

```bash
gh pr checks <number>                 # if CI is wired up
gh pr merge <number> --squash --delete-branch
```

## Step 5 — Close the loop

```bash
git checkout main && git pull
git mv docs/tasks/<slug>.md docs/tasks/done/<slug>.md
git commit -m "docs: move <slug> to done/" && git push
```

Remove any leftover local worktree:

```bash
git worktree remove ../omarchy-scripts-<slug>
```

## What "good" looks like the first time you try this

- The claim push happens *before* any real implementation work — if you
  `git fetch && git branch -a` mid-task and don't see `task/<slug>` yet,
  something skipped step 2.2.
- The PR description references the task file rather than re-explaining
  everything from scratch.
- `make test`/`make lint-qml`/`make validate` all show green in the PR
  before you're asked to review — a PR that skips this isn't done per
  `docs/AGENT_WORKFLOW.md`'s definition of done.
