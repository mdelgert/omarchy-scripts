import QtQuick
import Quickshell
import Quickshell.Io
import "ScriptModel.js" as Model

// Controller between the QML menu and the `omarchy-scripts` engine.
//
// Every piece of knowledge about scripts enters the plugin through this
// file, and it enters as parsed JSON from the runner. Nothing here reads a
// script file, parses its metadata, or decides what a parameter means: the
// engine is the authoritative boundary and the UI is a view over what it
// reports.
//
// Processes are argv arrays. No command string is ever assembled from script
// metadata or user input, and nothing from a script is evaluated as code.
Item {
  id: engine

  readonly property int schemaVersion: 1

  // ---- runner resolution ----------------------------------------------
  //
  // OMARCHY_SCRIPTS_BIN, when set, is the whole list. Otherwise, in order:
  //   1. <plugin>/bin/omarchy-scripts     installed plugin ships the engine
  //   2. <plugin>/../bin/omarchy-scripts  running straight from a checkout
  //   3. ~/.local/bin/omarchy-scripts     user install
  readonly property string pluginDir: Model.pathFromUrl(Qt.resolvedUrl("."))
  readonly property string runnerOverride: String(Quickshell.env("OMARCHY_SCRIPTS_BIN") || "")
  readonly property var runnerCandidates: {
    if (runnerOverride) return [runnerOverride]
    var out = []
    if (pluginDir) {
      out.push(pluginDir + "/bin/omarchy-scripts")
      out.push(Model.parentDir(pluginDir) + "/bin/omarchy-scripts")
    }
    var home = Quickshell.env("HOME")
    if (home) out.push(home + "/.local/bin/omarchy-scripts")
    return out
  }

  property int candidateIndex: -1
  property string runnerPath: ""
  property bool runnerResolved: false

  readonly property bool available: runnerResolved && runnerPath !== ""

  property bool loadingList: false
  property var scripts: []
  property var problems: []
  property string engineError: ""

  property string selectedId: ""
  property var script: null
  property var lastResult: null
  property bool running: false

  function argv(args) {
    var out = [runnerPath]
    for (var i = 0; i < args.length; i++) out.push(String(args[i]))
    return out
  }

  function describeFailure(error, exitCode, stderrText) {
    if (error) return error
    var line = Model.firstLine(stderrText, 200)
    return line || ("omarchy-scripts exited " + exitCode)
  }

  // ---- resolve the runner once, at startup --------------------------------

  function resolveRunner() {
    candidateIndex = -1
    tryNextCandidate()
  }

  function tryNextCandidate() {
    candidateIndex += 1
    if (candidateIndex >= runnerCandidates.length) {
      runnerResolved = true
      runnerPath = ""
      engineError = "could not find the omarchy-scripts runner"
      return
    }
    probeProc.command = ["test", "-x", runnerCandidates[candidateIndex]]
    probeProc.running = true
  }

  Process {
    id: probeProc
    onExited: function(exitCode) {
      if (exitCode === 0) {
        runnerPath = runnerCandidates[candidateIndex]
        runnerResolved = true
        reload()
      } else {
        tryNextCandidate()
      }
    }
  }

  Component.onCompleted: resolveRunner()

  // ---- list ----------------------------------------------------------------

  function reload() {
    if (!available || listProc.running) return
    loadingList = true
    listProc.command = argv(["list"])
    listProc.running = true
  }

  Process {
    id: listProc
    stdout: StdioCollector { id: listOut; waitForEnd: true }
    stderr: StdioCollector { id: listErr; waitForEnd: true }
    onExited: function(exitCode) {
      engine.loadingList = false
      var parsed = Model.parseResponse(listOut.text, engine.schemaVersion)
      if (!parsed.ok) {
        engine.scripts = []
        engine.problems = []
        engine.engineError = engine.describeFailure(parsed.error, exitCode, listErr.text)
        return
      }
      engine.engineError = ""
      engine.scripts = parsed.data.scripts || []
      engine.problems = parsed.data.problems || []
    }
  }

  // ---- info ------------------------------------------------------------

  function select(id) {
    selectedId = id
    script = null
    lastResult = null
    if (!available || !id) return
    infoProc.command = argv(["info", id])
    infoProc.running = true
    lastRunProc.command = argv(["last-run", id])
    lastRunProc.running = true
  }

  Process {
    id: infoProc
    stdout: StdioCollector { id: infoOut; waitForEnd: true }
    stderr: StdioCollector { id: infoErr; waitForEnd: true }
    onExited: function(exitCode) {
      var parsed = Model.parseResponse(infoOut.text, engine.schemaVersion)
      if (!parsed.ok) {
        engine.engineError = engine.describeFailure(parsed.error, exitCode, infoErr.text)
        return
      }
      engine.engineError = ""
      engine.script = parsed.data.script
    }
  }

  Process {
    id: lastRunProc
    stdout: StdioCollector { id: lastRunOut; waitForEnd: true }
    onExited: function() {
      var parsed = Model.parseResponse(lastRunOut.text, engine.schemaVersion)
      engine.lastResult = parsed.ok ? parsed.data.result : null
    }
  }

  // ---- run ---------------------------------------------------------------

  function run(id, values) {
    if (!available || running) return
    running = true
    var args = ["run", id]
    for (var key in values) {
      args.push("--param")
      args.push(key + "=" + values[key])
    }
    runProc.command = argv(args)
    runProc.running = true
  }

  Process {
    id: runProc
    stdout: StdioCollector { id: runOut; waitForEnd: true }
    stderr: StdioCollector { id: runErr; waitForEnd: true }
    onExited: function(exitCode) {
      engine.running = false
      var parsed = Model.parseResponse(runOut.text, engine.schemaVersion)
      if (!parsed.ok) {
        engine.engineError = engine.describeFailure(parsed.error, exitCode, runErr.text)
        return
      }
      engine.engineError = ""
      engine.lastResult = parsed.data.result
    }
  }

  // ---- edit / delete -------------------------------------------------------
  //
  // Edit opens the file in a terminal running $EDITOR — a real editor on the
  // real file, not a text box in this plugin re-implementing one.

  function editInTerminal(path) {
    if (!path) return
    var term = String(Quickshell.env("TERMINAL") || "") || "foot"
    var editor = String(Quickshell.env("EDITOR") || "") || "vi"
    editProc.command = [term, "-e", editor, path]
    editProc.running = true
  }

  Process { id: editProc }

  function runInTerminal(path) {
    if (!path) return
    var term = String(Quickshell.env("TERMINAL") || "") || "foot"
    // Runs the file directly, then drops to an interactive shell so the user
    // can inspect what happened or re-run it by hand — the whole point of a
    // plain file on disk is that you never have to go through this plugin.
    // `path` is passed as a positional argument ($1), never concatenated into
    // the -c string, so a path containing spaces or shell metacharacters is
    // still handled safely.
    terminalProc.command = [term, "-e", "bash", "-c", 'bash "$1"; exec bash', "_", path]
    terminalProc.running = true
  }

  Process { id: terminalProc }

  function deleteScript(id) {
    if (!available) return
    deleteProc.command = argv(["delete", id])
    deleteProc.running = true
  }

  Process {
    id: deleteProc
    stdout: StdioCollector { id: deleteOut; waitForEnd: true }
    onExited: function() {
      engine.reload()
      if (engine.selectedId) engine.select("")
    }
  }
}
