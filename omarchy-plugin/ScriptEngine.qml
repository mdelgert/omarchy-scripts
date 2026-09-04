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
  // An id asked for before the runner finished resolving (see probeProc
  // above), replayed the moment resolution completes.
  property string pendingSelect: ""

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
        // A payload-driven open (`{"script": "<id>"}`) can call select()
        // before the runner finishes resolving, right after a fresh shell
        // start/restart — select() queues that id in pendingSelect instead
        // of silently dropping it, and this is where it gets replayed.
        if (engine.pendingSelect) {
          var id = engine.pendingSelect
          engine.pendingSelect = ""
          engine.select(id)
        }
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
    if (!available) {
      pendingSelect = id
      return
    }
    if (!id) return
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
  //
  // Run always executes through the floating presentation terminal (see
  // below) so there is exactly one run path, not two competing ones. It
  // still goes through `omarchy-scripts run`, so parameter validation and
  // last-run recording stay identical to running it any other way.

  // ---- edit / run-in-terminal / new -----------------------------------------
  //
  // These hand off to Omarchy's own helpers instead of each plugin
  // reinventing "launch a terminal" or "find the user's editor":
  //   * omarchy-launch-editor   — the same default-editor resolution every
  //                               other Omarchy surface uses (GUI or TUI).
  //   * omarchy-launch-floating-terminal-with-presentation — the same
  //                               floating, focused, logo/done-banner
  //                               terminal Omarchy's own update flow uses.
  // Neither is ever built as a shell string from untrusted input: `edit`
  // passes the path as its own argv element, and the terminal command is
  // POSIX single-quoted by `shQuote` before being handed to the presentation
  // helper as one argv element.

  function shQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  function editInTerminal(path) {
    if (!path) return
    editProc.command = ["omarchy-launch-editor", path]
    editProc.running = true
  }

  Process { id: editProc }

  function runInTerminal(id, values) {
    if (!available || !id) return
    var args = ["run", id, "--raw"]
    for (var key in values) args.push("--param", key + "=" + values[key])
    var quoted = args.map(function(a) { return engine.shQuote(a) })
    var cmd = engine.shQuote(runnerPath) + " " + quoted.join(" ")
    engine.terminalRunning = true
    terminalProc.command = ["omarchy-launch-floating-terminal-with-presentation", cmd]
    terminalProc.running = true
  }

  // True while the presentation terminal launched by runInTerminal is still
  // open. The menu uses this to stay open-but-hidden behind it instead of
  // closing outright, so the user lands back on the same screen — with a
  // freshly reloaded last-run result — the moment they close the terminal.
  property bool terminalRunning: false

  Process {
    id: terminalProc
    onExited: {
      engine.terminalRunning = false
      if (engine.selectedId) engine.select(engine.selectedId)
    }
  }

  Process {
    id: newProc
    stdout: StdioCollector { id: newOut; waitForEnd: true }
    stderr: StdioCollector { id: newErr; waitForEnd: true }
    onExited: function(exitCode) {
      var parsed = Model.parseResponse(newOut.text, engine.schemaVersion)
      if (!parsed.ok) {
        engine.engineError = engine.describeFailure(parsed.error, exitCode, newErr.text)
        return
      }
      engine.engineError = ""
      engine.editInTerminal(parsed.data.path)
      engine.reload()
    }
  }

  function newScript() {
    if (!available) return
    newProc.command = argv(["new"])
    newProc.running = true
  }

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
