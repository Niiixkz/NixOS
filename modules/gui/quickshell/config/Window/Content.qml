import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.Utils as Utils

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

        WlrLayershell.keyboardFocus: {
            if (visible
                && Backend.focusName === root.widgetName
                && Backend.focusScreen === screenName) {
                Utils.Functions.imeEnable(false)
                return WlrKeyboardFocus.Exclusive
            }
            return WlrKeyboardFocus.None
        }

        contentItem {
            focus: true
            Keys.onPressed: event => Backend.dispatchKey(event)
        }

        Loader {
            id: loader
            anchors.fill: parent
            sourceComponent: root.content
        }

        // 依 objectName 找 region Item(結果會快取)
        property var _regionCache: ({})
        function region(name) {
            if (_regionCache[name]) return _regionCache[name];

            const find = (node) => {
                if (node.objectName === name) return node;
                for (const c of node.children) {
                    const r = find(c);
                    if (r) return r;
                }
                return null;
            };

            const found = loader.item ? find(loader.item) : null;
            if (found) _regionCache[name] = found;
            return found;
        }

        function callback(str, rects) {
            root.instances.forEach(p => {
                const active = p.screenName === screenName && str !== "";
                p.visible = active;

                if (!active) return;

                Object.entries(root.configs).forEach(([key, offset]) => {
                    const item = p.region(key);
                    const rect = rects?.[key];
                    if (!item || !rect) return;

                    const [x, y, w, h] = rect;
                    Object.assign(item, {
                        x: x + offset,
                        y: y + offset,
                        width: w - offset * 2,
                        height: h - offset * 2
                    });
                });

                Object.keys(root.configs).forEach(key => {
                    const item = p.region(key);
                    if (item) item.opacity = str.includes(key);
                });
            });
        }
    }
}
