import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Variants {
    model: Quickshell.screens
    id: root
    
    property var instanceMap: ({})
    
    /**
     * 通知特定螢幕的Bar要顯示或隱藏
     * @param screenIndex - 螢幕索引
     * @param visible - true顯示，false隱藏
     */
    function setVisibility(screenIndex, visible) {
        if (!instanceMap[screenIndex])
            return
        instanceMap[screenIndex].setVisibilityInternal(visible)
    }
    
    PanelWindow {
        id: panelWindow
        property var modelData
        screen: modelData
        
        readonly property int screenIndex: Quickshell.screens.indexOf(modelData)
        readonly property string monitorName: modelData.name
        
        // 根據螢幕名稱確定workspace起始編號
        readonly property int workspaceBase: {
            if (monitorName === "eDP-1") return 1
            if (monitorName === "HDMI-A-1") return 11
            if (monitorName === "DP-1") return 21
            return 1
        }
        
        Component.onCompleted: {
            root.instanceMap[screenIndex] = panelWindow
        }
        
        anchors {
            top: true
            left: true
            right: true
        }
        
        implicitHeight: 30
        color: "transparent"
        mask: Region { item: container }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: 0
        
        /**
         * 動畫顯示/隱藏
         */
        function setVisibilityInternal(visible) {
            if (visible) {
                visibilityAnimation.to = 1.0
                visibilityAnimation.duration = 100
                visibilityAnimation.easing.type = Easing.OutQuad
            } else {
                visibilityAnimation.to = 0.0
                visibilityAnimation.duration = 100
                visibilityAnimation.easing.type = Easing.InQuad
            }
            visibilityAnimation.start()
        }
        
        NumberAnimation {
            id: visibilityAnimation
            target: container
            property: "opacity"
        }
        
        Item {
            id: container
            anchors.centerIn: parent
            width: childrenRect.width
            height: parent.height
            
            Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                
                Repeater {
                    model: 8
                    
                    Rectangle {
                        width: 40
                        height: 20
                        radius: 20
                        
                        readonly property int workspaceId: panelWindow.workspaceBase + index
                        
                        // 檢查是否是focused螢幕的當前workspace
                        readonly property bool isFocusedActive: {
                            var focusedMon = Hyprland.focusedMonitor
                            return focusedMon && 
                                   focusedMon.name === panelWindow.monitorName && 
                                   Hyprland.focusedWorkspace.id === workspaceId
                        }
                        
                        // 檢查是否是非focused螢幕的當前workspace
                        readonly property bool isUnfocusedActive: {
                            var focusedMon = Hyprland.focusedMonitor
                            if (!focusedMon || focusedMon.name === panelWindow.monitorName)
                                return false
                            
                            // 找到這個螢幕上的當前workspace
                            var monitors = Hyprland.monitors.values
                            for (var i = 0; i < monitors.length; i++) {
                                if (monitors[i].name === panelWindow.monitorName) {
                                    var activeWs = monitors[i].activeWorkspace
                                    return activeWs && activeWs.id === workspaceId
                                }
                            }
                            return false
                        }
                        
                        color: {
                            if (isFocusedActive) return Colors.foreground
                            if (isUnfocusedActive) return Colors.midground
                            return Colors.background
                        }
                        
                        border.color: Colors.foreground
                        border.width: 1
                        
                        Text {
                            anchors.centerIn: parent
                            text: (index + 1).toString()
                            color: {
                                if (parent.isFocusedActive) return Colors.background
                                if (parent.isUnfocusedActive) return Colors.background
                                return Colors.foreground
                            }
                            font.pixelSize: 12
                            font.bold: true
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                Hyprland.dispatch("workspace " + parent.workspaceId)
                            }
                        }
                        
                        // 平滑過渡顏色變化
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
            }
        }
        
        Connections {
            target: Colors
            function onColorsChanged() {
                // 顏色改變時自動更新
            }
        }
        
        Connections {
            target: Hyprland
            function onFocusedMonitorChanged() {
                // monitor改變時強制更新所有按鈕
            }
            function onFocusedWorkspaceChanged() {
                // workspace改變時強制更新所有按鈕
            }
        }
    }
}
