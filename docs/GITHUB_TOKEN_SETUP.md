# GitHub token setup for `gh` (repo-scoped, not account-wide)

`git push`/`git pull` on this repo already work via your SSH key — this doc
is only about the separate credential `gh` needs for anything that talks to
the GitHub API instead of git's own transport: `gh pr create`, `gh pr view`,
`gh issue`, `/delegate` (GitHub's cloud Coding Agent), etc.

The default `gh auth login` interactive flow requests broad, account-wide
OAuth scopes (`repo`, etc.) — access to *every* repo you can touch, not just
this one. Use a **fine-grained personal access token** instead: it can be
locked to a single repository and a minimal set of permissions.

## Creating the token

1. Go to <https://github.com/settings/personal-access-tokens/new>.
2. **Resource owner**: your account (or the org, if the repo lives in one).
3. **Repository access**: choose "Only select repositories" and pick just
   the one repo you're working in (e.g. `mdelgert/omarchy-scripts`). Do not
   choose "All repositories."
4. **Permissions → Repository permissions**, set only what you actually
   need:
   - `Contents`: Read and write — required to push branches/commits.
   - `Pull requests`: Read and write — required for `gh pr create`/`gh pr
     view`/`gh pr merge`.
   - `Metadata`: Read-only — GitHub adds this automatically; it's required
     for the token to function at all and isn't optional.
   Leave everything else (Actions, Issues, Workflows, Admin, etc.) at "No
   access" unless a specific task genuinely needs it.
5. Set an expiration (30/60/90 days, or custom) — short-lived is safer than
   "no expiration" for a token you're about to hand to an agent.
6. Click **Generate token** and copy it immediately — GitHub only shows it
   once.

## Using the token

Two ways to authenticate `gh` with it; prefer the second for anything
session-scoped (an agent's shell, a one-off terminal) since it doesn't
touch `gh`'s persistent global config at all:

```bash
# Option A: persists in gh's own config (~/.config/gh/hosts.yml)
echo '<TOKEN>' | gh auth login --with-token

# Option B: session-scoped only, nothing written to disk, expires when the
# shell/env goes away. gh (and most git tooling that shells out to gh)
# reads this automatically.
export GH_TOKEN='<TOKEN>'
```

Verify it worked and confirm it's actually scoped the way you expect:

```bash
gh auth status
gh repo view mdelgert/omarchy-scripts   # should work
gh repo view mdelgert/some-other-repo   # should fail — token can't see it
```

## Revoking / rotating

Fine-grained tokens are managed at
<https://github.com/settings/personal-access-tokens> — delete or regenerate
from there at any time; this instantly invalidates it for every `gh`/`git`
session using it, without touching your main GitHub password or SSH keys.

## Why this matters for agent workflows

This repo's `skills/task-workflow/SKILL.md` has an agent push a claimed
`task/<slug>` branch and open a PR back to `main`. The push needs only your
existing SSH key (already works, nothing to set up). The PR-open step needs
a `gh`-authenticated credential — giving an agent a repo-scoped token here
means it can open PRs against *this* repo and nothing else, even if
something in its environment were compromised or it misbehaved.
