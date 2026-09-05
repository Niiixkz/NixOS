pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import qs.Utils as Utils

Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData
        implicitWidth: modelData.width
        implicitHeight: modelData.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell:background"
        color: "black"

        readonly property double aspectRatio: modelData.width / modelData.height
        readonly property string orientation: aspectRatio >= 1.0 ? "H" : "V"

        //Wallpaper
        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop

            source: Backend.wallpaperCount0 === "" ? "" : `https://raw.githubusercontent.com/Niiixkz/Wallpaper/main/${Backend.wallpaperCount0}/${orientation}.avif`
            opacity: Backend.toggle ? 0 : 1

            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            onStatusChanged: {
                if (status !== Image.Ready || source === "")
                    return

                Backend.monitorReady()
            }
        }

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop

            source: Backend.wallpaperCount1 === "" ? "" : `https://raw.githubusercontent.com/Niiixkz/Wallpaper/main/${Backend.wallpaperCount1}/${orientation}.avif`
            opacity: Backend.toggle ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            onStatusChanged: {
                if (status !== Image.Ready || source === "")
                    return

                Backend.monitorReady()
            }
        }


        //Clock
        Item {
            visible: Backend.clockFail[orientation] ? false : true

            anchors {
                left: parent.left
                top: parent.top

                leftMargin: Backend.clockLeftMargin[orientation] - clockTexts.width / 2
                topMargin: Backend.clockTopMargin[orientation] - clockTexts.height / 2

                Behavior on leftMargin {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                    }
                }
                Behavior on topMargin {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                    }
                }
            }

            SystemClock {
                id: systemClock
                precision: SystemClock.Minutes
            }

            ColumnLayout {
                id: clockTexts
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 62
                    font.weight: Font.Bold
                    text: Qt.formatDateTime(systemClock.date, "hh:mm")
                    color: (Backend.clockTone[orientation] == "light"
                            ? Utils.Colors.background : Utils.Colors.foreground)
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    text: Qt.formatDateTime(systemClock.date, "ddd, MM/dd")
                    color: (Backend.clockTone[orientation] == "light"
                            ? Utils.Colors.background : Utils.Colors.foreground)
                }
            }
        }
    }
}

