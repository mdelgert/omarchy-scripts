# Task: script that changes the machine's hostname

Status: Done
Type: feature

## Problem

There's no example script for changing the system hostname — a common,
simple admin action. `hostname-info.sh` (existing example) only reports
the current hostname; there's no counterpart that changes it.

## Scope

- Add `scripts/examples/set-hostname.sh`:
  - `@script.id set-hostname`, category `System` (or similar).
  - One `@param hostname string required=true label="New hostname"`.
  - Print the current hostname first (so the user has an implicit "undo"
    value: re-run the script with the old name to revert — no automated
    undo is required per `docs/VISION.md`, this is a plain run-only
    script).
  - Validate the typed value is a plausible hostname before doing
    anything (non-empty, no whitespace/slashes; a simple regex is
    enough — don't try to fully replicate RFC 1123 validation).
  - Apply the change with `hostnamectl set-hostname <value>` (prefer
    `hostnamectl` over editing `/etc/hostname` directly — it updates
    `/etc/hostname` and the running kernel hostname together, and is the
    standard tool on systemd-based systems, which Omarchy is).
  - This needs root/polkit privileges `hostnamectl` will typically not
    have when run as a normal user — surface a clear, actionable error
    (e.g. suggest running via `sudo` / that a polkit prompt may appear)
    rather than a confusing raw permission-denied failure. Do not
    silently retry with `sudo` yourself if the engine's execution model
    doesn't support interactive privilege prompts — check how other
    system-level example scripts (if any) already handle this, or flag
    it as a known limitation in the Report if none do yet.
  - Print the resulting hostname after the change (re-read it, don't just
    echo back the input) so the user can confirm it actually took effect.

## What done looks like

- [x] Running the script with a valid new hostname changes it and the
      script's own output confirms the new value by re-reading it (not
      just echoing the input back).
- [x] An obviously invalid value (empty, contains a space or `/`) is
      rejected with a clear error before attempting `hostnamectl`.
- [x] Lack of sufficient privileges produces a clear, actionable message,
      not a raw stack trace or silent no-op.
- [x] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.
- [x] Documentation updated only if this surfaces a new pattern worth
      recording (e.g. how privilege-requiring example scripts should
      report failure) — otherwise no doc changes are needed. (No pattern
      change needed; documented decisions in the Report above instead.)

## Out of scope

- Any automated "undo" — re-running the script with the previous
  hostname is the whole undo story, consistent with `docs/VISION.md`'s
  v1 stance that not every script needs a check/apply/undo lifecycle.
- Editing `/etc/hosts` to keep a matching `127.0.1.1 <hostname>` line in
  sync — flag it as a known follow-up in the Report if you think it's
  worth doing, but don't expand scope to include it here.
- Building any general "elevate privileges" mechanism into the engine —
  if privilege escalation is genuinely blocked by the current execution
  model, report that as a limitation rather than working around it.

## Testing notes

- Test on a real session: confirm the hostname actually changes system-
  wide (e.g. `hostnamectl status` before/after, and a new shell picking
  up the new `$HOSTNAME`/prompt), then revert back to the original
  hostname afterwards so the test machine isn't left renamed.
- Test the invalid-input rejection path (blank, a value with a space).
- Test running without sufficient privileges to confirm the error
  message is clear.

## Report

Added `scripts/examples/set-hostname.sh`:

- `@script.id set-hostname`, category `System` (new category — no existing
  example used it), single required `hostname` string param.
- Prints the current hostname up front (via `hostname`) as the implicit
  undo value before doing anything.
- Validates the input is non-empty and has no whitespace/slash before
  calling `hostnamectl` — a simple regex check, not full RFC 1123.
- Applies the change via `hostnamectl set-hostname <value>`.
- Re-reads `hostname` after the call to confirm the actual resulting
  value rather than echoing the input back.
- On `hostnamectl` failure (captured via `set +e`/`$?`, output captured),
  prints the underlying error plus an actionable suggestion to re-run
  with `sudo` or that a polkit prompt may be required, since no other
  example script in this repo has an established privilege-escalation
  pattern to follow (checked `run-command.sh`, `reinstall-from-source.sh`,
  `configure-omarchy-scripts.sh` — none invoke `sudo` or handle
  permission-denied specially). No engine-level "elevate privileges"
  mechanism exists; the script just reports the limitation clearly
  instead of silently failing or attempting sudo itself.

Manually tested on this machine (systemd, `hostnamectl` present):
- Invalid inputs (empty, `"bad host"`, `"bad/host"`) are rejected before
  calling `hostnamectl`, each with a clear message and exit 1.
- Running as a normal user without a polkit agent fails with a clear,
  actionable message (confirmed real `hostnamectl` "interactive
  authentication required" error surfaced, plus the sudo/polkit hint) —
  no raw stack trace or silent no-op.
- Running via `sudo` actually changed the system hostname
  (`hostnamectl status` showed the new static hostname), and the
  script's own re-read confirmed it. Reverted the test machine back to
  its original hostname (`vm-01`) afterward.

`make test`, `make lint-qml` (no new warning categories beyond the
documented pre-existing ones), and `make validate` all pass.

Known follow-ups (left out of scope per the task):
- No automated update of `/etc/hosts` (e.g. a `127.0.1.1 <hostname>`
  line) — flagged here as a possible future enhancement, not implemented.
- No general privilege-escalation mechanism was added to the engine;
  scripts requiring elevated privileges still rely on the user running
  omarchy-scripts itself with sufficient rights, or a polkit agent being
  available. Worth revisiting if more privilege-requiring example
  scripts are added.
