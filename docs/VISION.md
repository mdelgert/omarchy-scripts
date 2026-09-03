# Vision: small, inspectable scripts

`omarchy-scripts` v1 is a browser and runner for ordinary Bash scripts with self-describing header comments. It lets people browse, edit, delete, and run those scripts without turning each one into a miniature application.

## Why it is deliberately simple

Many useful scripts only report information or perform a focused action. They do not have a meaningful `check`, `apply`, or `undo` lifecycle: a script might fetch JSON, print network diagnostics, or open an editor. In v1, a script is therefore just a Bash file. Its `@script.*` and `@param` comments describe it; the engine turns supplied parameter values into `--name value` arguments and runs it. No action-dispatch protocol, mandatory backup, conflict detection, or lint gate is imposed.

The optional helper library only removes routine argument-parsing boilerplate. It is not a framework and scripts may run perfectly well without it.

## What waits for v2

AI chat and AI-assisted authoring, automatic repair loops, richer history, backup/restore and undo helpers, conflict detection, trust/provenance systems, and stronger linting may be added later as opt-in layers. They are not hidden requirements for v1 authors.

## Things v1 must keep

- The engine emits a stable, versioned, frontend-neutral JSON contract. A future TUI, web client, or v2 authoring layer must be able to use the same discovery and execution boundary.
- File-oriented control is core: users can see a script's path, edit it, make a new workspace script, delete it, and run it. The UI must stay close to the executable source rather than obscuring it.
