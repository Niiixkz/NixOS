//         readonly property int screenIndex: Quickshell.screens.indexOf(modelData)
//
//         Component.onCompleted: {
//             root.instanceMap[screenIndex] = panelWindow
//         }
//
//         anchors {
//             bottom: true
//         }
//
//         implicitWidth: 600
//         implicitHeight: 400
//         margins.bottom: 5
//         color: "transparent"
//         mask: Region { }
//         WlrLayershell.layer: WlrLayer.Overlay
//         WlrLayershell.exclusiveZone: 0
//         WlrLayershell.keyboardFocus: container.opacity > 0.0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
//
//         function setVisibilityInternal(visible) {
//             if (visible) {
//                 visibilityAnimation.to = 1.0
//                 visibilityAnimation.duration = 100
//                 visibilityAnimation.easing.type = Easing.OutQuad
//             } else {
//                 visibilityAnimation.to = 0.0
//                 visibilityAnimation.duration = 100
//                 visibilityAnimation.easing.type = Easing.InQuad
//             }
//             visibilityAnimation.start()
//         }
//
//         NumberAnimation {
//             id: visibilityAnimation
//             target: container
//             property: "opacity"
//         }
//
//         Item {
//             id: container
//             anchors.centerIn: parent
//             width: childrenRect.width
//             height: parent.height
//             opacity: 0
//         }
//
//         Connections {
//             target: Colors
//             function onColorsChanged() {
//                 // 顏色改變時自動更新
//             }
//         }
//     }
// }

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Controls

Variants {
    model: Quickshell.screens
    id: root
    
    property var instanceMap: ({})
    
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
        
        Component.onCompleted: {
            root.instanceMap[screenIndex] = panelWindow
        }
        
        anchors {
            bottom: true
        }
        
        implicitWidth: 600
        implicitHeight: 400
        margins.bottom: 5
        color: "transparent"
        mask: Region { }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: 0
        
        // 檢查當前螢幕是否是focused monitor
        readonly property bool isThisMonitorFocused: {
            var focusedMon = Hyprland.focusedMonitor
            return focusedMon && focusedMon.name === panelWindow.monitorName
        }
        
        // 根據是否是focused monitor和可見性來決定鍵盤焦點
        WlrLayershell.keyboardFocus: {
            if (container.opacity > 0.0 && isThisMonitorFocused) {
                return WlrKeyboardFocus.Exclusive
            }
            return WlrKeyboardFocus.None
        }
        
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
            opacity: 0
        }
        
        Connections {
            target: Colors
            function onColorsChanged() {
                // 顏色改變時自動更新
            }
        }

		contentItem {
			focus: true
			Keys.onPressed: event => {
				// if (event.key == Qt.Key_Escape) Qt.quit();
				// else {
				// 	for (let i = 0; i < buttons.length; i++) {
				// 		let button = buttons[i];
				// 		if (event.key == button.keybind) button.exec();
				// 	}
				// }
                console.log(event.key)
			}
		}
    }
}
