# Task: fix README's example keybinding — it shadows Hyprland's own SUPER+F

Status: Ready
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

## What done looks like

- [ ] `README.md`'s example keybind uses a combo verified free of conflicts
      at merge time, with the check command/steps shown.
- [ ] The caution note about checking for conflicts before binding a new
      global key is present and easy to spot.
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

## Report

Fill in when finished: what changed, decisions made, limitations, and
useful follow-ups. Set Status to Done after merge, then move the
completed file to `docs/tasks/done/`.
