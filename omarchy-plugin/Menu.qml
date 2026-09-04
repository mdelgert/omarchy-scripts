import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "KeyModel.js" as KeyModel
import "ScriptModel.js" as Model

// Native Omarchy menu for omarchy-scripts.
//
// This file is a view. It draws the surface, routes keys and clicks, and asks
// ScriptEngine for things; it does not parse a script's header comments,
// validate a parameter, or build a command line — all of that lives in the
// `omarchy-scripts` engine and reaches here only as JSON.
//
// Safety rules this file keeps:
//   * every string that came from a script renders as Text.PlainText
//   * no command string is ever built from script metadata or user input
//   * no script content is evaluated as QML or JavaScript
//   * Delete always goes through a confirmation dialog first
Item {
  id: root

  // ---- host injections (set by the shell's plugin Loader) -----------------
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // ---- plugin lifecycle ----------------------------------------------------

  property bool opened: false
  property bool fullscreen: false
  property string view: "browse"   // "browse" | "detail"
  property string filterText: ""
  property var paramValues: ({})
  property bool confirmingDelete: false
  property bool confirmingDuplicate: false
  property string duplicateIdText: ""
  property string duplicateError: ""
  // Set by openScript(id, true) — a required-parameter script opened via
  // the browse list's quick-activate shortcut. Consumed by
  // tryFocusFirstParam() once scriptEngine.script (fetched asynchronously)
  // actually has params to focus.
  property bool pendingFocusFirstParam: false

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    root.filterText = ""
    root.fullscreen = !!payload.fullscreen
    root.goBrowse()
    root.opened = true
    scriptEngine.reload()
    if (payload.script) Qt.callLater(function() { root.openScript(String(payload.script)) })
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.confirmingDelete = false
    root.confirmingDuplicate = false
  }

  function ping() { return "ok" }
  function refresh() { scriptEngine.reload(); return "ok" }

  function openScript(id, focusFirstParam) {
    root.paramValues = ({})
    root.confirmingDelete = false
    root.confirmingDuplicate = false
    scriptEngine.select(id)
    root.view = "detail"
    if (focusFirstParam) {
      root.pendingFocusFirstParam = true
      Qt.callLater(root.tryFocusFirstParam)
    } else {
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  // scriptEngine.script arrives asynchronously (a subprocess round-trip), so
  // a script opened via quickActivateCursor() may not have its params yet
  // the moment openScript() returns. This is called right away and again
  // whenever scriptEngine.script changes (see the Connections below);
  // pendingFocusFirstParam makes repeat calls harmless no-ops once it's done
  // its job once.
  function tryFocusFirstParam() {
    if (!root.pendingFocusFirstParam) return
    if (!scriptEngine.script) return
    root.pendingFocusFirstParam = false
    if (paramRepeater.count > 0) {
      var item = paramRepeater.itemAt(0)
      if (item && item.focusField) item.focusField()
      else keyCatcher.forceActiveFocus()
    } else {
      keyCatcher.forceActiveFocus()
    }
  }

  // Runs a script straight from the browse list, with no parameter values —
  // the engine already applies each param's metadata default when a value
  // is omitted (see SCRIPT_SPEC.md / core.py's _build_argv), so this is
  // exactly what "Run" would send for a script canRunWithoutInput() already
  // confirmed has no `required=true` param. Same runInTerminal machinery as
  // the detail view's Run button — no second execution path.
  function quickRunScript(id) {
    if (!id) return
    scriptEngine.select(id)
    scriptEngine.runInTerminal(id, {})
  }

  function goBrowse() {
    root.view = "browse"
    root.confirmingDelete = false
    root.confirmingDuplicate = false
    scriptEngine.select("")
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function paramValue(param) {
    if (root.paramValues[param.name] !== undefined) return root.paramValues[param.name]
    return param.default !== undefined ? param.default : ""
  }

  function setParamValue(name, value) {
    var next = ({})
    for (var k in root.paramValues) next[k] = root.paramValues[k]
    next[name] = value
    root.paramValues = next
  }

  // ---- engine ---------------------------------------------------------------

  ScriptEngine {
    id: scriptEngine
  }

  // scriptEngine.script populates asynchronously; this catches the case
  // where openScript(id, true) fires before the info round-trip lands (see
  // tryFocusFirstParam's own comment for why the flag makes repeats safe).
  Connections {
    target: scriptEngine
    function onScriptChanged() { Qt.callLater(root.tryFocusFirstParam) }
  }

  // ---- keyboard-driven navigation -------------------------------------------
  //
  // Same pattern as omarchy-recipes' Menu.qml: a flat row list (category
  // headers + scripts) the browse view walks with Up/Down, Enter/Right opens
  // the highlighted script, typing filters without a text field needing
  // focus, and Escape always means "go back one level, then close".

  property int selectedIndex: 0
  property bool cursorActive: false

  readonly property var rows: Model.rowsFor(scriptEngine.scripts, filterText)
  readonly property var keyBindings: KeyModel.resolve(scriptEngine.keySpecs)

  function runSelectedScript() {
    if (!scriptEngine.selectedId) return
    scriptEngine.runInTerminal(scriptEngine.selectedId, root.paramValues)
  }

  function editSelectedScript() {
    if (!scriptEngine.script) return
    scriptEngine.editInTerminal(scriptEngine.script.path)
    root.close()
  }

  function requestDeleteSelectedScript() {
    if (!scriptEngine.selectedId) return
    root.confirmingDelete = true
  }

  // Auto-suggests "<id>-copy", falling back to "<id>-copy-2", "-3", ... if
  // that id is already taken by a discovered script, so the prompt usually
  // needs no edit before Confirm.
  function suggestDuplicateId(id) {
    var taken = {}
    for (var i = 0; i < scriptEngine.scripts.length; i++) taken[scriptEngine.scripts[i].id] = true
    var candidate = id + "-copy"
    var n = 2
    while (taken[candidate]) {
      candidate = id + "-copy-" + n
      n += 1
    }
    return candidate
  }

  function requestDuplicateSelectedScript() {
    if (!scriptEngine.selectedId) return
    root.duplicateIdText = root.suggestDuplicateId(scriptEngine.selectedId)
    root.duplicateError = ""
    root.confirmingDuplicate = true
  }

  function confirmDuplicateSelectedScript() {
    if (!scriptEngine.selectedId || !root.duplicateIdText) return
    root.confirmingDuplicate = false
    scriptEngine.duplicateScript(scriptEngine.selectedId, root.duplicateIdText)
    root.close()
  }

  function setFilter(text) {
    filterText = text
    selectedIndex = Math.max(0, Model.firstSelectableRow(rows))
    cursorActive = false
  }

  function moveCursor(step) {
    if (rows.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = Math.max(0, Model.firstSelectableRow(rows))
      return
    }
    selectedIndex = Model.nextSelectableRow(rows, selectedIndex, step)
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function activateCursor() {
    if (rows.length === 0) return
    var index = cursorActive ? selectedIndex : Model.firstSelectableRow(rows)
    if (index < 0 || index >= rows.length) return
    var row = rows[index]
    if (row.kind === "script") root.openScript(row.scriptId)
  }

  // Shift+Enter / the row's inline "▶" affordance. A no-required-param
  // script runs immediately (see ScriptModel.canRunWithoutInput); a script
  // that still needs input can't skip the form, so this instead opens the
  // same detail view Enter does but lands focus straight in the first
  // parameter field — one fewer Tab/click than opening it passively.
  function quickActivateCursor() {
    if (rows.length === 0) return
    var index = cursorActive ? selectedIndex : Model.firstSelectableRow(rows)
    if (index < 0 || index >= rows.length) return
    var row = rows[index]
    if (row.kind !== "script") return
    if (row.canRunWithoutInput) root.quickRunScript(row.scriptId)
    else root.openScript(row.scriptId, true)
  }

  onRowsChanged: {
    if (selectedIndex >= rows.length || (rows[selectedIndex] && rows[selectedIndex].kind !== "script"))
      selectedIndex = Math.max(0, Model.firstSelectableRow(rows))
  }

  // ---- theme (menu surface roles, same tokens the built-in Omarchy menu and
  // omarchy-recipes use, so this doesn't look or feel like a different app) --

  property string fontFamily: Style.font.menuFamily
  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color borderColor: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property color selectedText: Color.menu.selectedText
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", borderColor, Math.max(1, Style.space(2)))

  readonly property int headerHeight: Math.max(Style.space(34), Style.font.heading + Style.spacing.controlPaddingY * 2)
  readonly property int rowHeight: Math.max(Style.space(46), Style.font.body + Style.spacing.rowPaddingX * 2)
  readonly property int headerRowHeight: Math.max(Style.space(26), Style.font.caption * 2)

  // ---- surface --------------------------------------------------------------

  PanelWindow {
    id: panel
    // Hidden (not just covered) while a script is running in its own
    // floating terminal: that terminal is a normal window, this is an
    // Overlay-layer surface that always paints above normal windows, so
    // staying mapped would hide the very thing Run just opened. The menu
    // itself stays "open" — root.opened never flips — so the moment the
    // terminal closes this reappears already refreshed with the new result.
    visible: root.opened && !scriptEngine.terminalRunning
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-scripts-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property int cardWidth: root.fullscreen
      ? panel.width - Style.gapsOut * 2
      : Math.min(Style.space(520), panel.width - Style.gapsOut * 2)
    readonly property int cardHeight: root.fullscreen
      ? panel.height - Style.gapsOut * 2
      : Math.min(Style.space(560), panel.height - Style.gapsOut * 2)

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: panel.cardWidth
      height: panel.cardHeight
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      // Clicking the card takes the keyboard back. With OnDemand focus the
      // user can click away to another window and the surface loses it.
      MouseArea {
        anchors.fill: parent
        onClicked: keyCatcher.forceActiveFocus()
      }

      // One key handler for the whole card. Content lives inside it, and
      // `Keys.AfterItem` lets a focused control (a spin box, a dropdown, the
      // filter itself typing) consume its own keys first; whatever bubbles
      // up here is Escape, arrows, Enter, and type-to-filter.
      Item {
        id: keyCatcher
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        focus: true

        Keys.priority: Keys.AfterItem
        Keys.onPressed: function(event) {
          if (confirmingDelete) {
            if (confirmDialog.handleKey(event)) event.accepted = true
            return
          }
          if (confirmingDuplicate) {
            // duplicateField normally owns focus and handles typing/Enter/
            // Escape itself; this only guards against a stray global
            // shortcut (R/E/D/...) firing if focus ever lands elsewhere
            // while the prompt is open.
            if (event.key === Qt.Key_Escape) {
              root.confirmingDuplicate = false
              event.accepted = true
            }
            return
          }
          if (KeyModel.matches(root.keyBindings.back, event)) {
            if (root.view !== "browse") root.goBrowse()
            else if (root.filterText) root.setFilter("")
            else root.close()
            event.accepted = true
            return
          }
          if (KeyModel.matches(root.keyBindings.reload, event)) {
            scriptEngine.reload()
            if (root.view === "detail") scriptEngine.select(scriptEngine.selectedId)
            event.accepted = true
            return
          }
          if (root.view === "detail") {
            if (KeyModel.matches(root.keyBindings.run, event)) {
              root.runSelectedScript()
              event.accepted = true
            } else if (KeyModel.matches(root.keyBindings.edit, event)) {
              root.editSelectedScript()
              event.accepted = true
            } else if (KeyModel.matches(root.keyBindings.delete, event)) {
              root.requestDeleteSelectedScript()
              event.accepted = true
            }
            return
          }

          if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (KeyModel.matches(root.keyBindings.moveUp, event)) {
            root.moveCursor(-1)
            event.accepted = true
          } else if (KeyModel.matches(root.keyBindings.moveDown, event)) {
            root.moveCursor(1)
            event.accepted = true
          } else if (KeyModel.matches(root.keyBindings.quickRun, event)) {
            root.quickActivateCursor()
            event.accepted = true
          } else if (KeyModel.matches(root.keyBindings.open, event)) {
            root.activateCursor()
            event.accepted = true
          } else if (event.text && event.text.length === 1
                     && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
                     && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        // ---- header -------------------------------------------------------
        Item {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.spacing.controlHeight + Style.spacing.md

          Button {
            id: backButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: root.view === "detail"
            text: "‹ Back"
            tooltipText: "Back (" + KeyModel.bindingHint(root.keyBindings.back) + ")"
            onClicked: root.goBrowse()
          }

          Row {
            anchors.left: root.view === "detail" ? backButton.right : parent.left
            anchors.leftMargin: root.view === "detail" ? Style.spacing.md : 0
            anchors.right: headerRightActions.left
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              visible: text !== ""
              text: root.view === "detail" && scriptEngine.script ? String(scriptEngine.script.icon || "") : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
            }

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              text: root.view === "browse" ? "Scripts" : (scriptEngine.script ? scriptEngine.script.title : "…")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideRight
            }
          }

          Row {
            id: headerRightActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.md

            Button {
              visible: root.view === "browse"
              text: "+ New script"
              tooltipText: "Scaffolds a script in your workspace and opens it for editing"
              onClicked: {
                scriptEngine.newScript()
                root.close()
              }
            }

            Button {
              text: "Close"
              onClicked: root.close()
            }
          }
        }

        Text {
          id: engineErrorText
          textFormat: Text.PlainText
          anchors.top: header.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          visible: scriptEngine.engineError !== ""
          text: scriptEngine.engineError
          color: Color.urgent
          wrapMode: Text.WordWrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // ---- browse view ----------------------------------------------------
        Item {
          id: browseView
          visible: root.view === "browse"
          anchors.top: engineErrorText.visible ? engineErrorText.bottom : header.bottom
          anchors.topMargin: Style.spacing.md
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          Text {
            id: filterLine
            textFormat: Text.PlainText
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.filterText ? ("Filter: " + root.filterText) : KeyModel.hintLine(root.keyBindings)
            color: root.filterText ? root.foreground : Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Text {
            id: problemsLine
            textFormat: Text.PlainText
            anchors.top: filterLine.bottom
            anchors.topMargin: Style.spacing.xs
            anchors.left: parent.left
            anchors.right: parent.right
            visible: scriptEngine.problems.length > 0
            text: scriptEngine.problems.length + " script(s) failed to parse — see terminal / `omarchy-scripts validate`"
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            id: settingsProblemsLine
            textFormat: Text.PlainText
            anchors.top: problemsLine.visible ? problemsLine.bottom : filterLine.bottom
            anchors.topMargin: Style.spacing.xs
            anchors.left: parent.left
            anchors.right: parent.right
            visible: scriptEngine.settingsProblems.length > 0
            text: scriptEngine.settingsProblems[0]
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          ListView {
            id: resultList
            anchors.top: settingsProblemsLine.visible
              ? settingsProblemsLine.bottom
              : (problemsLine.visible ? problemsLine.bottom : filterLine.bottom)
            anchors.topMargin: Style.spacing.sm
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            spacing: Style.spacing.xs
            model: root.rows

            delegate: Item {
              id: row
              required property var modelData
              required property int index

              width: resultList.width
              height: (row.modelData ? row.modelData.kind : "") === "header"
                ? root.headerRowHeight : root.rowHeight

              PanelSectionHeader {
                visible: (row.modelData ? row.modelData.kind : "") === "header"
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.spacing.xxs
                text: row.modelData ? row.modelData.label : ""
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Rectangle {
                id: scriptRow
                visible: (row.modelData ? row.modelData.kind : "") === "script"
                anchors.fill: parent
                radius: Style.cornerRadius
                color: root.cursorActive && root.selectedIndex === row.index
                  ? root.selectedBackground : "transparent"

                property bool rowHovered: false
                readonly property bool showQuickRun: !!(row.modelData && row.modelData.canRunWithoutInput)
                  && (scriptRow.rowHovered || (root.cursorActive && root.selectedIndex === row.index))

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: scriptRow.rowHovered = true
                  onExited: scriptRow.rowHovered = false
                  onClicked: root.openScript(row.modelData.scriptId)
                }

                Row {
                  anchors.left: parent.left
                  anchors.right: quickRunButton.visible ? quickRunButton.left : parent.right
                  anchors.leftMargin: Style.spacing.rowPaddingX
                  anchors.rightMargin: Style.spacing.rowPaddingX
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.spacing.controlGap

                  Text {
                    id: rowIcon
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: row.modelData && row.modelData.icon ? row.modelData.icon : ""
                    color: root.cursorActive && root.selectedIndex === row.index
                      ? root.selectedText : Qt.darker(root.foreground, 1.25)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width - rowIcon.width - Style.spacing.controlGap
                    text: row.modelData ? row.modelData.label : ""
                    color: root.cursorActive && root.selectedIndex === row.index
                      ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                }

                // Quick-run affordance: only for scripts that need no user
                // input (row.canRunWithoutInput — a script with a
                // `required=true` param never shows this, matching
                // quickActivateCursor()'s own gating). Hover-revealed for
                // the mouse, and shown whenever the keyboard cursor sits on
                // the row so Shift+Enter stays discoverable too.
                Text {
                  id: quickRunButton
                  textFormat: Text.PlainText
                  visible: scriptRow.showQuickRun
                  anchors.right: parent.right
                  anchors.rightMargin: Style.spacing.rowPaddingX
                  anchors.verticalCenter: parent.verticalCenter
                  text: "▶ " + KeyModel.bindingHint(root.keyBindings.quickRun)
                  color: root.cursorActive && root.selectedIndex === row.index
                    ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Style.spacing.xs
                    onClicked: root.quickRunScript(row.modelData.scriptId)
                  }

                  PanelToolTip {
                    visible: quickRunButton.visible && quickRunButtonHover.hovered
                    text: "Run now with default values (" + KeyModel.bindingHint(root.keyBindings.quickRun) + ")"
                    fontFamily: root.fontFamily
                  }

                  HoverHandler {
                    id: quickRunButtonHover
                  }
                }
              }
            }
          }
        }

        // ---- detail view ----------------------------------------------------
        Flickable {
          id: detailView
          visible: root.view === "detail"
          anchors.top: engineErrorText.visible ? engineErrorText.bottom : header.bottom
          anchors.topMargin: Style.spacing.md
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          clip: true
          contentHeight: detailColumn.height
          contentWidth: width

          Column {
            id: detailColumn
            width: detailView.width
            spacing: Style.spacing.md

            Text {
              textFormat: Text.PlainText
              visible: !!scriptEngine.script
              text: scriptEngine.script ? scriptEngine.script.description : ""
              color: root.foreground
              wrapMode: Text.WordWrap
              width: parent.width
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              textFormat: Text.PlainText
              visible: !!scriptEngine.script
              text: scriptEngine.script ? scriptEngine.script.path : ""
              color: Qt.darker(root.foreground, 1.5)
              wrapMode: Text.WrapAnywhere
              width: parent.width
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            // ---- generated parameter form ------------------------------
            Repeater {
              id: paramRepeater
              model: scriptEngine.script ? scriptEngine.script.params : []
              delegate: Column {
                required property var modelData
                width: detailColumn.width
                spacing: Style.spacing.xs

                // Best-effort focus hand-off for tryFocusFirstParam(): a
                // plain TextField accepts forceActiveFocus() directly;
                // NumberField exposes its internal SpinBox via its `field`
                // alias; Dropdown has no such hook today, so it falls back
                // to focusing its own root item.
                function focusField() {
                  var item = fieldLoader.item
                  if (!item) return
                  if (item.field && item.field.forceActiveFocus) item.field.forceActiveFocus()
                  else if (item.forceActiveFocus) item.forceActiveFocus()
                }

                Text {
                  textFormat: Text.PlainText
                  text: (modelData.label || modelData.name) + (modelData.required === "true" ? " *" : "")
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Loader {
                  id: fieldLoader
                  width: parent.width
                  sourceComponent: {
                    if (modelData.type === "integer") return integerField
                    if (modelData.type === "boolean") return booleanField
                    if (modelData.type === "choice") return choiceField
                    return stringField
                  }
                  onLoaded: {
                    if (item.setInitial) item.setInitial(modelData)
                  }

                  Component {
                    id: stringField
                    TextField {
                      // placeholderText only shows a greyed-out hint when
                      // `text` is empty; it is never part of `text` itself,
                      // so it never reaches setParamValue. This lets a param
                      // document its built-in default (e.g. a settings
                      // script's blank-leaves-unchanged field) without that
                      // default being silently submitted on Run the way a
                      // real `default=` attribute would be (see @param
                      // `placeholder=` in docs/SCRIPT_SPEC.md).
                      placeholderText: modelData.placeholder || ""
                      function setInitial(p) { text = root.paramValue(p) }
                      onTextChanged: root.setParamValue(modelData.name, text)
                    }
                  }
                  Component {
                    id: integerField
                    NumberField {
                      from: modelData.min !== undefined ? parseInt(modelData.min) : 0
                      to: modelData.max !== undefined ? parseInt(modelData.max) : 999999
                      function setInitial(p) {
                        var v = root.paramValue(p)
                        value = v ? parseInt(v) : from
                      }
                      onModified: root.setParamValue(modelData.name, String(value))
                    }
                  }
                  Component {
                    id: booleanField
                    Dropdown {
                      options: ["false", "true"]
                      function setInitial(p) { value = root.paramValue(p) || "false" }
                      onChanged: function(v) { root.setParamValue(modelData.name, v) }
                    }
                  }
                  Component {
                    id: choiceField
                    Dropdown {
                      options: (modelData.choices || "").split(",").filter(function(s) { return s.length > 0 })
                      function setInitial(p) { value = root.paramValue(p) }
                      onChanged: function(v) { root.setParamValue(modelData.name, v) }
                    }
                  }
                }
              }
            }

            // ---- actions --------------------------------------------------
            // Flow (not Row) so a narrow detail card wraps Duplicate onto a
            // second line instead of it being clipped off the right edge by
            // the enclosing Flickable's clip: true.
            Flow {
              width: detailColumn.width
              spacing: Style.spacing.md

              Column {
                spacing: Style.spacing.xxs

                Button {
                  text: "Run"
                  tooltipText: "Runs in a floating terminal, like Omarchy's own updates — this menu hides itself and reappears when it closes"
                  onClicked: root.runSelectedScript()
                }

                Text {
                  textFormat: Text.PlainText
                  text: KeyModel.bindingHint(root.keyBindings.run)
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Column {
                spacing: Style.spacing.xxs

                Button {
                  text: "Edit"
                  onClicked: root.editSelectedScript()
                }

                Text {
                  textFormat: Text.PlainText
                  text: KeyModel.bindingHint(root.keyBindings.edit)
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Column {
                spacing: Style.spacing.xxs

                Button {
                  text: "Delete"
                  onClicked: root.requestDeleteSelectedScript()
                }

                Text {
                  textFormat: Text.PlainText
                  text: KeyModel.bindingHint(root.keyBindings.delete)
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Column {
                spacing: Style.spacing.xxs

                Button {
                  text: "Duplicate"
                  tooltipText: "Copies this script into your workspace under a new id and opens it for editing"
                  onClicked: root.requestDuplicateSelectedScript()
                }
              }
            }

            // ---- last result ------------------------------------------------
            // Updates itself: runInTerminal re-selects the script the moment
            // its terminal closes, so this is always the most recent run —
            // no manual refresh needed.
            Column {
              width: detailColumn.width
              spacing: Style.spacing.xs
              visible: !!scriptEngine.lastResult

              Text {
                textFormat: Text.PlainText
                text: scriptEngine.lastResult
                  ? ("Last run: exit " + scriptEngine.lastResult.exit_code
                      + " · " + scriptEngine.lastResult.duration_seconds + "s"
                      + " · " + scriptEngine.lastResult.ran_at)
                  : ""
                color: (scriptEngine.lastResult && scriptEngine.lastResult.success) ? root.foreground : Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              BorderSurface {
                width: detailColumn.width
                height: Style.space(180)
                color: Qt.darker(root.background, 1.1)
                borderSpec: Border.flat(Qt.darker(root.foreground, 1.6), Style.normalBorderWidth)
                padding: Style.spacing.sm

                Flickable {
                  anchors.fill: parent
                  clip: true
                  contentHeight: outputText.implicitHeight
                  TextEdit {
                    id: outputText
                    readOnly: true
                    selectByMouse: true
                    width: parent.width
                    text: scriptEngine.lastResult
                      ? (scriptEngine.lastResult.stdout + scriptEngine.lastResult.stderr)
                      : ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: TextEdit.Wrap
                  }
                }
              }
            }
          }
        }

        // ---- delete confirmation --------------------------------------------
        ConfirmDialog {
          id: confirmDialog
          anchors.fill: parent
          opened: root.confirmingDelete
          message: scriptEngine.script
            ? ("Delete " + scriptEngine.script.title + "? This removes the file: " + scriptEngine.script.path)
            : ""
          confirmText: "Delete"
          onCanceled: root.confirmingDelete = false
          onConfirmed: {
            root.confirmingDelete = false
            scriptEngine.deleteScript(scriptEngine.selectedId)
            root.goBrowse()
          }
        }

        // ---- duplicate prompt -------------------------------------------------
        // No shared dialog component takes free text input, so this is a small
        // bespoke overlay rather than reusing ConfirmDialog: a suggested new id
        // (see suggestDuplicateId()) prefilled and editable, Confirm/Cancel.
        Item {
          id: duplicateDialog
          anchors.fill: parent
          visible: root.confirmingDuplicate

          Rectangle {
            anchors.fill: parent
            color: Util.alpha(Color.background, 0.7)
            MouseArea { anchors.fill: parent; onClicked: root.confirmingDuplicate = false }

            BorderSurface {
              id: duplicateCard
              width: Math.min(parent.width - Style.space(32), Style.space(370))
              height: duplicateCard.contentTopInset + duplicateCard.contentBottomInset
                + duplicateMessage.implicitHeight + Style.spacing.sm + duplicateField.implicitHeight
                + (root.duplicateError ? (Style.spacing.xs + duplicateErrorText.implicitHeight) : 0)
                + Style.spacing.md + Style.space(34)
              anchors.centerIn: parent
              color: root.background
              borderSpec: Border.flat(Color.accent, Style.normalBorderWidth)
              padding: Style.space(18)
              radius: Style.cornerRadius

              MouseArea { anchors.fill: parent; onClicked: {} }

              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: duplicateCard.contentLeftInset
                anchors.rightMargin: duplicateCard.contentRightInset
                anchors.topMargin: duplicateCard.contentTopInset
                spacing: Style.spacing.sm

                Text {
                  id: duplicateMessage
                  textFormat: Text.PlainText
                  width: parent.width
                  text: scriptEngine.script ? ("Duplicate " + scriptEngine.script.title + " as:") : ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  wrapMode: Text.WordWrap
                }

                TextField {
                  id: duplicateField
                  width: parent.width
                  text: root.duplicateIdText
                  onTextChanged: root.duplicateIdText = text
                  Keys.onEscapePressed: root.confirmingDuplicate = false
                  onAccepted: root.confirmDuplicateSelectedScript()
                }

                Text {
                  id: duplicateErrorText
                  textFormat: Text.PlainText
                  width: parent.width
                  visible: !!root.duplicateError
                  text: root.duplicateError
                  color: Color.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }

                Row {
                  anchors.right: parent.right
                  spacing: Style.space(10)

                  Button {
                    text: "Cancel"
                    onClicked: root.confirmingDuplicate = false
                  }

                  Button {
                    text: "Duplicate"
                    onClicked: root.confirmDuplicateSelectedScript()
                  }
                }
              }
            }
          }

          onVisibleChanged: if (visible) Qt.callLater(function() { duplicateField.forceActiveFocus(); duplicateField.selectAll() })
        }
      }
    }
  }
}
