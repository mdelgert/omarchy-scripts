# Task: fix README's example keybinding, and audit all default hotkeys for conflicts

Status: Done
Type: bug

## Problem

`README.md`'s example keybinding for opening the scripts menu fullscreen
uses `SUPER + F`:

```lua
o.bind("SUPER + F", "Scripts (fullscreen)",
  "omarchy-shell shell toggle io.github.mdelgert.omarchy-scripts '{\"fullscreen\":true}'")
```

But `SUPER + F` is already Omarchy's own **default** binding for "fullscreen
the currently focused window"
(`/usr/share/omarchy/default/hypr/bindings/tiling.lua:7`:
`o.bind("SUPER + F", "Full screen", hl.dsp.window.fullscreen({ mode =
"fullscreen" }))`). A user's own `~/.config/hypr/bindings.lua` is loaded
after the defaults, so pasting this example verbatim silently shadows the
system default everywhere: pressing `SUPER + F` in a terminal, browser, or
any other focused window no longer fullscreens it — it pops open the
scripts menu instead. This was reported as "it seems to have taken over".
This repo doesn't own the user's live `~/.config/hypr/bindings.lua` (we
can't push a fix into it), but the *example we tell people to copy* picked
an already-taken combo, which is our bug to fix.

Also checked other likely-looking alternatives — all already taken by
Omarchy defaults too: `SUPER + SHIFT + F` (file manager), `SUPER + ALT + F`
(full width), `SUPER + ALT + SHIFT + F` (file manager, cwd). Don't just
swap in another guessed combo without checking.

Separately, this plugin has its own **internal** hotkeys — `KEY_ACTION_DEFAULTS`
in `core.py`, only active while the menu panel itself has focus (a
different system entirely from the global `SUPER+F` toggle above; these
are QML key handlers, not Hyprland binds, and are already user-configurable
via `configure-omarchy-scripts.sh`):

```
moveUp: Up, moveDown: Down, open: Return, quickRun: Shift+Return,
back: Escape, reload: F5, run: R, edit: E, delete: D
```

These don't get added to Hyprland, but Hyprland global binds fire
regardless of focused-window content (unless the shortcuts-inhibit
protocol is engaged for that window), so a bare `F5`, `Escape`, `R`, `E`,
or `D` press *could* theoretically still be swallowed by a conflicting
global Hyprland bind before this panel ever sees it. That hasn't been
verified — do so as part of this task rather than assuming it's fine.
The user only actually needs a minimal set day to day (back/Escape,
arrow-key navigation, and one run key) — reducing surface area is
preferable to keeping unused defaults around if any turn out to conflict.

## Scope

- Change `README.md`'s example to a combo confirmed free via
  `omarchy menu keybindings --print` (or by grepping
  `/usr/share/omarchy/default/hypr/bindings/*.lua` and the user's own
  `~/.config/hypr/bindings.lua`) at the time this is implemented —
  defaults can change over Omarchy versions, so re-verify rather than
  trusting this task file's findings above as still current.
- Add a short caution note directly above the example in `README.md`:
  before adding *any* global keybind (not just this one), run
  `omarchy menu keybindings --print` and confirm the chosen combo isn't
  already bound — a later-defined binding silently shadows an earlier one
  system-wide, with no warning.
- If a conflict-free letter combo isn't available for "Scripts", it's
  fine to suggest a combo that isn't `SUPER + <letter>` at all (e.g. a
  function key or a three-modifier chord) rather than force-fitting one.
- Audit every `KEY_ACTION_DEFAULTS` entry (`moveUp`, `moveDown`, `open`,
  `quickRun`, `back`, `reload`, `run`, `edit`, `delete`) against Omarchy's
  default Hyprland binds (`/usr/share/omarchy/default/hypr/bindings/*.lua`)
  for any bare-key (no-`SUPER`) global bind that would swallow the same
  key before the menu panel receives it — e.g. does anything globally
  bind a bare `F5`, `Escape`, `R`, `E`, or `D`? Report exactly what you
  find, conflict or not.
- If any default is found to actually conflict, either pick a different
  default for that action or document the conflict clearly rather than
  silently leaving it broken.
- Confirm (or fix) that only the essential, distinct actions have a
  default at all — don't invent extra default keybindings beyond what's
  already in `KEY_ACTION_DEFAULTS` for this task; the goal is verifying/
  trimming the *existing* set for conflicts and necessity, not adding new
  bindable actions.

## What done looks like

- [ ] `README.md`'s example keybind uses a combo verified free of conflicts
      at merge time, with the check command/steps shown.
- [ ] The caution note about checking for conflicts before binding a new
      global key is present and easy to spot.
- [ ] Every `KEY_ACTION_DEFAULTS` entry has been checked against Omarchy's
      default Hyprland binds for a bare-key conflict, with findings
      recorded in the Report (even if the finding is "no conflicts").
- [ ] Any confirmed conflict is either resolved (different default key)
      or explicitly documented as a known limitation.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done (this is a docs-only fix, so these should be
      unaffected, but still run them per the standard definition of done).

## Out of scope

- Touching the user's actual live `~/.config/hypr/bindings.lua` — that's
  their own machine's config, not something this repo manages or should
  script changes into.
- Any mechanism in `omarchy-scripts` itself to detect/warn about
  keybinding conflicts — Hyprland/Omarchy owns keybindings entirely; this
  repo only ever suggests one example line in its README.
- Adding new bindable actions/menu features — this task only reviews and,
  if needed, adjusts the *defaults* for actions that already exist.

## Report

**Changed:**
- `README.md`: replaced the `SUPER + F` example with `SUPER + R`, and
  added a "check for conflicts first" note (`omarchy menu keybindings
  --print`, or grep the default binds + your own `bindings.lua`) directly
  above the example.
- `docs/tasks/persist-default-fullscreen-setting.md`: updated its two
  `SUPER + F` references to `SUPER + R` for consistency with the new
  README example (it isn't implemented yet, so this is a same-day
  correction, not a behavior change).

**Verified `SUPER + R` is free:** extracted every `o.bind(...)`/
`hl.bind(...)` key-combo string from `/usr/share/omarchy/default/hypr/bindings/*.lua`
and this machine's own `~/.config/hypr/bindings.lua`. `SUPER + R` (and
`SUPER + A/B/D/E/I/M/N/Q/U/Y/Z`, for what it's worth) has no default or
user-level bind anywhere. Previously-considered alternatives
(`SUPER+SHIFT+F`, `SUPER+ALT+F`, `SUPER+ALT+SHIFT+F`) really are all
taken, confirming the task file's original note.

**Internal `KEY_ACTION_DEFAULTS` audit** (`moveUp: Up`, `moveDown: Down`,
`open: Return`, `quickRun: Shift+Return`, `back: Escape`, `reload: F5`,
`run: R`, `edit: E`, `delete: D`) — checked each for a conflicting
*bare* (no-modifier) global Hyprland bind, since those are the only kind
that could fire ahead of a focused QML panel:
- **No conflicts found** for any of them. Grepping the full Hyprland
  config tree for bare `F5`, `Escape`, `R`, `E`, `D`, `Up`, `Down`, or
  `Return` binds turned up only two unrelated bare binds: `F9`
  (`voxtype` push-to-talk dictation — different key, no overlap) and a
  bare `RETURN`/arrow-key/`TAB` set that Omarchy registers *only while a
  screenshot-region selection layer is open* (`utilities.lua`, added on
  `layer.opened` / presumably removed on close) — a narrow, self-scoped,
  temporary case that would only matter if the scripts menu and an
  active screenshot-selection overlay were both trying to claim
  keyboard focus simultaneously, which isn't a realistic default
  conflict.
- Conclusion: the existing internal hotkey defaults do not need
  changing. No default was removed — every action in
  `KEY_ACTION_DEFAULTS` already had a distinct, non-conflicting key, so
  there was nothing to trim per the "minimum keys" request beyond
  confirming the existing minimal set is in fact conflict-free.

**Limitations / follow-ups:** this audit is a point-in-time check against
the Omarchy version installed on this machine; Omarchy's own default
binds can change release to release, so the same conflict-check step
(now documented in `README.md`) should be re-run before adding any
*new* global keybind in the future, rather than trusting this snapshot
indefinitely.
