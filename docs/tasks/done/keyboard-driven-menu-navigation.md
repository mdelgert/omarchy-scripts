# Keyboard-driven menu navigation

Status: Done
Reported by: live-desktop screenshot review, 2026-09-03

## Problem

`omarchy-plugin/Menu.qml` currently only supports mouse interaction (click to
select a script, click a button to run/edit/delete). Every other Omarchy
panel/menu is keyboard-first: arrow keys or j/k move a highlighted "cursor"
through the list, Enter activates it, Escape closes the panel, and mouse
hover is treated as just another way to move that same cursor
(`hasCursor`/`hovered(bool)` on `Button`, `Dropdown`, etc. all exist
specifically to support this). Not following that pattern makes this plugin
feel foreign next to the rest of the shell.

## What "done" looks like

Reference the real, installed Omarchy shell components before writing any
code — do not guess at the API:

- `/usr/share/omarchy/shell/Ui/PanelController.qml` and `Panel.qml` — the
  shell's own keyboard-cursor model for a list + detail panel.
- `/usr/share/omarchy/shell/Ui/PanelKeyCatcher.qml` — how a panel captures
  j/k/arrows/Enter/Escape without stealing focus from a focused TextField.
- Any first-party plugin under `/usr/share/omarchy/shell/plugins/*/Panel.qml`
  that already implements a browse list + detail view (several exist — read
  a couple end to end, don't just skim one).

Required behavior:

1. Opening the menu puts keyboard focus on the browse list with a visible
   cursor on the first script (or the first result if a filter is active).
2. Up/Down (and j/k, matching the rest of the shell) move the cursor across
   category groups without extra modifier keys.
3. Enter opens the detail view for the highlighted script; Escape from the
   detail view returns to browse (mirrors the existing `‹ Back` button, does
   not replace it).
4. Escape from the browse view closes the menu (mirrors the existing
   `Close` button).
5. In the detail view, Tab/Shift+Tab (or the shell's normal convention, check
   the reference panels) moves the cursor between Run / Edit / Delete /
   parameter fields; Enter activates the focused control.
6. Typing text while the browse list has focus still reaches the filter
   `TextField` — don't let a global key catcher swallow printable characters
   meant for search-as-you-type. Check how an existing searchable list
   handles this (`SearchableDropdown` or similar) rather than reinventing it.
7. Mouse interaction keeps working exactly as it does today — this is
   additive, not a replacement.

## Constraints

- This is a visual/interactive feature: iterate against the real, installed
  Omarchy shell on this machine, not qmllint alone. `qmllint` cannot verify
  focus or key handling.
- After any structural QML change, run `omarchy-restart-shell` before
  re-testing — `omarchy-shell shell rescanPlugins` does not reliably
  recompile changed QML (confirmed during scaffolding).
- Take a screenshot (`grim`) after each meaningful change and actually look
  at it. Confirm the compositor layer for this plugin
  (`omarchy-scripts-menu`) opens via `hyprctl layers -j` before assuming a
  change rendered.
- Don't regress the existing mouse flow or the recent Run/Edit fixes (Run
  hands off to `omarchy-launch-floating-terminal-with-presentation`, Edit to
  `omarchy-launch-editor`, both via argv arrays — never build a shell
  string from script metadata or user input).

## Out of scope

- AI chat / authoring (deferred to v2, see repo root context).
- Anything about the engine (`src/omarchy_scripts`) — this is QML-only.

## Report

Implemented directly against the reference pattern in
`omarchy-recipes/omarchy-plugin/Menu.qml` + `RecipeModel.js` (this sibling
repo already solves the exact same problem, so it was used instead of the
stock shell panels).

- `ScriptModel.js` gained `rowsFor`/`firstSelectableRow`/`nextSelectableRow`/
  `matchesFilter`, ported from `RecipeModel.js`.
- `Menu.qml` was rewritten around a flat `rows` list + a single `keyCatcher`
  `Item` (`Keys.onPressed`, `Keys.priority: Keys.AfterItem`): Up/Down move
  the cursor across category groups (headers are skipped), Enter/Right open
  the detail view, Escape/Left go back-then-close, typing reaches the filter
  field, F5 reloads. `ConfirmDialog.handleKey` wires the delete-confirmation
  modal into the same key catcher.
- Verified live via `wtype -k Down/Down/Return/Escape/Escape` +
  `grim`/`hyprctl layers -j` screenshots on the real, running desktop (not
  just `qmllint`): cursor highlight moves, Enter opens the highlighted
  script's detail view, Escape returns to browse then closes the panel,
  fullscreen mode (`{"fullscreen": true}` payload, bound to Super+F) renders
  correctly full-panel.
- Mouse interaction is unaffected — all existing click handlers were kept
  as-is; the key catcher is additive.

Known gap (not blocking, left for a follow-up if it turns out to matter in
practice): item 5, Tab/Shift-Tab moving focus between the Run/Edit/Delete
buttons and generated parameter fields inside the detail view, relies on
Qt Quick's default focus-chain order rather than an explicit
`KeyNavigation.tab` wiring. `wtype -k Tab` was exercised live but the
buttons/fields in this theme have no visible focus ring, so the actual tab
order could not be visually confirmed from a screenshot. If a future session
notices Tab skipping/looping oddly in the detail view, add explicit
`KeyNavigation.tab`/`KeyNavigation.backtab` between Run → Edit → Delete →
each parameter field, matching whatever `omarchy-recipes`' detail view does
if it has the same requirement.
