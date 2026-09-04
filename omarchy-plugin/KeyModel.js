.pragma library

var ACTIONS = [
  "moveUp",
  "moveDown",
  "open",
  "quickRun",
  "back",
  "reload",
  "run",
  "edit",
  "delete"
]

var DEFAULT_SPECS = {
  moveUp: "Up",
  moveDown: "Down",
  open: "Return",
  quickRun: "Shift+Return",
  back: "Escape",
  reload: "F5",
  run: "R",
  edit: "E",
  delete: "D"
}

var DEFAULT_EXTRA_SPECS = {
  open: ["Right"],
  back: ["Left"]
}

var MODIFIER_ORDER = ["Ctrl", "Alt", "Shift", "Super", "Meta"]

var MODIFIER_ALIASES = {
  alt: "Alt",
  control: "Ctrl",
  ctrl: "Ctrl",
  meta: "Meta",
  shift: "Shift",
  super: "Super"
}

var KEY_ALIASES = {
  backspace: "Backspace",
  "delete": "Delete",
  down: "Down",
  end: "End",
  enter: "Return",
  esc: "Escape",
  escape: "Escape",
  home: "Home",
  left: "Left",
  pagedown: "PageDown",
  pageup: "PageUp",
  return: "Return",
  right: "Right",
  space: "Space",
  tab: "Tab",
  up: "Up"
}

var SPECIAL_KEYS = {
  Backspace: [Qt.Key_Backspace],
  Delete: [Qt.Key_Delete],
  Down: [Qt.Key_Down],
  End: [Qt.Key_End],
  Escape: [Qt.Key_Escape],
  Home: [Qt.Key_Home],
  Left: [Qt.Key_Left],
  PageDown: [Qt.Key_PageDown],
  PageUp: [Qt.Key_PageUp],
  Return: [Qt.Key_Return, Qt.Key_Enter],
  Right: [Qt.Key_Right],
  Space: [Qt.Key_Space],
  Tab: [Qt.Key_Tab],
  Up: [Qt.Key_Up]
}

var DISPLAY_KEYS = {
  Down: "↓",
  Escape: "Esc",
  Left: "←",
  Return: "Enter",
  Right: "→",
  Up: "↑"
}

function modifierMask(modifiers) {
  var mask = 0
  for (var i = 0; i < modifiers.length; i++) {
    if (modifiers[i] === "Ctrl") mask |= Qt.ControlModifier
    else if (modifiers[i] === "Alt") mask |= Qt.AltModifier
    else if (modifiers[i] === "Shift") mask |= Qt.ShiftModifier
    else if (modifiers[i] === "Super" || modifiers[i] === "Meta") mask |= Qt.MetaModifier
  }
  return mask
}

function normalizeEventModifiers(modifiers) {
  return modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier | Qt.MetaModifier)
}

function normalizeKeyToken(token) {
  var text = String(token || "").trim()
  if (!text) return ""
  var alias = KEY_ALIASES[text.toLowerCase()]
  if (alias) return alias
  if (/^f([1-9]|[12][0-9]|3[0-5])$/i.test(text)) return text.toUpperCase()
  if (text.length === 1 && !/\s/.test(text)) return /[a-z]/i.test(text) ? text.toUpperCase() : text
  return ""
}

function keyCodesForToken(token) {
  if (SPECIAL_KEYS[token]) return SPECIAL_KEYS[token]
  if (/^F([1-9]|[12][0-9]|3[0-5])$/.test(token)) {
    return [0x01000030 + parseInt(token.slice(1), 10) - 1]
  }
  if (token.length === 1) {
    return [token.charCodeAt(0)]
  }
  return []
}

function displayForKey(token) {
  return DISPLAY_KEYS[token] || token
}

function parseKeySpec(spec) {
  var raw = String(spec || "").trim()
  if (!raw) return null

  var parts = raw.split("+").map(function(part) { return part.trim() })
  if (parts.some(function(part) { return !part })) return null

  var modifiers = []
  var seen = {}
  for (var i = 0; i < parts.length - 1; i++) {
    var modifier = MODIFIER_ALIASES[String(parts[i]).toLowerCase()]
    if (!modifier || seen[modifier]) return null
    seen[modifier] = true
    modifiers.push(modifier)
  }

  modifiers.sort(function(a, b) {
    return MODIFIER_ORDER.indexOf(a) - MODIFIER_ORDER.indexOf(b)
  })

  var keyToken = normalizeKeyToken(parts[parts.length - 1])
  if (!keyToken) return null
  var keyCodes = keyCodesForToken(keyToken)
  if (keyCodes.length === 0) return null

  var display = modifiers.concat([displayForKey(keyToken)]).join("+")
  return {
    spec: modifiers.concat([keyToken]).join("+"),
    display: display,
    modifiers: modifierMask(modifiers),
    key: keyToken,
    keyCodes: keyCodes
  }
}

function bindingHint(binding) {
  if (!binding) return ""
  return binding.variants.map(function(variant) { return variant.display }).join("/")
}

function buttonText(label, binding) {
  var hint = bindingHint(binding)
  return hint ? (label + " · " + hint) : label
}

function defaultSpec(action) {
  return DEFAULT_SPECS[action] || ""
}

function resolve(keySpecs) {
  var raw = keySpecs || {}
  var resolved = {}
  for (var i = 0; i < ACTIONS.length; i++) {
    var action = ACTIONS[i]
    var spec = typeof raw[action] === "string" && raw[action] ? raw[action] : defaultSpec(action)
    var primary = parseKeySpec(spec) || parseKeySpec(defaultSpec(action))
    var variants = [primary]
    var extras = DEFAULT_EXTRA_SPECS[action] || []
    if (primary && primary.spec === defaultSpec(action)) {
      for (var j = 0; j < extras.length; j++) {
        var extra = parseKeySpec(extras[j])
        if (extra) variants.push(extra)
      }
    }
    resolved[action] = {
      spec: primary ? primary.spec : "",
      display: primary ? primary.display : "",
      variants: variants
    }
  }
  return resolved
}

function matches(binding, event) {
  if (!binding) return false
  var eventModifiers = normalizeEventModifiers(event.modifiers)
  for (var i = 0; i < binding.variants.length; i++) {
    var variant = binding.variants[i]
    if (!variant || variant.modifiers !== eventModifiers) continue
    if (variant.keyCodes.indexOf(event.key) >= 0) return true
  }
  return false
}

function hintLine(bindings) {
  return "Type to filter — "
    + bindingHint(bindings.moveUp) + "/" + bindingHint(bindings.moveDown) + " to move, "
    + bindingHint(bindings.open) + " to open, "
    + bindingHint(bindings.quickRun) + " to run, "
    + bindingHint(bindings.back) + " to close"
}
