# Task: Run a script directly from the browse list

Status: Draft
Type: feature

## Problem

Today the only way to run a script is: open the menu → select a script →
open its detail view → press Run. For scripts with no parameters (or only
optional ones with sane defaults) — the majority of quick diagnostics like
`hostname-info.sh` or `check-website-status.sh` — that's two extra
keystrokes/clicks and a whole screen transition just to launch something the
user already knows they want to run. This makes the plugin feel slower and
less "instant" than it should for its most common use case, and undercuts
the keyboard-first feel established in `keyboard-driven-menu-navigation.md`.

## Suggested flow (proposal, not mandatory — revisit if a better idea turns up)

The detail view exists for a reason (description, param form, last-run
output) and shouldn't be removed or bypassed for scripts that need input.
The two cases genuinely differ, so treat them differently instead of forcing
one interaction model on both:

1. **Scripts with no required parameters** (all params optional/have
   defaults, or zero params): add a second action key on the highlighted
   browse row, e.g. `Ctrl+Enter` (Enter still opens detail, unchanged) or a
   single-letter mnemonic like `r`, that runs immediately using default
   parameter values — no detail-view detour. Mouse users get the same via a
   small inline "▶" affordance on the row (hover-revealed, consistent with
   how the rest of the shell surfaces secondary row actions).
2. **Scripts with required parameters**: the same key still takes the user
   to the detail view (can't skip collecting required input), but should
   land focus directly in the first parameter field instead of just opening
   passively — one fewer Tab/click than today.
3. Either path uses the exact same `runInTerminal`/`terminalRunning`/
   `pendingSelect` machinery already built for the detail view's Run button
   — this is a UI entry-point change, not a new execution path. Don't
   duplicate the process-launch logic.
4. After the run finishes, the browse list itself (not just the detail
   view) should reflect that a run just happened — at minimum, keep the
   cursor on the row that was run so repeat-running the same script twice in
   a row (a very common diagnostic pattern) needs only one keypress each
   time.

Whoever picks this up should sanity-check this proposal against how similar
"list of things, one probably needs a form and one doesn't" UIs are handled
elsewhere in the installed Omarchy shell before committing to the specific
keybind — consistency with the rest of the shell's conventions matters more
than this exact suggestion.

## Scope

- Determine (from `Script`/`Param` metadata already exposed by the engine)
  whether a script can run with zero user input, so the browse list can
  decide which of the two behaviors above applies per row.
- Wire a second key (and, ideally, a discoverable mouse affordance) in
  `Menu.qml`'s browse-list `keyCatcher` alongside the existing Enter/Escape/
  arrow handling.
- Update the "Type to filter — ↑/↓ to move, Enter to open, Esc to close"
  hint line to mention the new run shortcut.
- Reuse the existing `ScriptEngine` run/terminal machinery unchanged.

## What done looks like

- [ ] A no-parameter (or all-optional-parameter) script can be launched from
      the browse list without opening its detail view first.
- [ ] A script with required parameters still routes through the detail
      view, with focus placed usefully (first param field) rather than
      passively landing on the header.
- [ ] The browse list's cursor position survives a run so the same script
      can be re-run immediately.
- [ ] Mouse and keyboard both have a way to trigger the new shortcut.
- [ ] `make test`, `make lint-qml`, and `make validate` pass.
- [ ] Verified live (`omarchy-restart-shell` + `grim`/`hyprctl layers -j`,
      per this project's established workflow — `qmllint` alone cannot
      confirm key handling or focus).

## Out of scope

- Changing what "Run" does once triggered (terminal hand-off, exit-code
  capture, etc. — already correct, don't touch).
- Batch-running multiple scripts at once.

## Testing notes

Use `greet-user.sh` (has a required param) and `hostname-info.sh` (no
params) as the two representative cases when testing live.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful
follow-ups.
