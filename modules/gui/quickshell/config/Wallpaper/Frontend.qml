pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.Utils as Utils

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData
        implicitWidth: modelData.width
        implicitHeight: modelData.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell:background"
        color: "black"

        readonly property string orientation: modelData.width >= modelData.height ? "H" : "V"

        // ── 兩個圖層輪流當上層 / 下層 (由 Backend.topSlot 決定) ──
        //    下層：目前桌布，永遠不透明
        //    上層：新桌布，載入完後 opacity 0 -> 1
        //    淡入完成後兩層對調：淡入完的上層直接變成下層，不需重新載入；
        //    舊下層被清空並瞬間變回透明，等待下一次
        Repeater {
            model: 2

            Image {
                id: img

                required property int index
                readonly property bool isTop: Backend.topSlot === index

                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: Backend.wallpaperUrl(Backend.slots[index], win.orientation)

                z: isTop ? 1 : 0
                opacity: isTop ? 0 : 1

                onStatusChanged: {
                    if (!isTop)
                        return;
                    if (status === Image.Ready)
                        Backend.overlayReady(win.modelData.name);
                    else if (status === Image.Error)
                        Backend.overlayFailed();
                }

                states: State {
                    name: "shown"
                    when: img.isTop && Backend.overlayVisible
                    PropertyChanges { target: img; opacity: 1 }
                }

                // 只有 "進入 shown" 有動畫；離開時沒有 transition，所以是瞬間切換
                transitions: Transition {
                    to: "shown"
                    NumberAnimation {
                        property: "opacity"
                        duration: Backend.fadeDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }

        // ── 時鐘 ──
        Item {
            id: clock
            z: 2

            readonly property color textColor: Backend.clockTone[win.orientation] === "light"
                                               ? Utils.Colors.background : Utils.Colors.foreground

            visible: !Backend.clockFail[win.orientation]
            x: Backend.clockLeftMargin[win.orientation] - clockTexts.width / 2
            y: Backend.clockTopMargin[win.orientation] - clockTexts.height / 2

            Behavior on x {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                }
            }

            SystemClock {
                id: systemClock
                enabled: clock.visible
                precision: SystemClock.Minutes
            }

            ColumnLayout {
                id: clockTexts

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 62
                    font.weight: Font.Bold
                    color: clock.textColor
                    text: Qt.formatDateTime(systemClock.date, "hh:mm")
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: clock.textColor
                    text: Qt.formatDateTime(systemClock.date, "ddd, MM/dd")
                }
            }
        }
    }
}
