import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    // ── 由各 widget 注入 ──
    required property string widgetName   // 對應 Backend 的 name
    required property var configs         // region 名稱 -> offset(名稱 = region Item 的 objectName)
    property Component content            // widget 的內容

    delegate: PanelWindow {
        id: win

        property var modelData
        screen: modelData
        readonly property string screenName: modelData ? modelData.name : ""

        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        visible: false
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay

        // 鍵盤焦點與按鍵不再由各 panel 處理，
        // 統一由 Frontend 的 window 接收後交給 Backend.dispatchKey 派發

        Loader {
            id: loader
            anchors.fill: parent
            sourceComponent: root.content
            onLoaded: win._buildRegionMap()
        }

        property var _regions: ({})
        function _buildRegionMap() {
            const map = {};
            for (const child of loader.item.children) {
                if (child.objectName) map[child.objectName] = child;
            }
            _regions = map;
        }

        function region(name) {
            return _regions[name] ?? null;
        }

        function callback(str, rects) {
            const keys = str === "" ? [] : str.split(",");
            win.visible = keys.length > 0;
            if (!win.visible) return;

            for (const key in root.configs) {
                const item = win.region(key);
                if (!item) continue;

                const offset = root.configs[key];
                const rect = rects?.[key];
                if (rect) {
                    item.x = rect[0] + offset;
                    item.y = rect[1] + offset;
                    item.width = rect[2] - offset * 2;
                    item.height = rect[3] - offset * 2;
                }
                item.opacity = keys.includes(key) ? 1 : 0;
            }
        }
    }
}
