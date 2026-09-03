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
