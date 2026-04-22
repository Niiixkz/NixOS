pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import qs

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

            source: WallpaperBackend.wallpaperCount0 === "" ? "" : `https://raw.githubusercontent.com/Niiixkz/Wallpaper/main/${WallpaperBackend.wallpaperCount0}/${orientation}.avif`
            opacity: WallpaperBackend.toggle ? 0 : 1

            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            onStatusChanged: {
                if (status !== Image.Ready || source === "")
                    return

                WallpaperBackend.monitorReady()
            }
        }

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop

            source: WallpaperBackend.wallpaperCount1 === "" ? "" : `https://raw.githubusercontent.com/Niiixkz/Wallpaper/main/${WallpaperBackend.wallpaperCount1}/${orientation}.avif`
            opacity: WallpaperBackend.toggle ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
            onStatusChanged: {
                if (status !== Image.Ready || source === "")
                    return

                WallpaperBackend.monitorReady()
            }
        }


        //Clock
        Item {
            visible: WallpaperBackend.clockFail[orientation] ? false : true

            anchors {
                left: parent.left
                top: parent.top

                leftMargin: WallpaperBackend.clockLeftMargin[orientation] - this.childrenRect.width / 2
                topMargin: WallpaperBackend.clockTopMargin[orientation] - this.childrenRect.height / 2

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
                    font.pixelSize: 80
                    font.weight: Font.Bold
                    text: Qt.formatDateTime(systemClock.date, "hh:mm")
                    color: (WallpaperBackend.clockTone[orientation] == "light"
                            ? Colors.background : Colors.foreground)

                    Behavior on color {
                        ColorAnimation {
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
                Text {
                    horizontalAlignment: Text.AlignRight
                    Layout.rightMargin: 20
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    text: Qt.formatDateTime(systemClock.date, "dddd, MM/dd")
                    color: (WallpaperBackend.clockTone[orientation] == "light"
                            ? Colors.background : Colors.foreground)

                    Behavior on color {
                        ColorAnimation {
                            easing.type:Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }
}

