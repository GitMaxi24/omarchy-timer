import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "maxi.timer"

  property double nowTick: Date.now()
  property int nextTimerId: 0
  readonly property var timerEntries: {
    if (Array.isArray(settings.timers)) return settings.timers
    var endAt = Number(settings.endAt || 0)
    var pausedRemaining = Number(settings.pausedRemaining || 0)
    if (endAt > 0 || pausedRemaining > 0)
      return [{ id: "legacy", duration: Number(settings.duration || 60), endAt: endAt, pausedRemaining: pausedRemaining }]
    return []
  }
  readonly property int timerCount: timerEntries.length
  readonly property int runningCount: {
    var count = 0
    for (var i = 0; i < timerEntries.length; i++)
      if (Number(timerEntries[i].endAt || 0) > nowTick) count++
    return count
  }
  readonly property int pausedCount: {
    var count = 0
    for (var i = 0; i < timerEntries.length; i++)
      if (Number(timerEntries[i].pausedRemaining || 0) > 0) count++
    return count
  }
  readonly property bool running: runningCount > 0
  readonly property bool paused: pausedCount > 0
  readonly property var primaryTimer: {
    var selected = null
    var leastRemaining = Infinity
    for (var i = 0; i < timerEntries.length; i++) {
      var entry = timerEntries[i]
      var pausedRemaining = Number(entry.pausedRemaining || 0)
      var endAt = Number(entry.endAt || 0)
      var remaining = pausedRemaining > 0 ? pausedRemaining : Math.max(0, Math.ceil((endAt - nowTick) / 1000))
      if (selected === null || remaining < leastRemaining) {
        selected = { id: String(entry.id || i), duration: Number(entry.duration || 60), endAt: endAt, pausedRemaining: pausedRemaining, remainingSeconds: remaining, paused: pausedRemaining > 0 }
        leastRemaining = remaining
      }
    }
    return selected
  }
  readonly property int remainingSeconds: primaryTimer ? primaryTimer.remainingSeconds : 0
  readonly property string timeLabel: {
    var m = Math.floor(remainingSeconds / 60)
    var s = remainingSeconds % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  function refresh() { nowTick = Date.now() }
  function storedTimers() {
    if (Array.isArray(settings.timers)) return settings.timers.map(function(t) {
      return { id: String(t.id || ""), duration: Number(t.duration || 60), endAt: Number(t.endAt || 0), pausedRemaining: Number(t.pausedRemaining || 0) }
    })
    var endAt = Number(settings.endAt || 0)
    var pausedRemaining = Number(settings.pausedRemaining || 0)
    return endAt > 0 || pausedRemaining > 0
      ? [{ id: "legacy", duration: Number(settings.duration || 60), endAt: endAt, pausedRemaining: pausedRemaining }]
      : []
  }
  function save(patch) {
    var next = { id: moduleName }
    for (var k in settings) if (k !== "id") next[k] = settings[k]
    for (var p in patch) next[p] = patch[p]
    if (patch.timers !== undefined) {
      var first = patch.timers.length > 0 ? patch.timers[0] : null
      next.duration = first ? Number(first.duration || 60) : 60
      next.endAt = first ? Number(first.endAt || 0) : 0
      next.pausedRemaining = first ? Number(first.pausedRemaining || 0) : 0
    }
    settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, next)
  }
  function rememberAndStart(seconds) {
    seconds = Math.max(1, Math.min(86400, Math.floor(seconds)))
    var timers = storedTimers()
    if (timers.length >= 3) return false
    var recent = Array.isArray(settings.recentTimes) ? settings.recentTimes.slice(0) : []
    recent = recent.filter(function(v) { return Number(v) !== seconds })
    recent.unshift(seconds)
    if (recent.length > 4) recent.length = 4
    timers.push({ id: Date.now().toString() + "-" + (++nextTimerId), duration: seconds, endAt: Date.now() + seconds * 1000, pausedRemaining: 0 })
    save({ recentTimes: recent, timers: timers })
    refresh()
    return true
  }
  function pauseTimer(timerId) {
    var timers = storedTimers()
    for (var i = 0; i < timers.length; i++) if (String(timers[i].id) === String(timerId)) {
      var remaining = Math.max(0, Math.ceil((Number(timers[i].endAt || 0) - Date.now()) / 1000))
      if (remaining > 0) { timers[i].endAt = 0; timers[i].pausedRemaining = remaining; save({ timers: timers }); refresh() }
      return
    }
  }
  function resumeTimer(timerId) {
    var timers = storedTimers()
    for (var i = 0; i < timers.length; i++) if (String(timers[i].id) === String(timerId)) {
      var seconds = Number(timers[i].pausedRemaining || 0)
      if (seconds > 0) { timers[i].endAt = Date.now() + seconds * 1000; timers[i].pausedRemaining = 0; save({ timers: timers }); refresh() }
      return
    }
  }
  function stopTimer(timerId) {
    var timers = storedTimers()
    if (timerId === undefined) timers = []
    else timers = timers.filter(function(t) { return String(t.id) !== String(timerId) })
    save({ timers: timers })
    refresh()
  }
  function completeExpiredTimers() {
    var timers = storedTimers()
    var now = Date.now()
    var completed = timers.filter(function(t) { return Number(t.endAt || 0) > 0 && Number(t.endAt) <= now })
    if (completed.length === 0) return
    var remaining = timers.filter(function(t) { return Number(t.endAt || 0) === 0 || Number(t.endAt) > now })
    save({ timers: remaining })
    refresh()
    Quickshell.execDetached(["/usr/bin/pw-play", "--media-role", "Notification", "--volume", "1.0", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"])
    var count = completed.length
    Quickshell.execDetached(["omarchy-notification-send", "--app-name", "omarchy-action", "-u", "normal", "-t", "10000", count === 1 ? "Timer complete" : count + " timers complete", count === 1 ? "Your countdown has finished." : count + " countdowns have finished."])
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.openFromHotkey() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (opened) close(); else open() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function injectPanel() {
    var p = panelLoader.item
    if (!p) return
    p.bar = bar; p.settings = settings; p.anchorItem = root.timerCount > 0 ? countdownButton : button; p.hostWidget = root
  }
  implicitWidth: root.timerCount > 0 ? countdownButton.implicitWidth : button.implicitWidth
  implicitHeight: root.timerCount > 0 ? countdownButton.implicitHeight : button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: { refresh(); injectPanel() }

  Timer {
    interval: 200; repeat: true; running: true
    onTriggered: { root.refresh(); root.completeExpiredTimers() }
  }
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }
  BarIconButton {
    id: button
    anchors.fill: parent
    visible: root.timerCount === 0
    bar: root.bar
    text: root.timerCount > 0 ? root.timeLabel : ""
    slotSize: Style.bar.statusSlot
    iconComponent: root.timerCount > 0 ? null : clockIcon
    tooltipText: root.timerCount === 0 ? "Timer" : root.timerCount + (root.timerCount === 1 ? " timer" : " timers") + " · " + root.runningCount + " running · click to manage"
    onPressed: function(b) { if (b === Qt.LeftButton) root.togglePanel() }

    Component {
      id: clockIcon
      Item {
        Rectangle {
          anchors.centerIn: parent
          width: 10; height: 10; radius: 5
          color: "transparent"
          border.width: 1
          border.color: button.foreground
        }
        Rectangle {
          width: 1; height: 3.5; radius: 1
          color: button.foreground
          anchors.horizontalCenter: parent.horizontalCenter
          y: parent.height / 2 - 3.5
        }
        Rectangle {
          width: 3; height: 1; radius: 1
          color: button.foreground
          x: parent.width / 2
          y: parent.height / 2 - 0.2
        }
      }
    }
  }
  WidgetButton {
    id: countdownButton
    anchors.fill: parent
    visible: root.timerCount > 0
    bar: root.bar
    text: root.timeLabel
    labelVisible: true
    fontSize: Style.font.body
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.timerCount + (root.timerCount === 1 ? " timer" : " timers") + " · " + root.runningCount + " running · click to manage"
    onPressed: function(b) { if (b === Qt.LeftButton) root.togglePanel() }
  }
}
