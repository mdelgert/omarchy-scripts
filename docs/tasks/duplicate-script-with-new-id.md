# Task: Duplicate an existing script under a new, unique id

Status: Ready
Type: feature

## Problem

A script's identity is its `@script.id` line, not its file path — this is
deliberate: `id` is the single addressing key used by `run`/`edit`/`delete`,
by last-run history (stored as `<id>.json`), and by discovery's duplicate
detection (`docs/ARCHITECTURE.md`'s discovery/ownership section). IDs must
be globally unique across bundled + workspace + every configured
`scriptDirs` entry; a later duplicate is reported as an explicit `problems`
entry rather than silently shadowed.

That invariant is correct and out of scope to change (see below), but it
creates real friction for a common, legitimate workflow: copying an
existing script to develop or test a variant side by side (e.g. copying
`greet-user.sh` into a `scriptDirs` folder to iterate on a
`greet-user-2`-style variant while comparing it against the original).
Doing this with a plain file copy leaves `@script.id` unchanged, so the
copy collides with the original and shows up as a "duplicate id" problem
instead of a second, independently runnable script — easy to forget, and
confusing when it happens.

## Scope

- Add a duplicate/copy operation to the engine (`src/omarchy_scripts/core.py`):
  - Takes an existing script's `id` (resolved via the existing `find()`)
    and a new target id.
  - Validates the new id against the same `ID_RE` kebab-case rule every
    script id must already satisfy, and rejects a new id that collides
    with any id already returned by `discover()` — a clear error, raised
    before anything is written, never a silent overwrite.
  - Copies the source file into the *workspace* scripts root
    (`workspace_root() / "scripts"`), matching where `create()` already
    scaffolds new scripts — not back into `bundled` or an external
    `scriptDirs` folder, since those aren't guaranteed writable/owned by
    the user.
  - Rewrites only the copied file's `@script.id` line to the new id
    (updating `@script.title` too, if that's straightforward, e.g.
    appending " (copy)"); everything else in the file is byte-for-byte
    identical to the source.
  - Preserves the source file's executable bit.
- Add a `omarchy-scripts copy <id> <new-id>` CLI subcommand wired to this,
  emitting the new file's `path` (mirroring the existing `new` command's
  JSON shape).
- Add a "Duplicate" action in the QML detail view alongside Run/Edit/
  Delete: prompts for (or auto-suggests, e.g. `<id>-copy`) a new id, calls
  this operation, and opens the resulting file for editing the same way
  `+ New script` already does.
- Tests covering: a successful duplicate, a new-id collision rejected
  without writing anything, an invalid new-id shape rejected the same way
  metadata parsing already rejects a bad id, and the original file left
  untouched afterward.

## What done looks like

- [ ] `omarchy-scripts copy <id> <new-id>` produces a new file in the
      workspace scripts directory with only `@script.id` (and title, if
      implemented) changed from the source, and the CLI reports success
      with a `path` in its JSON output.
- [ ] Attempting to copy to an id that already exists anywhere in
      discovery fails clearly, before writing any file.
- [ ] An invalid new id (fails the existing kebab-case rule) is rejected
      the same way any other bad script id already is, without writing a
      file.
- [ ] The QML detail view has a "Duplicate" action producing the same
      result as the CLI, and opens the new file for editing.
- [ ] Tests are added covering the success, id-collision, and
      invalid-id-shape cases, plus confirming the source file is
      untouched.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.
- [ ] `docs/ARCHITECTURE.md` and `docs/SCRIPT_SPEC.md` mention the new
      `copy` command alongside the existing CLI command list.

## Out of scope

- Any relaxation of the "script id must be globally unique across
  discovery" invariant. That invariant is what keeps `run`/`edit`/
  `delete`/last-run addressing simple (a single `<id>` argument, no
  folder/source qualifier needed anywhere) and prevents a script silently
  shadowing another with the same id. This task only removes the manual
  step of remembering to change the id after a manual file copy — it does
  not change how duplicates are detected or reported.
- Improving the wording of the existing duplicate-id `problems` message
  (e.g. suggesting the fix inline) — a separate, smaller task if wanted.
- Copying a script into an external `scriptDirs` folder or the bundled
  root instead of the workspace, since those aren't guaranteed
  writable/owned by the user the way the workspace is.

## Testing notes

- `omarchy-scripts copy greet-user greet-user-2` should produce a new
  file under the workspace `scripts/` directory with `@script.id
  greet-user-2` and otherwise-identical content; confirm
  `omarchy-scripts list`/`validate` shows both scripts afterward with
  zero problems.
- Copying to an id that collides with a bundled/workspace/external
  script should fail without writing a file — confirm the target path
  does not exist afterward.
- Copying with a malformed new id (uppercase, double hyphen, empty)
  should fail without writing a file, the same way a bad `@script.id` is
  already rejected elsewhere.
- Manually verify the QML "Duplicate" action end-to-end in a running
  Omarchy session: duplicate an example script, confirm it appears in the
  browse list as a distinct entry, and that running or editing the copy
  never affects the original's behavior or its last-run history.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
