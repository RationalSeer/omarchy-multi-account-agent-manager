import QtQuick
import Quickshell
import Quickshell.Io

// Data side of the widget. Everything comes from `agent-acct status --json`;
// the widget never edits the registry or the usage records itself. A refresh
// runs on load, on a timer, whenever the registry / env file / a usage record
// changes on disk, and after every action the panel fires.
Item {
  id: root
  visible: false

  property int intervalSec: 300
  property string home: Quickshell.env("HOME") || ""
  readonly property string confDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/agent-accounts"
  // The CLI ships inside the plugin; no PATH setup is needed for the widget.
  readonly property string cli: String(Qt.resolvedUrl("bin/agent-acct")).replace(/^file:\/\//, "")
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/agents/usage"

  // [{tool,id,label,glyph,dir,active,exists,signedIn,email,plan,expiresAt,expired,limits,usageUpdatedAt,ready,attention}]
  property var profiles: []
  property var recordKeys: []
  property string updatedAt: ""
  property var alerts: ({})
  property string version: ""
  // setup card: [{id,label,ok}] from `agent-acct setup --status --json`
  property var setupSteps: []
  property bool setupComplete: true
  property bool setupChecked: false
  property bool busy: statusProcess.running
  property bool actionRunning: actionProcess.running
  property string lastError: ""
  property bool available: true   // false when agent-acct itself is missing

  readonly property var tools: {
    var order = [], byTool = {}
    for (var i = 0; i < profiles.length; i++) {
      var p = profiles[i]
      if (!byTool[p.tool]) { byTool[p.tool] = { id: p.tool, name: p.toolName || toolName(p.tool), mode: p.mode || "env", hasUsage: p.hasUsage !== false, autoRotate: p.autoRotate === true, profiles: [], active: null }; order.push(p.tool) }
      byTool[p.tool].profiles.push(p)
      if (p.active) byTool[p.tool].active = p
    }
    var out = []
    for (var j = 0; j < order.length; j++) out.push(byTool[order[j]])
    return out
  }

  function toolName(id) { return id ? id.charAt(0).toUpperCase() + id.slice(1) : "" }

  function refresh() {
    if (statusProcess.running) { refreshQueued = true; return }
    statusProcess.running = true
  }
  property bool refreshQueued: false

  Process {
    id: statusProcess
    running: false
    command: [root.cli, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text.trim() !== "") root.lastError = text.trim() }
    onExited: function(code) {
      // 127 = agent-acct not on PATH; anything else is a status we can show
      if (code === 127) root.available = false
      if (root.refreshQueued) { root.refreshQueued = false; Qt.callLater(root.refresh) }
    }
  }

  function applyStatus(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && parsed.profiles) {
        root.profiles = parsed.profiles
        // Watchers are keyed by record name so a status refresh does not
        // tear down and rebuild identical FileViews.
        var keys = []
        for (var i = 0; i < parsed.profiles.length; i++) keys.push(parsed.profiles[i].tool + "-" + parsed.profiles[i].id)
        keys.sort()
        if (JSON.stringify(keys) !== JSON.stringify(root.recordKeys)) root.recordKeys = keys
        root.updatedAt = String(parsed.updatedAt || "")
        root.alerts = parsed.alerts || {}
        root.version = String(parsed.version || "")
        root.lastError = ""
        root.available = true
      }
    } catch (e) {
      console.warn("agent-accounts", "bad status output", e)
    }
  }

  // ---- actions: one at a time, then re-read status ----
  property var actionQueue: []
  function run(args) {
    actionQueue.push(args)
    pumpActions()
  }
  function pumpActions() {
    if (actionProcess.running || actionQueue.length === 0) return
    actionProcess.command = [root.cli].concat(actionQueue.shift())
    actionProcess.running = true
  }
  Process {
    id: actionProcess
    running: false
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text.trim() !== "") root.lastError = text.trim() }
    onExited: function() { root.refresh(); root.checkSetup(); root.pumpActions() }
  }

  // ---- setup status ----
  Process {
    id: setupProcess
    running: false
    command: [root.cli, "setup", "--status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || ""))
          root.setupSteps = parsed.steps || []
          root.setupComplete = parsed.complete !== false
          root.setupChecked = true
        } catch (e) { console.warn("agent-accounts", "bad setup output", e) }
      }
    }
  }
  function checkSetup() { if (!setupProcess.running) setupProcess.running = true }
  function runSetup() { run(["setup"]) }
  function setAutoRotate(tool, on) { run(["config", tool, "autoRotate", on ? "on" : "off"]) }

  function use(tool, profile) { run(["use", tool, profile]) }
  function next(tool) { run(["next", tool]) }
  function login(tool, profile) { run(["login", tool, profile]) }     // no tty → opens a terminal
  function logout(tool, profile) { run(["logout", tool, profile]) }
  function shell(tool, profile) { run(profile ? ["shell", tool, profile] : ["shell"]) }
  function usageUpdate() { run(["usage-update", "--force"]) }
  function apply() { run(["apply"]) }

  // ---- watchers: registry, env, and every usage record ----
  FileView { path: root.confDir + "/accounts.json"; watchChanges: true; printErrors: false; onFileChanged: root.refresh() }
  FileView { path: root.confDir + "/active.env"; watchChanges: true; printErrors: false; onFileChanged: root.refresh() }
  Repeater {
    model: root.recordKeys
    Item {
      required property var modelData
      FileView {
        path: root.usageDir + "/" + modelData + ".json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
      }
    }
  }

  Timer {
    interval: Math.max(30, root.intervalSec) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: { checkSetup(); apply(); refresh() }
}
