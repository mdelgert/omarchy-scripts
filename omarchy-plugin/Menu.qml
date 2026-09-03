import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "ScriptModel.js" as Model

// Native Omarchy menu for omarchy-scripts.
//
// This file is a view. It draws the surface, routes clicks, and asks
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
  property string view: "browse"   // "browse" | "detail"
  property string filterText: ""
  property var paramValues: ({})
  property bool confirmingDelete: false

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    root.filterText = ""
    root.goBrowse()
    root.opened = true
    scriptEngine.reload()
    if (payload.script) Qt.callLater(function() { root.openScript(String(payload.script)) })
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
  }

  function goBrowse() {
    root.view = "browse"
    root.confirmingDelete = false
    scriptEngine.select("")
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

  // ---- filtering --------------------------------------------------------

  readonly property var filteredGroups: {
    var text = root.filterText.toLowerCase()
    var list = scriptEngine.scripts
    if (text) {
      list = list.filter(function(s) {
        var haystack = (s.title + " " + s.description + " " + (s.tags || []).join(" ")).toLowerCase()
        return haystack.indexOf(text) >= 0
      })
    }
    return Model.groupByCategory(list)
  }

  // ---- surface --------------------------------------------------------------

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-scripts-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property int cardWidth: Math.min(Style.space(520), panel.width - Style.gapsOut * 2)
    readonly property int cardHeight: Math.min(Style.space(560), panel.height - Style.gapsOut * 2)

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.5)
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
      color: Color.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.foreground, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      // Absorb clicks on the card so they don't fall through to the scrim.
      MouseArea { anchors.fill: parent; onClicked: function() {} }

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

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

          Text {
            textFormat: Text.PlainText
            anchors.left: root.view === "detail" ? backButton.right : parent.left
            anchors.leftMargin: root.view === "detail" ? Style.spacing.md : 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.view === "browse" ? "Scripts" : (scriptEngine.script ? scriptEngine.script.title : "…")
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
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
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        // ---- browse view ----------------------------------------------------
        Column {
          id: browseView
          visible: root.view === "browse"
          anchors.top: engineErrorText.visible ? engineErrorText.bottom : header.bottom
          anchors.topMargin: Style.spacing.md
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: Style.spacing.md

          TextField {
            id: filterField
            width: parent.width
            placeholderText: "Filter…"
            text: root.filterText
            onTextChanged: root.filterText = text
          }

          Text {
            textFormat: Text.PlainText
            visible: scriptEngine.problems.length > 0
            text: scriptEngine.problems.length + " script(s) failed to parse — see terminal / `omarchy-scripts validate`"
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            width: parent.width
          }

          ListView {
            width: parent.width
            height: parent.height - filterField.height - Style.spacing.md
            clip: true
            model: root.filteredGroups
            delegate: Column {
              width: browseView.width
              required property var modelData

              Text {
                textFormat: Text.PlainText
                text: modelData.category
                color: Qt.darker(Color.foreground, 1.3)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                topPadding: Style.spacing.sm
                bottomPadding: Style.spacing.xs
              }

              Repeater {
                model: modelData.scripts
                delegate: Button {
                  required property var modelData
                  width: browseView.width
                  leftAlign: true
                  bordered: true
                  text: modelData.title
                  tooltipText: modelData.description
                  onClicked: root.openScript(modelData.id)
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
              color: Color.foreground
              wrapMode: Text.WordWrap
              width: parent.width
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              textFormat: Text.PlainText
              visible: !!scriptEngine.script
              text: scriptEngine.script ? scriptEngine.script.path : ""
              color: Qt.darker(Color.foreground, 1.5)
              wrapMode: Text.WrapAnywhere
              width: parent.width
              font.family: Style.font.family
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
                  color: Qt.darker(Color.foreground, 1.4)
                  font.family: Style.font.family
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
                tooltipText: "Runs in a floating terminal, like Omarchy's own updates"
                onClicked: {
                  scriptEngine.runInTerminal(scriptEngine.selectedId, root.paramValues)
                  root.close()
                }
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
            Column {
              width: detailColumn.width
              spacing: Style.spacing.xs
              visible: !!scriptEngine.lastResult

              Row {
                width: parent.width
                spacing: Style.spacing.md

                Text {
                  textFormat: Text.PlainText
                  text: scriptEngine.lastResult
                    ? ("Last run: exit " + scriptEngine.lastResult.exit_code
                        + " · " + scriptEngine.lastResult.duration_seconds + "s"
                        + " · " + scriptEngine.lastResult.ran_at)
                    : ""
                  color: (scriptEngine.lastResult && scriptEngine.lastResult.success) ? Color.foreground : Color.urgent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }

                Button {
                  text: "↻ Refresh"
                  tooltipText: "Reload this result — Run opens in its own terminal, so this doesn't update live"
                  onClicked: scriptEngine.select(scriptEngine.selectedId)
                }
              }

              BorderSurface {
                width: detailColumn.width
                height: Style.space(180)
                color: Qt.darker(Color.background, 1.1)
                borderSpec: Border.flat(Qt.darker(Color.foreground, 1.6), Style.normalBorderWidth)
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
                    color: Color.foreground
                    font.family: Style.font.family
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
