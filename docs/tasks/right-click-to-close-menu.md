# Task: right-click closes the Scripts menu

Status: Ready
Type: feature

## Problem

The Scripts menu currently only closes via Escape or a left-click on the
background scrim outside the card (`omarchy-plugin/Menu.qml`'s scrim
`MouseArea`, which only handles `Qt.LeftButton` by default). There's no
right-click shortcut to close/exit the menu, even though the bar icon that
opens it (`omarchy-plugin/BarWidget.qml`) already receives and discriminates
mouse buttons — its `WidgetButton.onPressed(mouseButton)` handler explicitly
ignores anything other than `Qt.LeftButton`
(`if (mouseButton !== Qt.LeftButton) return`). Right-click-to-dismiss is a
common, low-friction pattern for popup/menu UIs and would give users a
faster way to exit than aiming for the scrim or reaching for Escape.

**Feasibility confirmed before writing this task:** this plugin's
`Menu.qml` surface is a real Wayland layer-shell `PanelWindow`
(`WlrLayershell.layer: WlrLayer.Overlay`) using plain QtQuick `MouseArea`s
for input — `MouseArea.acceptedButtons` supports `Qt.RightButton` natively,
no special compositor/Quickshell support is required. The bar icon's
`WidgetButton.onPressed` signature already passes `mouseButton`, proving
button discrimination is already plumbed through at that layer too. Right
click is not blocked by anything in this codebase or its dependencies.

## Scope

- In `omarchy-plugin/Menu.qml`, make right-click close the menu, in at
  least one (ideally both, for consistency) of these places:
  - The scrim `MouseArea` at the top of the `PanelWindow` (currently
    `onClicked: root.close()`, implicitly left-click only) — extend
    `acceptedButtons` to include `Qt.RightButton` and close on either
    button, OR add a second explicit handler for the right button if the
    existing `onClicked` semantics don't fit cleanly.
  - The card's own background (not on top of interactive rows/buttons/
    inputs — right-clicking a script row or a text field should not be
    hijacked into a global close if that would surprise users reaching
    for a native context-menu-like action later; scope this task to
    "background/chrome" areas only, consistent with how left-click-to-
    close already only applies to the scrim, not row content).
- In `omarchy-plugin/BarWidget.qml`, decide (and document the decision in
  the Report) whether right-clicking the bar icon itself should also
  close the menu if it's open — this is optional/secondary to the
  in-menu scrim behavior above; if implemented, it must not open the menu
  when it's closed (that's still left-click's job).
- Keep Escape and click-outside-with-left-click working exactly as they
  do today; this task only adds a new way to close, not replaces any
  existing one.

## What done looks like

- [ ] Right-clicking the menu's background/scrim area closes the menu,
      verified live in an Omarchy/Hyprland session.
- [ ] Right-clicking inside the card on interactive content (a script row,
      a button, a text field) does not unexpectedly close the menu if
      that would conflict with scope decided above — confirm the chosen
      boundary works as intended.
- [ ] Escape and left-click-on-scrim still close the menu exactly as
      before (no regression).
- [ ] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.
- [ ] `docs/ARCHITECTURE.md` or inline comments updated only if this
      introduces a new interaction pattern worth documenting for future
      contributors.

## Out of scope

- Any actual native/OS-level context menu (a list of right-click actions)
  — this task is only about right-click-to-close, not building a context
  menu widget.
- Changing the bar icon's left-click open behavior.
- Adding right-click behavior to individual script rows/action buttons
  (e.g. a "right-click to duplicate" shortcut) — out of scope unless a
  future task asks for it specifically.

## Testing notes

- Live in a real Omarchy/Hyprland session: open the menu, right-click the
  background/scrim, confirm it closes. Repeat for left-click and Escape
  to confirm no regression.
- If a mouse isn't available in the test environment (see
  `docs/tasks/done/duplicate-script-with-new-id.md`'s Report for this
  repo's documented sandbox limitation around synthetic mouse
  input/`hyprctl dispatch`), state this limitation plainly in the Report
  rather than skipping verification silently — a partial/CLI-level
  equivalent check (e.g. confirming the QML logic path via code
  inspection or a unit-testable helper, if one is extracted) is a
  reasonable fallback, but say so explicitly.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
