import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
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
  }

  function ping() { return "ok" }
  function refresh() { scriptEngine.reload(); return "ok" }

  function openScript(id) {
    root.paramValues = ({})
    root.confirmingDelete = false
    scriptEngine.select(id)
    root.view = "detail"
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function goBrowse() {
    root.view = "browse"
    root.confirmingDelete = false
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

  // ---- keyboard-driven navigation -------------------------------------------
  //
  // Same pattern as omarchy-recipes' Menu.qml: a flat row list (category
  // headers + scripts) the browse view walks with Up/Down, Enter/Right opens
  // the highlighted script, typing filters without a text field needing
  // focus, and Escape always means "go back one level, then close".

  property int selectedIndex: 0
  property bool cursorActive: false

  readonly property var rows: Model.rowsFor(scriptEngine.scripts, filterText)

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
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left) {
            if (root.view !== "browse") root.goBrowse()
            else if (root.filterText) root.setFilter("")
            else root.close()
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_F5) {
            scriptEngine.reload()
            if (root.view === "detail") scriptEngine.select(scriptEngine.selectedId)
            event.accepted = true
            return
          }
          // Below here is browse-list navigation and type-to-filter. In the
          // detail view those keys belong to the generated form controls.
          if (root.view !== "browse") return

          if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.moveCursor(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.moveCursor(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
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
            text: root.filterText ? ("Filter: " + root.filterText) : "Type to filter — ↑/↓ to move, Enter to open, Esc to close"
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

          ListView {
            id: resultList
            anchors.top: problemsLine.visible ? problemsLine.bottom : filterLine.bottom
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
                visible: (row.modelData ? row.modelData.kind : "") === "script"
                anchors.fill: parent
                radius: Style.cornerRadius
                color: root.cursorActive && root.selectedIndex === row.index
                  ? root.selectedBackground : "transparent"

                MouseArea {
                  anchors.fill: parent
                  onClicked: root.openScript(row.modelData.scriptId)
                }

                Row {
                  anchors.left: parent.left
                  anchors.right: parent.right
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
              model: scriptEngine.script ? scriptEngine.script.params : []
              delegate: Column {
                required property var modelData
                width: detailColumn.width
                spacing: Style.spacing.xs

                Text {
                  textFormat: Text.PlainText
                  text: (modelData.label || modelData.name) + (modelData.required === "true" ? " *" : "")
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Loader {
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
            Row {
              spacing: Style.spacing.md

              Button {
                text: "Run"
                tooltipText: "Runs in a floating terminal, like Omarchy's own updates — this menu hides itself and reappears when it closes"
                onClicked: scriptEngine.runInTerminal(scriptEngine.selectedId, root.paramValues)
              }
              Button {
                text: "Edit"
                onClicked: {
                  scriptEngine.editInTerminal(scriptEngine.script ? scriptEngine.script.path : "")
                  root.close()
                }
              }
              Button {
                text: "Delete"
                onClicked: root.confirmingDelete = true
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
      }
    }
  }
}
