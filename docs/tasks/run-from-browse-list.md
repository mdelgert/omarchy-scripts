# Task: Run a script directly from the browse list

Status: Done
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

- [x] A no-parameter (or all-optional-parameter) script can be launched from
      the browse list without opening its detail view first.
- [x] A script with required parameters still routes through the detail
      view, with focus placed usefully (first param field) rather than
      passively landing on the header.
- [x] The browse list's cursor position survives a run so the same script
      can be re-run immediately.
- [x] Mouse and keyboard both have a way to trigger the new shortcut.
- [x] `make test`, `make lint-qml`, and `make validate` pass.
- [x] Verified live (`omarchy-restart-shell` + `grim`/`hyprctl layers -j`,
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

Implemented the two-path browse-list shortcut using the existing
`Shift+Enter`-for-secondary-action convention already used by the installed
Omarchy shell's own clipboard plugin (`/usr/share/omarchy/shell/plugins/
clipboard/Clipboard.qml`, which uses Shift+Enter/Alt+Enter as secondary
actions on the same row) rather than inventing a new modifier or mnemonic.

- `ScriptModel.js` gained `canRunWithoutInput(script)`: true iff no
  declared param has `required=true` (a `required=true` param with a
  metadata default still routes to the form — the required flag is treated
  as the author's "this is worth a conscious look" signal, not just
  "the engine would reject it if omitted"). This intentionally differs from
  a strict reading of the task's "optional or has a default" wording,
  because the task's own testing notes pair `greet-user.sh` (required
  `name`, which also has `default=friend`) with the "routes to detail"
  behavior — that only holds under the stricter reading. `rowsFor()` now
  stamps every script row with this flag.
- `Menu.qml`: `Shift+Enter` in the browse view (and a new hover-revealed
  "▶" affordance on each row, always visible while the keyboard cursor sits
  on that row) calls `quickActivateCursor()`. For a `canRunWithoutInput`
  row this calls `quickRunScript(id)`, which is `scriptEngine.select(id)` +
  `scriptEngine.runInTerminal(id, {})` — the exact same run path the detail
  view's Run button uses, just with an empty value map (the engine already
  fills in each param's metadata default when a value is omitted, per
  `core.py::_build_argv`). For a row that still needs input, it calls
  `openScript(id, true)`, which flags `pendingFocusFirstParam` and focuses
  the first generated param field once `scriptEngine.script` (fetched
  asynchronously) actually has params — via a `Connections` block on
  `onScriptChanged` plus a `paramRepeater`-scoped `focusField()` per
  delegate (works directly for `TextField`, via the exposed `field` alias
  for `NumberField`; `Dropdown` has no internal focus hook exposed today so
  it falls back to a best-effort `forceActiveFocus()` on its own root).
  Plain `Enter` is unchanged (always opens detail, no focus jump).
- The browse list never leaves `view === "browse"` for a quick run, so the
  cursor position (`selectedIndex`/`cursorActive`) survives automatically —
  no explicit state needed to satisfy "keep the cursor on the row that was
  run".
- Filter hint line updated: "Type to filter — ↑/↓ to move, Enter to open,
  Shift+Enter to run, Esc to close".

Verified live on the real, running desktop (not just qmllint): installed via
`./omarchy-plugin/install.sh` + `omarchy-restart-shell`, then drove the
panel with `wtype` and confirmed via `grim` screenshots + `hyprctl layers
-j`/`hyprctl clients -j`:
  - `hostname-info.sh` (no params) shows the ▶ affordance when the cursor
    sits on its row; Shift+Enter runs it immediately in the floating
    terminal (menu layer hides, `org.omarchy.terminal` client appears,
    output showed real hostname/IP data) with no detail-view detour.
  - Re-opening the menu after that run lands the cursor back on the same
    row, and a plain Enter from there opens its detail view showing the
    freshly recorded "Last run" result.
  - `greet-user.sh` (required `name`, with a default) shows no ▶ affordance;
    Shift+Enter opens its detail view with the "Name to greet" `TextField`
    already focused — confirmed by typing a character and seeing it land
    in that field (`friend` → `friendX`) rather than being swallowed by the
    key catcher.

`make test`, `make lint-qml` (same four pre-existing warning categories
only: `missing-property`, `uncreatable-type`, `unqualified`,
`signal-handler-parameters`), and `make validate` all pass.

Known follow-up: `Dropdown`-backed fields (`boolean`/`choice` params) don't
get a real focus hand-off if they happen to be a script's *first* param —
only `TextField`/`NumberField` do. No bundled or example script currently
has a `boolean`/`choice` param as its first parameter, so this wasn't
visually reachable to confirm either way live. If it turns out to matter,
`Dropdown.qml` (an installed shell component, not part of this repo) would
need to expose its internal `trigger` the same way `NumberField` exposes
`field`, or this repo would need its own focus-forwarding wrapper around it.
