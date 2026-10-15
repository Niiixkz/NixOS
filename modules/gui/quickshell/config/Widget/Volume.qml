import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Pipewire

import qs.Window as Window
import qs.Utils as Utils

Scope {
    id: root

    // true = toggle 開啟的大面板；false = up/down 彈出的小面板
    property bool isAdvanceSetting: false

    readonly property real volumeStep: 0.05

    // ───────────── 尺寸常數（全部自己算，不依賴 Layout） ─────────────
    readonly property int padding: 20      // 內容與 panel 四邊的間距
    readonly property int gap: 12          // 元素之間
    readonly property int iconW: 28
    readonly property int barH: 8
    readonly property int rowH: 36
    readonly property int nameMax: 428

    // 小面板內容：icon + 音量條 + 百分比
    readonly property int miniBarW: 200
    readonly property int miniPctW: 40
    readonly property int miniH: 28
    readonly property int miniContentW: iconW + gap + miniBarW + gap + miniPctW

    // 大面板內容：icon + 音量條 + 名稱 + rowPad
    readonly property int fullBarW: 220
    readonly property int nameX: iconW + gap + fullBarW + gap
    property real fullContentW: nameX 
    property real fullContentH: rowH

    // panel 最終尺寸（內容 + 四邊 padding）
    readonly property real panelW: (isAdvanceSetting ? fullContentW : miniContentW) + padding * 2
    readonly property real panelH: (isAdvanceSetting ? fullContentH : miniH) + padding * 2

    TextMetrics {
        id: nameMetrics
        font.pixelSize: 14
        font.bold: true     // 以粗體量測，取上限
    }

    function recalcSize() {
        const n = entries.length
        let maxName = 0
        entries.forEach(e => {
            nameMetrics.text = nodeName(e)
            maxName = Math.max(maxName, Math.min(Math.ceil(nameMetrics.advanceWidth), nameMax))
        })
        fullContentW = nameX + maxName 
        fullContentH = n > 0 ? n * rowH + (n - 1) : rowH
    }

    // ───────────── 圖示 ─────────────
    function iconFor(node, isSink) {
        const a = node ? node.audio : null
        if (!a) return isSink ? "" : ""
        if (isSink) {
            if (a.muted || a.volume <= 0) return ""
            if (a.volume < 0.34) return ""
            if (a.volume < 0.67) return ""
            return ""
        }
        return a.muted ? "󰍮" : "󰍬"
    }

    function nodeName(n) {
        return n.description || n.nickname || n.name
    }

    // ───────────── 裝置清單：預設輸出 → 預設輸入 → 其他輸出 → 其他輸入 ─────────────
    function buildEntries() {
        const nodes = Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
        const defSink = Pipewire.defaultAudioSink
        const defSrc = Pipewire.defaultAudioSource

        const sinks = nodes.filter(n => n.isSink)
        const sources = nodes.filter(n => !n.isSink)

        const result = []
        if (defSink && sinks.indexOf(defSink) >= 0) result.push(defSink)
        if (defSrc && sources.indexOf(defSrc) >= 0) result.push(defSrc)
        sinks.forEach(n => { if (n !== defSink) result.push(n) })
        sources.forEach(n => { if (n !== defSrc) result.push(n) })
        return result
    }

    property var entries: buildEntries()
    onEntriesChanged: recalcSize()
    Component.onCompleted: recalcSize()

    // 以 node id 記住選取，這樣設為預設後清單重排選取仍跟著該裝置
    property int selectedId: -1
    readonly property int selectedIndex: {
        const i = entries.findIndex(n => n.id === selectedId)
        return i < 0 ? 0 : i
    }
    readonly property var selectedNode: entries.length > 0 ? entries[selectedIndex] : null

    // 需 bind node 才能讀寫 audio.volume / muted
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    // ───────────── 音量操作 ─────────────
    function adjustVolume(node, delta) {
        if (!node || !node.audio) return
        node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta))
        if (delta > 0 && node.audio.muted) node.audio.muted = false
    }

    function toggleMute(node) {
        if (!node || !node.audio) return
        node.audio.muted = !node.audio.muted
    }

    function moveSelection(d) {
        if (entries.length === 0) return
        const i = Math.max(0, Math.min(entries.length - 1, selectedIndex + d))
        selectedId = entries[i].id
    }

    function setAsDefault(node) {
        if (!node) return
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }

    // ───────────── 按鍵 ─────────────
    function handleKey(event) {
        handleControlKey(event)
        event.accepted = true
    }

    function handleControlKey(event) {
        switch (event.key) {
            case Qt.Key_Escape:
            root.isAdvanceSetting = false
            Window.Backend.popWindow("volume")
            break

            case Qt.Key_H:
            case Qt.Key_Left:
            adjustVolume(selectedNode, -volumeStep)
            break

            case Qt.Key_L:
            case Qt.Key_Right:
            adjustVolume(selectedNode, volumeStep)
            break

            case Qt.Key_J:
            case Qt.Key_Down:
            moveSelection(1)
            break

            case Qt.Key_K:
            case Qt.Key_Up:
            moveSelection(-1)
            break

            case Qt.Key_Return:
            case Qt.Key_Enter:
            setAsDefault(selectedNode)
            break

            case Qt.Key_M:
            toggleMute(selectedNode)
            break

            default:
            break
        }
    }

    // ───────────── 視窗開關 ─────────────
    function findPanel() {
        if (!Hyprland.focusedMonitor) return null
        const p = panelVariants.instances.find(
            p => p.screenName === Hyprland.focusedMonitor.name
        )
        if (!p) console.warn("找不到對應螢幕的 panel:", Hyprland.focusedMonitor.name)
        return p ?? null
    }

    // 尺寸直接用 root 算好的 panelW / panelH，
    // 不讀 panel.width（window 尚未顯示時 Item 還沒完成排版，第一次會是舊值）
    function pushRegion(targetPanel) {
        Window.Backend.pushWindow({
            "screenName": targetPanel.screenName,
            "name": "volume",
            "regions": {
                "panel": [1, root.panelW, root.panelH, 0],
            },
            "callback": targetPanel.callback
        })
    }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.isAdvanceSetting)
                Window.Backend.popWindow("volume")
        }
    }

    // 小面板：顯示並重新計時 3 秒。大面板開著時不切換模式
    function showMiniPanel() {
        if (root.isAdvanceSetting) return   // toggle 優先

        const p = findPanel()
        if (!p) return

        if (!p.visible)
            pushRegion(p)

        hideTimer.restart()
    }

    // up/down 呼叫
    function nudgeDefaultSink(delta) {
        adjustVolume(Pipewire.defaultAudioSink, delta)
        showMiniPanel()
    }

    // mute 呼叫
    function muteDefaultSink() {
        toggleMute(Pipewire.defaultAudioSink)
        showMiniPanel()
    }

    // ───────────── 共用音量條 ─────────────
    component VolumeBar: Rectangle {
        property var node: null
        readonly property real value: node && node.audio ? node.audio.volume : 0
        readonly property bool muted: node && node.audio ? node.audio.muted : false

        radius: height / 2
        color: Utils.Colors.color15
        property color innerColor: Utils.Colors.color1

        Rectangle {
            id: inner
            width: parent.width * Math.max(0, Math.min(1, parent.value))
            height: parent.height
            radius: parent.radius
            color: parent.innerColor
            opacity: parent.muted ? 0.4 : 1.0

            Behavior on width {
                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
            }
        }
    }

    // ───────────── 視窗 ─────────────
    Variants {
        id: panelVariants
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            property var modelData
            screen: modelData
            readonly property var screenName: modelData.name

            property alias panel: panel

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            color: "transparent"
            visible: false
            WlrLayershell.layer: WlrLayer.Overlay

            readonly property bool isThisMonitorFocused: {
                var focusedMon = Hyprland.focusedMonitor
                return focusedMon && focusedMon.name === screenName
            }

            WlrLayershell.keyboardFocus: {
                if (visible && isThisMonitorFocused && root.isAdvanceSetting) {
                    Utils.Functions.imeEnable(false)
                    return WlrKeyboardFocus.Exclusive
                }
                return WlrKeyboardFocus.None
            }

            mask: Region {}

            Rectangle {
                id: panel
                radius: 20
                color: "transparent"
                visible: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }

                // ── 小面板 ──
                Item {
                    id: miniView
                    visible: !root.isAdvanceSetting
                    x: root.padding
                    y: root.padding
                    width: root.miniContentW
                    height: root.miniH

                    Text {
                        x: 0
                        width: root.iconW
                        height: root.miniH
                        text: root.iconFor(Pipewire.defaultAudioSink, true)
                        font.pixelSize: 22
                        color: Utils.Colors.color15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    VolumeBar {
                        x: root.iconW + root.gap
                        y: (root.miniH - root.barH) / 2
                        width: root.miniBarW
                        height: root.barH
                        node: Pipewire.defaultAudioSink
                    }

                    Text {
                        readonly property var a: Pipewire.defaultAudioSink
                                                 ? Pipewire.defaultAudioSink.audio : null
                        x: root.iconW + root.gap + root.miniBarW + root.gap
                        width: root.miniPctW
                        height: root.miniH
                        text: a ? Math.round(a.volume * 100) + "%" : "--"
                        color: Utils.Colors.color15
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // ── 大面板 ──
                Item {
                    id: fullView
                    visible: root.isAdvanceSetting
                    x: root.padding
                    y: root.padding
                    width: root.fullContentW
                    height: root.fullContentH

                    Repeater {
                        model: root.entries

                        Rectangle {
                            id: row
                            required property var modelData
                            required property int index

                            readonly property bool isDefault: modelData.isSink
                                ? modelData === Pipewire.defaultAudioSink
                                : modelData === Pipewire.defaultAudioSource
                            readonly property bool selected: index === root.selectedIndex

                            x: 0
                            y: index * root.rowH
                            width: root.fullContentW
                            height: root.rowH
                            radius: 10
                            color: selected ? Utils.Colors.color15 : "transparent"

                            Text {
                                x: 0
                                width: root.iconW
                                height: root.rowH
                                text: root.iconFor(row.modelData, row.modelData.isSink)
                                font.pixelSize: 20
                                color: selected ? Utils.Colors.color0 : Utils.Colors.color15
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            VolumeBar {
                                x: root.iconW + root.gap
                                y: (root.rowH - root.barH) / 2
                                width: root.fullBarW
                                height: root.barH
                                node: row.modelData
                                color: selected ? Utils.Colors.color0 : Utils.Colors.color15
                                innerColor: selected ? Utils.Colors.color1 : Utils.Colors.color1
                            }

                            Text {
                                x: root.nameX
                                width: row.width - root.nameX
                                height: root.rowH
                                text: root.nodeName(row.modelData)
                                color: selected ? Utils.Colors.color0 : Utils.Colors.color15
                                opacity: row.isDefault ? 1.0 : 0.7
                                font.pixelSize: 14
                                font.bold: row.isDefault
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            contentItem {
                focus: true
                Keys.onPressed: event => {
                    root.handleKey(event)
                }
            }

            function callback(str, rects) {
                panelVariants.instances.forEach(p => {
                    const active = p.screenName === screenName && str !== "";
                    p.visible = active;

                    if (!active) return;

                    const configs = {
                        panel: 0
                    };

                    Object.entries(configs).forEach(([key, offset]) => {
                        const rect = rects?.[key];
                        if (!rect) return;

                        const [x, y, w, h] = rect;
                        Object.assign(p[key], {
                            x: x + offset,
                            y: y + offset,
                            width: w - offset * 2,
                            height: h - offset * 2
                        });
                    });

                    Object.keys(configs).forEach(key => {
                        p[key].opacity = str.includes(key);
                    });
                });
            }
        }
    }

    // ───────────── IPC ─────────────
    IpcHandler {
        target: `volume`

        function toggle() {
            const targetPanel = root.findPanel()
            if (!targetPanel) return

            hideTimer.stop()

            // 大面板已開 → 關閉
            if (targetPanel.visible && root.isAdvanceSetting) {
                root.isAdvanceSetting = false
                Window.Backend.popWindow("volume")
                return
            }

            // 否則開大面板（小面板顯示中也直接升級，toggle 優先）
            root.selectedId = Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.id : -1
            root.recalcSize()
            root.isAdvanceSetting = true      // 先切模式，panelW/panelH 才是大面板的值
            root.pushRegion(targetPanel)
        }

        function up() {
            root.nudgeDefaultSink(root.volumeStep)
        }

        function down() {
            root.nudgeDefaultSink(-root.volumeStep)
        }

        function mute() {
            root.muteDefaultSink()
        }
    }
}
