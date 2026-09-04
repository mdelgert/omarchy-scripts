# Task: Configurable menu keybindings + on-screen key hints

Status: Draft
Type: feature

## Problem

The browse/detail keyboard shortcuts (`↑`/`↓`, `Enter`, `Shift+Enter`,
`Escape`/`Left`, `F5`, Super+F for fullscreen) are all hardcoded `Qt.Key_*`
checks in `Menu.qml`'s single `keyCatcher` (`Keys.onPressed`), plus one
Hyprland binding in `~/.config/hypr/bindings.lua`. Two things worth fixing:

1. A user who wants `j`/`k` instead of arrows, or a different quick-run
   modifier, has to go edit QML directly — there's no supported way to
   remap a key.
2. Even with the current, fixed set of keys, the UI only explains them in
   one small hint line at the top ("Type to filter — ↑/↓ to move, Enter to
   open, Shift+Enter to run, Esc to close") and nowhere near the actual
   controls it's describing — e.g. nothing on the Run/Edit/Delete buttons
   themselves indicates a key can trigger them.

## Design (keep this simple — same spirit as `configurable-script-directories.md`)

- Keybindings live in the **same** settings file that task introduces
  (`~/.config/omarchy-scripts/config.json`), as a `keys` object mapping a
  named action to a key spec, e.g.:

  ```json
  {
    "keys": {
      "moveUp": "Up",
      "moveDown": "Down",
      "open": "Return",
      "quickRun": "Shift+Return",
      "back": "Escape",
      "reload": "F5"
    }
  }
  ```

  A key spec is a plain string (`"Shift+Return"`), not a QML/Qt symbol —
  parse it with a small, well-tested `"Modifier+Modifier+Key"` parser, so
  the config file stays editable by hand or by a provisioning script, not
  just by a GUI that understands `Qt.Key_*` enums.
- Every action gets a **built-in default** identical to today's hardcoded
  behavior — an empty/missing `keys` section must behave exactly like the
  current code. This is a remapping feature, not a new default UX.
- **No settings UI for remapping**, same rationale as the sibling
  directories task: edit the JSON (by hand, or via a future `omarchy-scripts
  config set-key <action> <spec>` CLI subcommand, if that ends up worth
  adding — start with just the file, add the CLI convenience later if
  hand-editing turns out to be annoying in practice).
- **Do** show, in the GUI itself, which key currently triggers each visible
  action — this part *is* GUI work, just read-only GUI work:
  - The existing hint line stays, but should render from the resolved
    keymap (so if a user remaps `quickRun`, the hint line updates too)
    instead of a hardcoded string.
  - Each detail-view button (`Run`, `Edit`, `Delete`) should visually
    surface its mnemonic, e.g. underline or otherwise highlight the `R` in
    `Run`, matching whichever key currently activates it — this only makes
    sense for actions that don't already have a dedicated keybinding
    (`Run` doesn't currently have one *inside* the detail view, only
    `Shift+Enter` on the browse row before opening it) — worth deciding
    during implementation whether the detail view should also gain direct
    single-letter activation (`r`/`e`/`d`) once focus isn't in a text
    field, so the visual hint has something real to point at.
  - The row's hover-revealed "▶" affordance already visually implies
    "there's a shortcut for this row" — consider a small tooltip or
    persistent caption showing the actual resolved key next to it instead
    of leaving the user to infer it's `Shift+Enter` from the hint line
    alone.

## Scope

- Define the fixed set of remappable actions (`moveUp`, `moveDown`, `open`,
  `quickRun`, `back`, `reload`, and whatever `Menu.qml` currently hardcodes
  — enumerate them precisely from the current `Keys.onPressed`, don't
  invent new ones).
- Add a key-spec parser/formatter (string ⇄ `Qt.Key_*` + modifier mask) with
  unit-testable logic kept out of QML where possible (a `.js` helper next
  to `ScriptModel.js`, not inline in `Menu.qml`).
- Wire `Menu.qml`'s `keyCatcher` to check against the resolved keymap
  instead of literal `Qt.Key_*` comparisons.
- Render the hint line and button mnemonics from the same resolved keymap.
- Document the `keys` config schema (defaults, spec syntax, precedence)
  alongside wherever `configurable-script-directories.md` documents
  `scriptDirs` — same file, same section of the architecture docs.
- Leave the Super+F Hyprland-level fullscreen binding alone — that's a
  compositor keybind in `bindings.lua`, a different layer than in-menu
  QML keys, and out of scope here.

## What done looks like

- [ ] Default behavior (no `keys` config present) is pixel-for-pixel /
      keystroke-for-keystroke identical to today.
- [ ] At least one remapped action (e.g. `moveDown` → `j`) is verified live
      to actually change behavior after a restart.
- [ ] The hint line and any button mnemonics reflect the resolved keymap,
      not a hardcoded string — verified by remapping something and seeing
      the on-screen text change to match.
- [ ] Unit tests cover the key-spec parser (valid specs, modifier
      combinations, and at least one invalid-spec-falls-back-to-default
      case).
- [ ] `make test`, `make lint-qml`, and `make validate` pass.
- [ ] Docs updated (schema + syntax) in the same place as the script-dirs
      config, so there's one settings-file reference, not two.

## Out of scope

- A settings UI for remapping keys — explicitly rejected, same as the
  sibling directories task.
- Remapping the Hyprland-level Super+F binding — that already lives in the
  user's own `~/.config/hypr/bindings.lua` and is already user-editable by
  Hyprland's own convention; don't duplicate that mechanism here.
- Per-script custom keybindings (e.g. one script gets its own hotkey) —
  a different, bigger feature; this task is only about the fixed menu
  actions.

## Testing notes

Remap `quickRun` to something distinctive (e.g. `Ctrl+R`) and confirm live
that: the old `Shift+Enter` no longer triggers it, the new binding does, and
the hint line's text updated to say so — this exercises the full
config-read → keymap-resolve → QML-render loop in one pass.

## Report

Fill in when finished: what changed, decisions made, limitations, and
useful follow-ups.
