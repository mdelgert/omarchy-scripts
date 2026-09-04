# Task Workflow Skill

Use this skill whenever you are asked to work on a `docs/tasks/<slug>.md`
file in this repository — whether you were pointed at one specific file or
told to "pick a Ready task."

The goal: many agents (or the same agent across many sessions) can work on
this repo at once without stepping on each other, using nothing but git
branches and the task file itself as the coordination mechanism. No ticket
system, no lock server, no extra infra.

## Before you write any code

1. **Read the task file fully**, plus `AGENTS.md`, `docs/VISION.md`,
   `docs/ARCHITECTURE.md`, and `docs/SCRIPT_SPEC.md` at the repo root.
2. **Check the task is actually claimable:**
   - Its `Status` must be `Ready` (not `Draft` — a Draft task hasn't been
     scoped enough to implement safely; stop and ask the user instead of
     guessing at missing scope/acceptance-criteria).
   - Run `git fetch origin && git branch -a --list 'task/<slug>*'`. If a
     branch matching this task's slug already exists (local or remote),
     someone else already claimed it — stop and report that back rather
     than duplicating or overwriting their work.
3. **Claim it immediately, before implementing anything:**
   ```bash
   git checkout main && git pull
   git worktree add ../<repo-name>-<slug> -b task/<slug> main
   cd ../<repo-name>-<slug>
   ```
   Edit the task file's `Status: Ready` → `Status: In progress`, commit that
   single change, and push right away:
   ```bash
   git commit -am "task/<slug>: claim"
   git push -u origin task/<slug>
   ```
   This push *is* the claim. Anyone else who runs step 2's `git branch -a`
   after this point sees the branch and knows to skip it. Do this before
   spending any real effort on the implementation — a claimed-but-abandoned
   branch is cheap to notice and reclaim; silent duplicate work on the same
   task is not.

## While implementing

- Stay inside the task's stated `Scope` and respect its `Out of scope`
  section — do not expand it unless you hit a real blocker, in which case
  stop and report the blocker instead of improvising a bigger change.
- Commit as you go on `task/<slug>`; push periodically so the branch
  reflects real progress, not just the claim.
- If you need to verify live QML/UI behavior (keyboard nav, panel
  visibility, terminal hand-off), you need real access to `hyprctl`, `grim`,
  and `omarchy-restart-shell` on the actual desktop session — a sandboxed
  subagent restricted to only its own worktree directory cannot do this.
  If you find yourself unable to reach these tools, say so explicitly
  rather than silently skipping live verification.

## Before finishing

- [ ] `make test`, `make lint-qml`, and `make validate` all pass — this is
      this project's non-negotiable definition of done
      (`docs/AGENT_WORKFLOW.md`).
- [ ] Every checkbox in the task's "What done looks like" is either
      satisfied or explicitly called out as a known limitation in the
      Report.
- [ ] Documentation (`docs/SCRIPT_SPEC.md`/`docs/ARCHITECTURE.md`/etc.) is
      updated if the contract changed.
- [ ] The task file's `Report` section is filled in: what changed, decisions
      made, limitations, useful follow-ups.
- [ ] Set the task file's `Status: Done`.

## Opening the pull request

```bash
git push
gh pr create --base main --head task/<slug> \
  --title "<short summary>" \
  --body "Implements docs/tasks/<slug>.md. See its Report section for details."
```

Do not merge your own PR. A human reviews and merges it; only after merge
does the task file move to `docs/tasks/done/` (a follow-up commit on
`main`, not part of your PR, unless the reviewer asks you to include it).

## Cleaning up

Once merged (or if you abandon the task), remove your worktree so it
doesn't linger:

```bash
cd <path to main worktree>
git worktree remove ../<repo-name>-<slug>
git branch -d task/<slug>   # after merge; -D if abandoning unmerged work
```

## Rules

- **Never push directly to `main`.** Always a branch, always a PR.
- **One task per branch, one branch per task.** Don't bundle unrelated
  task files into a single PR.
- **The claim commit (`Status: In progress` + push) always comes before
  implementation work**, not after. It's the entire coordination mechanism
  this skill relies on — skipping it defeats the purpose.
- **Never invent scope.** A task file that's ambiguous or missing
  acceptance criteria should be flagged back to the user, not guessed at.
