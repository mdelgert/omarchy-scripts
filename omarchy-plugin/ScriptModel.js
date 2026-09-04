.pragma library

// Presentation helpers for the Omarchy Scripts menu.
//
// Pure functions over data the engine already normalized. This file must
// never parse a script file, validate a parameter, or build a command line:
// the `omarchy-scripts` engine owns all of that and stays the source of
// truth. What lives here is only "how should this be shown".

function pathFromUrl(url) {
  var text = String(url || "")
  if (text.indexOf("file://") !== 0) return ""
  text = text.slice("file://".length)
  try {
    text = decodeURIComponent(text)
  } catch (e) {
    return ""
  }
  while (text.length > 1 && text.charAt(text.length - 1) === "/") {
    text = text.slice(0, -1)
  }
  return text
}

function parentDir(path) {
  var text = String(path || "")
  var cut = text.lastIndexOf("/")
  if (cut <= 0) return text
  return text.slice(0, cut)
}

// Decode one `--json`-shaped response. The engine stamps every payload with
// schemaVersion; anything else is treated as unusable rather than guessed at.
function parseResponse(text, expectedVersion) {
  var raw = String(text || "").trim()
  if (!raw) return { ok: false, error: "the scripts engine returned no output", data: null }
  var data
  try {
    data = JSON.parse(raw)
  } catch (e) {
    return { ok: false, error: "the scripts engine returned output that is not JSON", data: null }
  }
  if (!data || typeof data !== "object") {
    return { ok: false, error: "unexpected engine response", data: null }
  }
  if (data.schemaVersion !== expectedVersion) {
    return {
      ok: false,
      data: null,
      error: "engine speaks schema version " + String(data.schemaVersion)
        + ", this plugin understands " + String(expectedVersion) + " — update the plugin"
    }
  }
  if (typeof data.error === "string" && data.error) {
    return { ok: false, error: data.error, data: data }
  }
  return { ok: true, error: "", data: data }
}

function firstLine(text, limit) {
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/^\s+|\s+$/g, "")
    if (line) return truncate(line, limit || 160)
  }
  return ""
}

function truncate(text, limit) {
  var s = String(text || "")
  return s.length > limit ? s.slice(0, limit - 1) + "…" : s
}

// Group a flat script list by category, for the browse view.
function groupByCategory(scripts) {
  var groups = []
  var byName = {}
  for (var i = 0; i < scripts.length; i++) {
    var s = scripts[i]
    var name = s.category || "Uncategorized"
    if (!byName[name]) {
      byName[name] = { category: name, scripts: [] }
      groups.push(byName[name])
    }
    byName[name].scripts.push(s)
  }
  groups.sort(function(a, b) { return a.category.localeCompare(b.category) })
  return groups
}

function matchesFilter(script, text) {
  if (!text) return true
  var haystack = (script.title + " " + script.description + " " + (script.tags || []).join(" ")).toLowerCase()
  return haystack.indexOf(text) >= 0
}

// Whether a script can be launched straight from the browse list with no
// detail-view detour: true for zero params, or when every declared param
// stops short of `required=true`. A `required=true` param routes to the
// detail view even if it also carries a metadata default (see
// SCRIPT_SPEC.md) — the required flag is the author's signal that this
// value is worth a conscious look, not just something to skip past.
function canRunWithoutInput(script) {
  var params = (script && script.params) || []
  for (var i = 0; i < params.length; i++) {
    if (String(params[i].required) === "true") return false
  }
  return true
}

// Flatten a script list to the row list the browse view renders: a category
// header followed by its scripts, keyboard-navigable in one pass. Every row
// carries the same keys so the delegate never binds undefined.
function rowsFor(scripts, filterText) {
  var text = String(filterText || "").toLowerCase()
  var filtered = (scripts || []).filter(function(s) { return matchesFilter(s, text) })
  var rows = []
  var currentCategory = null
  for (var i = 0; i < filtered.length; i++) {
    var s = filtered[i]
    var category = String(s.category || "Uncategorized")
    if (category !== currentCategory) {
      currentCategory = category
      rows.push({ kind: "header", label: category, scriptId: "", icon: "", canRunWithoutInput: false })
    }
    rows.push({
      kind: "script",
      label: String(s.title || s.id),
      detail: String(s.description || ""),
      scriptId: String(s.id),
      icon: String(s.icon || ""),
      canRunWithoutInput: canRunWithoutInput(s)
    })
  }
  return rows
}

function firstSelectableRow(rows) {
  for (var i = 0; i < (rows || []).length; i++) {
    if (rows[i].kind === "script") return i
  }
  return -1
}

// Move the cursor to the next selectable row, skipping category headers.
function nextSelectableRow(rows, from, step) {
  var list = rows || []
  if (list.length === 0) return -1
  var i = from
  for (var guard = 0; guard < list.length; guard++) {
    i += step
    if (i < 0 || i >= list.length) return from
    if (list[i].kind === "script") return i
  }
  return from
}
