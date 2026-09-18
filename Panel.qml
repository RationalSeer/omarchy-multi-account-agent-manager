import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Multi-Account Agent Manager: which subscription is live per AI coding CLI, and a panel
// to switch, sign in and eyeball each profile's limits. All state changes go
// through the agent-acct CLI (see Accounts.qml); this file only draws and
// dispatches.
Panel {
  id: root
  moduleName: "io.github.rationalseer.multi-account-agent-manager"
  ipcTarget: "io.github.rationalseer.multi-account-agent-manager"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color faint: Qt.darker(foreground, 2.2)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property real warnFraction: Math.max(0.5, Math.min(1, Number(setting("limitWarnPercent", 85)) / 100))
  readonly property bool showGlyphs: setting("showGlyphs", true) !== false
  readonly property bool compactBar: setting("compactBar", false) === true
  readonly property bool barShowUnsigned: setting("barShowUnsigned", false) === true
  // "masked" (cyc…@example.com), "hidden" (never shown), or "full"
  readonly property string emailDisplay: String(setting("emailDisplay", "masked"))

  // The bar only lists tools you are signed in to (at least one profile);
  // the panel still lists every discovered tool so you can sign the rest in.
  function toolSigned(tool) {
    for (var i = 0; i < (tool && tool.profiles || []).length; i++) if (tool.profiles[i].signedIn) return true
    return false
  }
  readonly property var barTools: {
    var out = []
    for (var i = 0; i < tools.length; i++) if (!tools[i].barHidden && (barShowUnsigned || toolSigned(tools[i]))) out.push(tools[i])
    return out
  }

  // ---- panel state: which view, which tool tab ----
  property string view: "accounts"          // "accounts" | "settings"
  property string selectedToolId: ""
  readonly property int selectedToolIndex: {
    for (var i = 0; i < tools.length; i++) if (tools[i].id === selectedToolId) return i
    return 0
  }
  readonly property var selectedTool: tools.length > 0 ? tools[selectedToolIndex] : null
  readonly property var tabProfiles: selectedTool ? selectedTool.profiles : []
  function selectTab(index) {
    if (tools.length === 0) return
    var i = ((index % tools.length) + tools.length) % tools.length
    selectedToolId = tools[i].id; cursor = 0
  }
  readonly property string legend: "j/k  select account\nEnter  use\ni  sign in\nt  terminal\nh/l  previous / next tool\nr  refresh usage\ns  settings\ne  edit registry\nEsc  back / close"

  readonly property var tools: accounts.tools
  readonly property var profiles: accounts.profiles

  // Flat cursor over every profile row, in display order.
  property int cursor: 0
  property bool cursorActive: false
  readonly property var cursorProfile: tabProfiles.length > 0 ? tabProfiles[clamp(cursor, 0, tabProfiles.length - 1)] : null

  property double nowMs: Date.now()
  Timer { interval: 30000; running: root.opened; repeat: true; onTriggered: root.nowMs = Date.now() }

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function flatIndexOf(p) {
    for (var i = 0; i < profiles.length; i++) if (profiles[i].tool === p.tool && profiles[i].id === p.id) return i
    return -1
  }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function escapeHtml(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
  function markSource(toolId) { return Qt.resolvedUrl("assets/" + toolId + ".svg") }

  // ---- attention: what the bar tints and the panel flags ----
  function worstLimit(p) {
    var worst = 0
    for (var i = 0; i < (p && p.limits || []).length; i++) worst = Math.max(worst, Number(p.limits[i].percent || 0))
    return worst
  }
  function attentionFor(p) {
    if (!p) return "none"
    if (!p.signedIn) return "login"
    if (p.expired) return "expired"
    if (p.managed === false) return "unmanaged"
    if (worstLimit(p) >= warnFraction) return "limit"
    return "none"
  }
  function attentionColor(kind) {
    return kind === "login" || kind === "expired" || kind === "unmanaged" ? urgent : kind === "limit" ? accent : foreground
  }
  function attentionText(p) {
    var k = attentionFor(p)
    if (k === "login") return p.exists ? "Not signed in" : "Not set up"
    if (k === "expired") return "Login expired"
    if (k === "unmanaged") return "Auth file unlinked"
    if (k === "limit") return Math.round(worstLimit(p) * 100) + "% used"
    return ""
  }
  function activeAttention(tool) { return attentionFor(tool ? tool.active : null) }
  // the signed-in profile with the most headroom, when there is a real choice
  function headroomId(tool) {
    if (!tool || !tool.hasUsage) return ""
    var best = "", bestWorst = 2, n = 0
    for (var i = 0; i < tool.profiles.length; i++) {
      var p = tool.profiles[i]
      if (!p.signedIn || !(p.limits || []).length) continue
      n++
      if (worstLimit(p) < bestWorst) { bestWorst = worstLimit(p); best = p.id }
    }
    return n > 1 ? best : ""
  }

  // ---- formatting ----
  function maskEmail(email) {
    var s = String(email || ""); var at = s.indexOf("@")
    if (emailDisplay === "hidden") return ""
    if (emailDisplay === "full" || at <= 0) return s
    return s.slice(0, Math.min(3, at)) + "…" + s.slice(at)
  }
  function planLabel(p) {
    var t = String(p && p.plan || "").trim()
    if (t === "") return ""
    return t.charAt(0).toUpperCase() + t.slice(1)
  }
  function shortDir(dir) {
    var h = accounts.home
    return h && String(dir).indexOf(h) === 0 ? "~" + String(dir).slice(h.length) : String(dir)
  }
  function windowLabel(label) {
    var l = String(label || "")
    if (l.indexOf("Session") === 0) return "Session · 5h"
    if (l.indexOf("Weekly") === 0) return "Weekly · 7d"
    return l
  }
  function agoLabel(iso) {
    var ms = Date.parse(String(iso || "")); if (!isFinite(ms)) return ""
    var m = Math.round((nowMs - ms) / 60000)
    return m < 1 ? "just now" : m < 60 ? m + " min ago" : Math.round(m / 60) + " h ago"
  }
  function untilLabel(iso) {
    var t = Date.parse(String(iso || "")); if (!isFinite(t)) return ""
    var mins = Math.max(0, Math.round((t - nowMs) / 60000))
    if (mins < 60) return mins + "m"
    if (mins < 60 * 48) return Math.floor(mins / 60) + "h " + (mins % 60) + "m"
    return Math.floor(mins / 1440) + "d " + Math.floor((mins % 1440) / 60) + "h"
  }
  function heroMeta() {
    var signed = 0
    for (var i = 0; i < profiles.length; i++) if (profiles[i].signedIn) signed++
    var u = agoLabel(accounts.updatedAt)
    return signed + " of " + profiles.length + " profiles signed in" + (u ? " · " + u : "") + (accounts.busy || accounts.actionRunning ? " · working…" : "")
  }

  // ---- actions ----
  function moveCursor(dy) { if (tabProfiles.length === 0) return; cursorActive = true; cursor = ((cursor + dy) % tabProfiles.length + tabProfiles.length) % tabProfiles.length }
  function tabIndexOf(p) { for (var i = 0; i < tabProfiles.length; i++) if (tabProfiles[i].id === p.id) return i; return -1 }
  // widget settings live in shell.json; omarchy-bar set writes them and the shell hot-reloads
  function setWidgetSetting(key, value, json) {
    if (!bar) return
    bar.run("omarchy-bar set " + shellQuote(moduleName) + " " + shellQuote(key) + " " + shellQuote(String(value)) + (json ? " --json" : ""))
  }
  function useCursor() { var p = cursorProfile; if (p && !p.active) accounts.use(p.tool, p.id) }
  function loginCursor() { var p = cursorProfile; if (p) accounts.login(p.tool, p.id) }
  function shellCursor() { var p = cursorProfile; if (p && p.mode !== "link") accounts.shell(p.tool, p.id) }
  function refreshNow() { accounts.usageUpdate() }
  function nextTool(toolId) { accounts.next(toolId) }
  function shellQuote(v) { return "'" + String(v).replace(/'/g, "'\\''") + "'" }
  // Bar.run() is a fire-and-forget shell exec; omarchy-launch-editor opens the
  // user's editor in a terminal for TUI editors, or as a window otherwise.
  function openEditor() { if (bar) bar.run("omarchy-launch-editor " + shellQuote(accounts.confDir + "/accounts.json")) }

  Accounts {
    id: accounts
    intervalSec: Number(root.setting("statusIntervalSec", 300))
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
    function next(tool: string): string { root.nextTool(tool); return "ok" }
    function status(): string { return JSON.stringify(root.profiles) }
    function settings(): void { root.open(); root.view = "settings" }
  }

  visible: accounts.available && (root.barTools.length > 0 || root.tools.length > 0)
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ---------- Bar item: <mark><glyph> per tool ----------
  Item {
    id: button
    readonly property bool vertical: root.bar ? root.bar.vertical : false
    implicitWidth: vertical ? (root.bar ? root.bar.barSize : Style.bar.sizeVertical) : barRow.implicitWidth + Style.spaceReal(8.5) * 2
    implicitHeight: vertical ? barRow.implicitHeight + Style.space(6) * 2 : (root.bar ? root.bar.barSize : Style.bar.sizeHorizontal)
    anchors.fill: parent

    Row {
      id: barRow
      anchors.centerIn: parent
      spacing: Style.space(7)

      Text {
        visible: root.barTools.length === 0
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "󱚣"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.bar.iconFont
      }

      Repeater {
        model: root.barTools
        Row {
          id: toolCell
          required property var modelData
          readonly property string kind: root.activeAttention(modelData)
          readonly property color tint: root.attentionColor(kind)
          spacing: Style.space(3)

          Image {
            width: Style.bar.iconCanvas - Style.space(2)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            source: root.markSource(toolCell.modelData.id)
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
            opacity: toolCell.kind === "none" ? 1 : 0.85
          }
          Text {
            visible: root.showGlyphs && (!root.compactBar || toolCell.kind !== "none")
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: toolCell.modelData.active ? (toolCell.modelData.active.glyph || toolCell.modelData.active.label.charAt(0)) : "?"
            color: toolCell.tint
            font.family: root.fontFamily
            font.pixelSize: Style.bar.iconFont
            font.bold: true
          }
        }
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onClicked: function(ev) {
        if (ev.button === Qt.RightButton) accounts.shell()
        else if (ev.button === Qt.MiddleButton) root.nextTool("claude")
        else root.toggle()
      }
      onWheel: function(w) { if (Math.abs(w.angleDelta.y) >= 60) root.nextTool("codex") }
      onEntered: if (root.bar) root.bar.showTooltip(button, root.tooltipText())
      onExited: if (root.bar) root.bar.hideTooltip(button)
    }
  }

  function tooltipText() {
    var lines = []
    for (var i = 0; i < barTools.length; i++) {
      var t = barTools[i], a = t.active
      var extra = a ? attentionText(a) : ""
      lines.push(t.name + ": " + (a ? a.label : "—") + (extra ? " · " + extra : ""))
    }
    var hidden = tools.length - barTools.length
    if (hidden > 0) lines.push(hidden + " tool" + (hidden === 1 ? "" : "s") + " not signed in — open the panel to log in")
    lines.push("left panel · middle next Claude · scroll next Codex · right terminal")
    return lines.join("\n")
  }

  // ---------- Panel ----------
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(470))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))
    onOpenChanged: if (open) { root.view = "accounts"; if (root.selectedToolId === "" && root.tools.length) root.selectedToolId = root.tools[0].id }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.view === "settings" && (warnSlider.dragging || rotateSlider.dragging)

      onMoveRequested: function(dx, dy) {
        if (root.view !== "accounts") return
        if (dy !== 0) root.moveCursor(dy)
        if (dx !== 0) root.selectTab(root.selectedToolIndex + dx)
      }
      onActivateRequested: if (root.view === "accounts") root.useCursor()
      onCloseRequested: { if (root.view === "settings") root.view = "accounts"; else root.close() }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshNow()
        else if (t === "s" || t === "S") root.view = root.view === "settings" ? "accounts" : "settings"
        else if (t === "e" || t === "E") root.openEditor()
        else if (root.view !== "accounts") return
        else if (t === "i" || t === "I") root.loginCursor()
        else if (t === "t" || t === "T") root.shellCursor()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(10)

          // ---------- Hero ----------
          PanelHero {
            width: parent.width
            title: root.view === "settings" ? "Settings" : "Multi-Account Agent Manager"
            meta: root.view === "settings" ? "alerts · tools · display · setup" : root.heroMeta()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: root.view === "settings" ? "󰒓" : "󱚣"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              Row {
                spacing: Style.spacing.sm
                PanelActionButton {
                  visible: root.view === "accounts"
                  iconText: "󰑐"; tooltipText: "Refresh usage (r)"
                  foreground: root.foreground; fontFamily: root.fontFamily
                  onClicked: root.refreshNow()
                }
                PanelActionButton {
                  visible: root.view === "accounts"
                  iconText: "󰋖"; tooltipText: root.legend
                  foreground: root.foreground; fontFamily: root.fontFamily
                }
                PanelActionButton {
                  iconText: root.view === "settings" ? "󰁍" : "󰒓"
                  tooltipText: root.view === "settings" ? "Back (Esc)" : "Settings (s)"
                  foreground: root.foreground; fontFamily: root.fontFamily
                  onClicked: root.view = root.view === "settings" ? "accounts" : "settings"
                }
              }
            }
          }

          Text {
            visible: accounts.lastError !== ""
            width: parent.width
            text: accounts.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          // =================== ACCOUNTS VIEW ===================
          Column {
            visible: root.view === "accounts"
            width: parent.width
            spacing: Style.space(10)

            // setup nudge: one line, details live in settings
            Rectangle {
              visible: accounts.setupChecked && !accounts.setupComplete
              width: parent.width
              height: Style.space(30)
              radius: Style.cornerRadius
              color: root.alpha(root.urgent, 0.06)
              border.width: 1
              border.color: root.alpha(root.urgent, 0.4)
              Text {
                anchors.left: parent.left; anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Setup is incomplete — switches may not reach every terminal."
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Button {
                anchors.right: parent.right; anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: "Finish"; bordered: true; selected: true
                foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; fontSize: Style.font.caption
                onClicked: root.view = "settings"
              }
            }

            Text {
              visible: root.profiles.length === 0 && !accounts.busy
              width: parent.width
              topPadding: Style.space(16)
              text: "No tools discovered.\nInstall an AI coding CLI, then open this panel again."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }

            // ---------- Tabs: one per tool ----------
            Grid {
              id: tabs
              width: parent.width
              columns: root.tools.length > 4 ? 3 : Math.max(1, root.tools.length)
              columnSpacing: Style.spacing.md
              rowSpacing: Style.spacing.md
              visible: root.tools.length > 0
              readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

              Repeater {
                model: root.tools
                Rectangle {
                  id: tab
                  required property var modelData
                  required property int index
                  readonly property var a: modelData.active
                  readonly property string kind: root.activeAttention(modelData)
                  readonly property bool selected: index === root.selectedToolIndex
                  width: tabs.cellWidth
                  height: Style.space(42)
                  radius: Style.cornerRadius
                  color: selected ? root.track : (tabMouse.containsMouse ? root.alpha(root.foreground, 0.07) : root.alpha(root.foreground, 0.035))
                  border.width: 1
                  border.color: selected ? root.alpha(root.accent, 0.7) : root.alpha(root.attentionColor(kind), kind === "none" ? 0.12 : 0.55)

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(8)
                    Image {
                      width: Style.space(16); height: width
                      anchors.verticalCenter: parent.verticalCenter
                      source: root.markSource(tab.modelData.id)
                      sourceSize.width: width * 2; sourceSize.height: height * 2
                      fillMode: Image.PreserveAspectFit
                      opacity: root.toolSigned(tab.modelData) ? 1 : 0.45
                    }
                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        textFormat: Text.PlainText
                        text: tab.modelData.name
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: tab.selected
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: tab.a ? (tab.a.glyph ? tab.a.glyph + " " : "") + tab.a.label : "—"
                        color: root.attentionColor(tab.kind)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                  MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectTab(tab.index)
                  }
                }
              }
            }

            // ---------- Selected tool ----------
            Item {
              visible: !!root.selectedTool
              width: parent.width
              height: Style.space(22)
              Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)
                PanelSectionHeader {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.selectedTool ? root.selectedTool.name.toUpperCase() + " ACCOUNTS" : ""
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }
                Text {
                  visible: !!root.selectedTool && !root.selectedTool.hasUsage
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "· no usage feed"
                  color: root.faint
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
              Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)
                Rectangle {
                  visible: !!root.selectedTool && root.selectedTool.autoRotate
                  width: autoTxt.implicitWidth + Style.space(12); height: Style.space(16); radius: height / 2
                  color: root.alpha(root.accent, 0.12); border.width: 1; border.color: root.alpha(root.accent, 0.35)
                  Text { id: autoTxt; anchors.centerIn: parent; textFormat: Text.PlainText; text: "󰑐 auto"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                }
                Rectangle {
                  id: activePill
                  visible: !!root.selectedTool && !!root.selectedTool.active
                  width: activeTxt.implicitWidth + Style.space(14); height: Style.space(16); radius: height / 2
                  color: root.alpha(root.accent, 0.12); border.width: 1; border.color: root.alpha(root.accent, 0.35)
                  Text { id: activeTxt; anchors.centerIn: parent; textFormat: Text.PlainText; text: root.selectedTool && root.selectedTool.active ? "● " + root.selectedTool.active.label + "  󰓦" : ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.selectedTool) root.nextTool(root.selectedTool.id)
                    onEntered: if (root.bar) root.bar.showTooltip(activePill, "Click: switch to the next " + (root.selectedTool ? root.selectedTool.name : "") + " account")
                    onExited: if (root.bar) root.bar.hideTooltip(activePill)
                  }
                }
              }
            }

            Repeater {
              model: root.tabProfiles
              Rectangle {
                id: row
                required property var modelData
                readonly property var p: modelData
                readonly property int tabIndex: root.tabIndexOf(modelData)
                readonly property bool hasCursor: root.cursorActive && root.cursor === tabIndex
                readonly property string kind: root.attentionFor(p)
                width: parent.width
                implicitHeight: rowContent.implicitHeight + Style.space(9) * 2
                radius: Style.cornerRadius
                color: hasCursor ? root.track : (p.active ? root.alpha(root.foreground, 0.045) : "transparent")
                border.width: 1
                border.color: hasCursor ? root.alpha(root.foreground, 0.28) : root.alpha(root.foreground, p.active ? 0.10 : 0.05)

                Rectangle {
                  anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                  anchors.margins: Style.space(6)
                  width: Style.space(3); radius: width / 2
                  color: row.p.active ? root.accent : "transparent"
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: { root.cursorActive = true; root.cursor = row.tabIndex }
                  onExited: root.cursorActive = false
                  onDoubleClicked: root.useCursor()
                  onClicked: { root.cursorActive = true; root.cursor = row.tabIndex }
                }

                Row {
                  id: rowContent
                  anchors.left: parent.left; anchors.right: parent.right
                  anchors.leftMargin: Style.space(14); anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(10)

                  // badge: provider mark with the profile letter pinned
                  Item {
                    width: Style.space(34); height: width
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                      anchors.fill: parent; radius: width / 2
                      color: row.p.active ? root.alpha(root.accent, 0.16) : root.alpha(root.foreground, 0.06)
                      border.width: 1; border.color: row.p.active ? root.alpha(root.accent, 0.5) : root.alpha(root.foreground, 0.12)
                    }
                    Image {
                      anchors.centerIn: parent; width: Style.space(18); height: width
                      source: root.markSource(row.p.tool); sourceSize.width: width * 2; sourceSize.height: height * 2
                      fillMode: Image.PreserveAspectFit; opacity: row.p.signedIn ? 1 : 0.45
                    }
                    Rectangle {
                      anchors.right: parent.right; anchors.bottom: parent.bottom
                      anchors.rightMargin: -Style.space(2); anchors.bottomMargin: -Style.space(2)
                      width: Style.space(16); height: width; radius: width / 2
                      color: row.p.active ? root.accent : root.surface
                      border.width: 1; border.color: row.p.active ? root.accent : root.alpha(root.foreground, 0.25)
                      Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: row.p.glyph || row.p.label.charAt(0); color: row.p.active ? root.surface : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                    }
                  }

                  Column {
                    width: Style.space(78)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)
                    Text {
                      textFormat: Text.PlainText
                      text: row.p.label + (root.headroomId(root.selectedTool) === row.p.id ? " ▲" : "")
                      color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true
                      elide: Text.ElideRight; width: parent.width
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: root.shortDir(row.p.dir)
                      color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle; width: parent.width
                    }
                  }

                  Column {
                    id: info
                    width: rowContent.width - Style.space(10) * 3 - Style.space(34) - Style.space(78) - actions.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Text {
                      visible: row.p.signedIn
                      width: info.width
                      textFormat: Text.StyledText
                      text: root.escapeHtml(root.maskEmail(row.p.email) || "signed in")
                        + (root.planLabel(row.p) ? "  <font color=\"" + root.accent + "\">" + root.escapeHtml(root.planLabel(row.p).toUpperCase()) + "</font>" : "")
                      color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
                      clip: true
                    }
                    Text {
                      visible: !row.p.signedIn || row.kind === "expired" || row.kind === "unmanaged"
                      textFormat: Text.PlainText
                      text: root.attentionText(row.p)
                      color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true
                    }
                    Text {
                      visible: !row.p.signedIn && row.hasCursor
                      width: info.width
                      textFormat: Text.PlainText
                      text: row.p.loginNote || "Login opens a terminal for the sign-in."
                      color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }
                    Text {
                      visible: row.kind === "unmanaged"
                      width: info.width
                      textFormat: Text.PlainText
                      text: "Run `agent-acct init` to re-link the auth file into this profile."
                      color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    Column {
                      visible: row.p.signedIn && (row.p.limits || []).length > 0
                      width: info.width
                      spacing: Style.space(3)
                      Repeater {
                        model: row.p.limits || []
                        Column {
                          id: meter
                          required property var modelData
                          readonly property real pct: Math.max(0, Math.min(1, Number(modelData.percent || 0)))
                          readonly property bool hot: pct >= root.warnFraction
                          width: info.width
                          spacing: Style.space(2)
                          Item {
                            width: parent.width; height: meterLabel.implicitHeight
                            Text { id: meterLabel; anchors.left: parent.left; textFormat: Text.PlainText; text: root.windowLabel(meter.modelData.label); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                            Text { anchors.right: parent.right; textFormat: Text.PlainText; text: Math.round(meter.pct * 100) + "%" + (meter.modelData.resetsAt ? "  ·  " + root.untilLabel(meter.modelData.resetsAt) : ""); color: meter.hot ? root.urgent : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                          }
                          Rectangle {
                            width: parent.width; height: Math.max(3, Style.space(4)); radius: height / 2
                            color: root.alpha(root.foreground, 0.13)
                            Rectangle { width: parent.width * meter.pct; height: parent.height; radius: parent.radius; color: meter.hot ? root.urgent : root.accent }
                          }
                        }
                      }
                    }
                    Text {
                      visible: row.p.signedIn && (row.p.limits || []).length > 0 && !!row.p.usageUpdatedAt
                      textFormat: Text.PlainText
                      text: "usage " + root.agoLabel(row.p.usageUpdatedAt)
                      color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    }
                    Text {
                      visible: row.p.signedIn && (row.p.limits || []).length === 0
                      textFormat: Text.PlainText
                      text: row.p.hasUsage === false ? "No limits published for this tool."
                        : (row.p.todayPrompts !== null && row.p.todayPrompts !== undefined
                           ? "today " + row.p.todayPrompts + " prompts · estimated from local sessions"
                           : (row.p.usageStatusText || "No usage yet — press r after the first session."))
                      color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                      width: info.width; wrapMode: Text.WordWrap
                    }
                  }

                  // actions: Login always (the call to action); Use / Shell only on hover or cursor
                  Column {
                    id: actions
                    spacing: Style.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(64)
                    Button {
                      visible: !row.p.signedIn || row.kind === "expired"
                      width: parent.width; text: "Login"; iconText: "󰍂"; bordered: true; selected: true
                      foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; fontSize: Style.font.caption; iconSize: Style.font.caption; horizontalPadding: Style.space(6)
                      onClicked: accounts.login(row.p.tool, row.p.id)
                    }
                    Button {
                      visible: row.hasCursor && !row.p.active && row.p.signedIn
                      width: parent.width; text: "Use"; iconText: "󰄬"; bordered: true
                      foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; fontSize: Style.font.caption; iconSize: Style.font.caption; horizontalPadding: Style.space(6)
                      onClicked: accounts.use(row.p.tool, row.p.id)
                    }
                    Button {
                      visible: row.hasCursor && row.p.signedIn && row.p.mode !== "link"
                      width: parent.width; text: "Shell"; iconText: ""; bordered: true
                      foreground: root.foreground; fontFamily: root.fontFamily; fontSize: Style.font.caption; iconSize: Style.font.caption; horizontalPadding: Style.space(6)
                      tooltipText: "Terminal with this account's env"
                      onClicked: accounts.shell(row.p.tool, row.p.id)
                    }
                    Text {
                      visible: !row.hasCursor && row.p.signedIn && row.kind !== "expired"
                      width: parent.width; horizontalAlignment: Text.AlignRight
                      textFormat: Text.PlainText
                      text: row.p.active ? "active" : "⋯"
                      color: row.p.active ? root.accent : root.faint
                      font.family: root.fontFamily; font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }
          }

          // =================== SETTINGS VIEW ===================
          Column {
            visible: root.view === "settings"
            width: parent.width
            spacing: Style.space(12)

            // ---- Alerts ----
            Column {
              width: parent.width
              spacing: Style.space(6)
              Item {
                width: parent.width; height: Style.space(22)
                PanelSectionHeader { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "ALERTS"; foreground: root.foreground; fontFamily: root.fontFamily }
                Row {
                  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(8)
                  Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "notifications"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: accounts.alerts.enabled !== false
                    foreground: root.foreground; accent: root.accent
                    onToggled: accounts.setAlert("enabled", accounts.alerts.enabled === false ? "on" : "off")
                  }
                }
              }
              Column {
                width: parent.width; spacing: Style.space(2)
                Item {
                  width: parent.width; height: warnLabel.implicitHeight
                  Text { id: warnLabel; anchors.left: parent.left; textFormat: Text.PlainText; text: "Warn when a window reaches"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                  Text { anchors.right: parent.right; textFormat: Text.PlainText; text: Math.round(warnSlider.liveValue * 100) + " %"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
                PanelSlider {
                  id: warnSlider
                  width: parent.width
                  bar: root.bar
                  minimum: 0.5; maximum: 1; step: 0.05
                  value: Number(accounts.alerts.warnAt || 0.85)
                  onReleased: function(v) { accounts.setAlert("warnAt", v.toFixed(2)) }
                }
                Text { width: parent.width; textFormat: Text.PlainText; text: "One notification per crossing, per account and window. Also tints the bar letter."; color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              }
              Column {
                width: parent.width; spacing: Style.space(2)
                Item {
                  width: parent.width; height: rotLabel.implicitHeight
                  Text { id: rotLabel; anchors.left: parent.left; textFormat: Text.PlainText; text: "Auto-rotate when the active account reaches"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                  Text { anchors.right: parent.right; textFormat: Text.PlainText; text: Math.round(rotateSlider.liveValue * 100) + " %"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
                PanelSlider {
                  id: rotateSlider
                  width: parent.width
                  bar: root.bar
                  minimum: 0.5; maximum: 1; step: 0.05
                  value: Number(accounts.alerts.rotateAt || 0.9)
                  onReleased: function(v) { accounts.setAlert("rotateAt", v.toFixed(2)) }
                }
                Text { width: parent.width; textFormat: Text.PlainText; text: "Only for tools with auto-rotate on (below) and another signed-in account under the threshold. New launches only; running sessions keep their account."; color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              }
            }

            PanelSeparator { width: parent.width; foreground: root.foreground }

            // ---- Tools ----
            Column {
              width: parent.width
              spacing: Style.space(4)
              Item {
                width: parent.width; height: Style.space(22)
                PanelSectionHeader { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "TOOLS"; foreground: root.foreground; fontFamily: root.fontFamily }
                Row {
                  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(14)
                  Text { textFormat: Text.PlainText; text: "auto-rotate"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; width: Style.space(70); horizontalAlignment: Text.AlignHCenter }
                  Text { textFormat: Text.PlainText; text: "in bar"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; width: Style.space(52); horizontalAlignment: Text.AlignHCenter }
                }
              }
              Repeater {
                model: root.tools
                Item {
                  id: toolRow
                  required property var modelData
                  width: parent.width; height: Style.space(30)
                  Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(8)
                    Image { width: Style.space(14); height: width; anchors.verticalCenter: parent.verticalCenter; source: root.markSource(toolRow.modelData.id); sourceSize.width: width * 2; sourceSize.height: height * 2; fillMode: Image.PreserveAspectFit }
                    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: toolRow.modelData.name; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: (toolRow.modelData.mode === "link" ? "auth link" : "env dir") + (toolRow.modelData.hasUsage ? "" : " · no usage feed"); color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }
                  Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(14)
                    Item {
                      width: Style.space(70); height: Style.space(26)
                      ToggleSwitch {
                        anchors.centerIn: parent
                        visible: toolRow.modelData.mode === "env" && toolRow.modelData.hasLimits
                        checked: toolRow.modelData.autoRotate === true
                        foreground: root.foreground; accent: root.accent
                        onToggled: accounts.setAutoRotate(toolRow.modelData.id, !(toolRow.modelData.autoRotate === true))
                      }
                      Text { anchors.centerIn: parent; visible: !(toolRow.modelData.mode === "env" && toolRow.modelData.hasLimits); textFormat: Text.PlainText; text: "—"; color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    }
                    Item {
                      width: Style.space(52); height: Style.space(26)
                      ToggleSwitch {
                        anchors.centerIn: parent
                        checked: toolRow.modelData.barHidden !== true
                        foreground: root.foreground; accent: root.accent
                        onToggled: accounts.setBarHidden(toolRow.modelData.id, !(toolRow.modelData.barHidden === true))
                      }
                    }
                  }
                }
              }
              Text { width: parent.width; textFormat: Text.PlainText; text: "Auto-rotate needs published limits (Claude, Codex) and an env-mode tool. Tools with no signed-in account stay out of the bar regardless (see Display)."; color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
            }

            PanelSeparator { width: parent.width; foreground: root.foreground }

            // ---- Display ----
            Column {
              width: parent.width
              spacing: Style.space(6)
              PanelSectionHeader { text: "DISPLAY"; foreground: root.foreground; fontFamily: root.fontFamily }
              Item {
                width: parent.width; height: Style.spacing.controlHeight
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Account email"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                Dropdown {
                  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(120)
                  showLabel: false
                  options: ["masked", "hidden", "full"]
                  value: root.emailDisplay
                  fontFamily: root.fontFamily
                  onChanged: function(v) { root.setWidgetSetting("emailDisplay", v, false) }
                }
              }
              Repeater {
                model: [
                  { key: "showGlyphs", label: "Show account letters (α/Ω) in the bar", on: root.showGlyphs },
                  { key: "compactBar", label: "Compact bar: letters only when something needs attention", on: root.compactBar },
                  { key: "barShowUnsigned", label: "Show tools with no signed-in account in the bar", on: root.barShowUnsigned }
                ]
                Item {
                  required property var modelData
                  width: parent.width; height: Style.space(28)
                  Text { anchors.left: parent.left; anchors.right: parent.right; anchors.rightMargin: Style.space(70); anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: modelData.label; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                  ToggleSwitch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: modelData.on
                    foreground: root.foreground; accent: root.accent
                    onToggled: root.setWidgetSetting(modelData.key, !modelData.on, true)
                  }
                }
              }
            }

            PanelSeparator { width: parent.width; foreground: root.foreground }

            // ---- Setup ----
            Column {
              width: parent.width
              spacing: Style.space(6)
              Item {
                width: parent.width; height: Style.space(22)
                PanelSectionHeader { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "SETUP"; foreground: root.foreground; fontFamily: root.fontFamily }
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: accounts.setupComplete ? "complete" : "incomplete"; color: accounts.setupComplete ? root.accent : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
              Repeater {
                model: accounts.setupSteps
                Row {
                  required property var modelData
                  spacing: Style.space(6)
                  Text { textFormat: Text.PlainText; text: modelData.ok ? "✓" : "✗"; color: modelData.ok ? root.accent : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  Text { textFormat: Text.PlainText; text: modelData.label; color: modelData.ok ? root.dim : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                }
              }
              Row {
                spacing: Style.spacing.sm
                Button { text: "Run setup"; iconText: "󰒓"; bordered: true; selected: !accounts.setupComplete; foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; fontSize: Style.font.caption; onClicked: accounts.runSetup() }
                Button { text: "Remove wiring"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; fontSize: Style.font.caption; tooltipText: "agent-acct setup --remove (keeps your profiles)"; onClicked: accounts.removeSetup() }
              }
              Text { width: parent.width; textFormat: Text.PlainText; text: "All user-space, no sudo. Setup edits ~/.bashrc, adds a session env file and a systemd --user timer, and hides the stock single-account tabs; Remove undoes exactly that."; color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
            }

            PanelSeparator { width: parent.width; foreground: root.foreground }

            // ---- Registry ----
            Column {
              width: parent.width
              spacing: Style.space(6)
              PanelSectionHeader { text: "REGISTRY"; foreground: root.foreground; fontFamily: root.fontFamily }
              Row {
                spacing: Style.spacing.sm
                Button { text: "Edit accounts.json"; iconText: "󰏫"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; fontSize: Style.font.caption; onClicked: root.openEditor() }
                Button { text: "Refresh usage"; iconText: "󰑐"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; fontSize: Style.font.caption; onClicked: root.refreshNow() }
              }
              Text { width: parent.width; textFormat: Text.PlainText; text: "Link-mode tools (Cursor, OpenCode): switch with no session of that tool open. " + (accounts.version ? "v" + accounts.version + " · " : "") + "agent-acct --help in a terminal for everything else."; color: root.faint; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
            }
          }
        }
      }
    }
  }
}
