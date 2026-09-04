# Task: capture application screenshots for documentation

Status: Ready
Type: chore

## Problem

`docs/` has no visual reference for the `omarchy-plugin` QML frontend (the
"application" end users actually see and interact with). Every doc
(`README.md`, `docs/ARCHITECTURE.md`) describes the browse list, the
detail/parameter view, and script execution/output only in prose. A new
contributor or user has no way to see what the menu actually looks like
without installing the plugin and launching it themselves in a live
Hyprland session.

## Scope

- In a real Omarchy/Hyprland session, launch the `omarchy-plugin` the
  normal way a user would (bar icon / configured keybinding) and, using
  `grim`, capture full-screen screenshots of each primary application
  state:
  - The initial browse/list view (script list as shown on open).
  - A script's detail/parameter-entry view (a script with at least one
    `@param` selected, showing its input fields).
  - A script actively running / showing its output.
  - The settings/config view, if the plugin exposes one as a distinct
    screen.
- Save the captured images as PNGs under a new `docs/images/` directory,
  using descriptive kebab-case filenames (e.g. `browse-list.png`,
  `script-detail.png`, `run-output.png`).
- Crop/resize each image as needed so files stay reasonably small (avoid
  committing multi-megabyte screenshots of an entire multi-monitor
  desktop when only the menu itself is relevant).
- Add a "Screenshots" section to `README.md` embedding each image with a
  one-line caption describing what it shows.

## What done looks like

- [ ] `docs/images/` contains one PNG per captured view, each reasonably
      sized (target: comfortably under 500KB per image; crop/downscale
      if `grim`'s raw output is larger).
- [ ] `README.md` has a "Screenshots" section that renders each image
      with a short caption, verified by previewing the rendered
      markdown.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done (expected to be unaffected by this
      doc-only change, but still run to confirm no regression).

## Out of scope

- Automated/CI screenshot generation or visual regression testing.
- Screenshots of every individual bundled example script's own output —
  only the core application chrome/views listed above.
- Any UI redesign or behavior change made in service of getting a
  "nicer" screenshot.

## Testing notes

- This task fundamentally requires a real Omarchy/Hyprland desktop
  session with `grim` and the `omarchy-plugin` actually running and
  visible — it cannot be completed by a sandboxed subagent restricted to
  only its own worktree directory (see
  `skills/task-workflow/SKILL.md`'s note on live QML/UI verification).
  If that access isn't available when this task is picked up, say so
  explicitly in the Report rather than fabricating or skipping images.
- After capturing, sanity-check each image actually shows the intended
  view (no compositor artifacts, no unrelated windows/notifications in
  frame) before committing it.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
