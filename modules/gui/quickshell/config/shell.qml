import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import qs.Wallpaper

ShellRoot {
    WallpaperFrontend { }

    // TopBar {
    //     id: topBar
    // }

    // 實例化Border並連接TopBar
    Border {
        id: border
        topBar: topBar
    }

    // Launcher {
    //     id: launcher
    // }


    // IpcHandler {
    //     target: "control"
    //
    //     property bool launcherVisible: false
    //     function launcherToggle(monitorIndex: int) {
    //         launcherVisible = !launcherVisible
    //         border.setCorners(monitorIndex, launcherVisible ? [[5, 600, 400, 0]] : [[5, 0, 0, 0]])
    //         launcher.setVisibility(monitorIndex, launcherVisible)
    //     }
    // }

    // Timer {
    //     interval: 1000
    //     running: true
    //     onTriggered: border.borderSetCorners(1, [[7, 400, 200, 0]])
    // }
    // Timer {
    //     interval: 2000
    //     running: true
    //     // onTriggered: border.borderSetCorners(0, [[0, 0, 0], [1, 0, 0]])
    //     // onTriggered: border.borderSetCorners(0, [[0, 200, 200], [1, 600, 100]])
    //     onTriggered: border.borderSetCorners(1, [[1, 500, 500, -200]])
    // }
    // Timer {
    //     interval: 3000
    //     running: true
    //     onTriggered: border.borderSetCorners(1, [[0, 100, 100], [1, 0, 0, 0], [2, 200, 100]])
    // }
    // Timer {
    //     interval: 4000
    //     running: true
    //     onTriggered: border.borderSetCorners(1, [[0, 200, 100]])
    // }
    // Timer {
    //     interval: 5000
    //     running: true
    //     onTriggered: border.borderSetCorners(1, [[0, 0, 0], [2, 0, 0]])
    // }
}

