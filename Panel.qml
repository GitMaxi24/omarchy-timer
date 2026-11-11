import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "maxi.timer"
  ipcTarget: "maxi.timer"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var settings: ({})
  property double nowTick: Date.now()
  readonly property var barIdentity: hostWidget || root
  readonly property var timerEntries: hostWidget ? hostWidget.timerEntries : []
  readonly property int timerCount: hostWidget ? hostWidget.timerCount : 0
  readonly property int runningCount: hostWidget ? hostWidget.runningCount : 0
  readonly property bool running: runningCount > 0
  readonly property bool paused: hostWidget ? hostWidget.paused : false
  readonly property int remainingSeconds: hostWidget ? hostWidget.remainingSeconds : 0
  readonly property int shownSeconds: remainingSeconds
  readonly property string label: running ? formatTime(remainingSeconds) : ""
  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color bg: bar ? bar.background : Commons.Color.background
  readonly property color accentColor: Commons.Color.accent
  property string customInput: ""
  property int customUnitIndex: 1

  function formatTime(s) { return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
  function openFromHotkey() {
    root.controller.show()
    Qt.callLater(function() { if (root.opened) setCenterHoverRevealSuppressed(true) })
  }
  function open() { setCenterHoverRevealSuppressed(false); root.controller.show() }
  function close() { setCenterHoverRevealSuppressed(false); root.controller.hide() }
  function toggle() { if (root.opened) close(); else openFromHotkey() }
  function closeForPopoutSwitch() { close() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(barIdentity, direction)
    return false
  }
  function setCenterHoverRevealSuppressed(value) {
    if (bar && typeof bar.setCenterHoverRevealSuppressed === "function") bar.setCenterHoverRevealSuppressed(value)
  }
  function startMinutes(minutes) { hostWidget.rememberAndStart(Number(minutes) * 60) }
  function startCustom() {
    var amount = Number(customInput)
    var multiplier = customUnitIndex === 0 ? 1 : customUnitIndex === 1 ? 60 : 3600
    var maxAmount = 86400 / multiplier
    if (timerCount >= 3 || !isFinite(amount) || amount <= 0 || amount > maxAmount) return
    if (hostWidget.rememberAndStart(Math.round(amount * multiplier))) customField.text = ""
  }

  Timer { interval: 200; repeat: true; running: true; onTriggered: root.nowTick = Date.now() }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: popup.fittedContentWidth(Style.space(390))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      width: Math.max(0, popup.contentWidth - popup.padding * 2 - Border.left(popup.borderSpec) - Border.right(popup.borderSpec))
      spacing: Style.space(16)
      clip: true
      clip: true

      Row {
        width: parent.width
        spacing: Style.space(12)
        Column {
          width: parent.width - closeButton.width - Style.space(12)
          Text { text: root.timerCount > 0 ? root.formatTime(root.shownSeconds) : "Timer"; color: root.fg; font.pixelSize: 30; font.bold: true }
          Text { text: root.timerCount === 0 ? "READY WHEN YOU ARE" : root.timerCount + " TIMER" + (root.timerCount === 1 ? "" : "S") + " · " + root.runningCount + " RUNNING"; color: root.fg; opacity: 0.55; font.pixelSize: 10; font.letterSpacing: 1.4 }
        }
        Button { id: closeButton; text: "×"; onClicked: root.close() }
      }

      Rectangle {
        width: parent.width; height: 4; radius: 2
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
        clip: true
        Rectangle {
          width: parent.width * (root.hostWidget && root.hostWidget.primaryTimer ? Math.max(0.015, Math.min(1, (root.hostWidget.primaryTimer.duration - root.hostWidget.primaryTimer.remainingSeconds) / root.hostWidget.primaryTimer.duration)) : 0)
          height: parent.height; radius: 2; color: root.accentColor
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.timerCount > 0
        Repeater {
          model: root.timerEntries
          delegate: Row {
            id: timerRow
            required property var modelData
            required property int index
            width: parent.width
            spacing: Style.space(8)
            readonly property bool timerPaused: Number(modelData.pausedRemaining || 0) > 0
            readonly property int timerRemaining: timerPaused ? Number(modelData.pausedRemaining) : Math.max(0, Math.ceil((Number(modelData.endAt || 0) - root.nowTick) / 1000))

            Text {
              width: Math.max(Style.space(80), parent.width - pauseButton.implicitWidth - cancelButton.implicitWidth - Style.space(16))
              text: "Timer " + (timerRow.index + 1) + "  ·  " + root.formatTime(timerRow.timerRemaining) + (timerRow.timerPaused ? "  PAUSED" : "")
              color: root.fg
              font.pixelSize: Style.font.bodySmall
              verticalAlignment: Text.AlignVCenter
            }
            Button {
              id: pauseButton
              text: timerRow.timerPaused ? "Resume" : "Pause"
              onClicked: timerRow.timerPaused ? root.hostWidget.resumeTimer(timerRow.modelData.id) : root.hostWidget.pauseTimer(timerRow.modelData.id)
            }
            Button {
              id: cancelButton
              text: "Cancel"
              onClicked: root.hostWidget.stopTimer(timerRow.modelData.id)
            }
          }
        }
      }

      Text { text: "QUICK START · " + root.timerCount + "/3"; color: root.fg; opacity: 0.58; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2 }
      Flow {
        width: parent.width; spacing: Style.space(8)
        Repeater {
          model: [1, 5, 10, 15, 20, 25, 30]
          delegate: Button {
            required property int modelData
            text: modelData + " min"
            enabled: root.timerCount < 3
            onClicked: root.startMinutes(modelData)
          }
        }
      }

      Row {
        width: Math.max(0, parent.width - Style.space(4))
        spacing: Style.space(8)
        TextField {
          id: customField
          width: Math.max(0, parent.width - customUnitSelector.width - customButton.implicitWidth - Style.space(16))
          placeholderText: "Custom duration"
          enabled: root.timerCount < 3
          font.pixelSize: customButton.fontSize
          inputMethodHints: Qt.ImhDigitsOnly
          validator: IntValidator { bottom: 1; top: root.customUnitIndex === 0 ? 86400 : root.customUnitIndex === 1 ? 1440 : 24 }
          onTextChanged: root.customInput = text
          onAccepted: root.startCustom()
        }
        ComboBox {
          id: customUnitSelector
          width: Style.space(58)
          font.pixelSize: customButton.fontSize
          model: ["sec", "min", "hr"]
          currentIndex: root.customUnitIndex
          enabled: root.timerCount < 3
          onActivated: root.customUnitIndex = currentIndex
        }
        Button { id: customButton; text: "Start"; width: implicitWidth; enabled: root.timerCount < 3; onClicked: root.startCustom() }
      }

      Column {
        width: parent.width; spacing: Style.space(7)
        visible: Array.isArray(root.settings.recentTimes) && root.settings.recentTimes.length > 0
        Text { text: "RECENT"; color: root.fg; opacity: 0.58; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2 }
        Row {
          spacing: Style.space(8)
          Repeater {
            model: root.settings.recentTimes || []
            delegate: Button {
              required property var modelData
              enabled: root.timerCount < 3
              text: Number(modelData) % 60 === 0 ? (Number(modelData) / 60) + " min" : Math.floor(Number(modelData) / 60) + ":" + (Number(modelData) % 60 < 10 ? "0" : "") + (Number(modelData) % 60)
              onClicked: root.hostWidget.rememberAndStart(Number(modelData))
            }
          }
        }
      }

    }
  }
}
