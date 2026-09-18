import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io

import qs.Window as Window
import qs.Utils as Utils

Scope {
    id: root

    property string filterText: ""

    // ------------------------------------------------------------------
    // 程式清單 & 模糊比對
    // ------------------------------------------------------------------

    readonly property var programs: ["firefox", "osu!", "obs"]

    // 簡單的「子序列」模糊比對,順便記錄:
    // - firstIndex:pattern 第一個字元在 text 中第一次出現的位置(給排序用)
    // - matchedIndices:pattern 每個字元各自比對到 text 中的哪個索引(給上色用)
    // 例如 pattern="ff" 對 text="firefox":第一個 f -> index0,第二個 f -> index4
    //      -> matched=true, firstIndex=0, matchedIndices=[0,4]
    function fuzzyMatchInfo(pattern, text) {
        if (pattern.length === 0) return { matched: true, firstIndex: 0, matchedIndices: [] }
        var p = pattern.toLowerCase()
        var t = text.toLowerCase()
        var pi = 0
        var firstIndex = -1
        var matchedIndices = []
        for (var ti = 0; ti < t.length && pi < p.length; ti++) {
            if (t[ti] === p[pi]) {
                if (pi === 0) firstIndex = ti
                matchedIndices.push(ti)
                pi++
            }
        }
        return { matched: pi === p.length, firstIndex: firstIndex, matchedIndices: matchedIndices }
    }

    function fuzzyMatch(pattern, text) {
        return fuzzyMatchInfo(pattern, text).matched
    }

    // 字元分類排序權重:數字 < 大寫字母 < 小寫字母 < 符號
    function charRank(ch) {
        if (ch >= "0" && ch <= "9") return 0
        if (ch >= "A" && ch <= "Z") return 1
        if (ch >= "a" && ch <= "z") return 2
        return 3
    }

    // 依「數字、大寫字母、小寫字母、符號」的順序逐字比較兩個字串
    function compareByCharOrder(a, b) {
        var len = Math.max(a.length, b.length)
        for (var i = 0; i < len; i++) {
            if (i >= a.length) return -1
            if (i >= b.length) return 1
            var ra = charRank(a[i])
            var rb = charRank(b[i])
            if (ra !== rb) return ra - rb
            if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1
        }
        return 0
    }

    // 所有符合 filterText 的程式,依「最左優先」排序,同分再依 charRank 排序
    // 例如打 "o":obs、osu! 的 o 都在 index0,firefox 的 o 在 index5 -> obs/osu! 排前面;
    //          obs 跟 osu! 同分時比較下一個字元 'b' vs 's','b' 較前 -> obs 排最前
    readonly property var matchedNames: {
        if (filterText.length === 0) return []

        var candidates = []
        for (var i = 0; i < programs.length; i++) {
            var info = fuzzyMatchInfo(filterText, programs[i])
            if (info.matched) {
                candidates.push({ name: programs[i], firstIndex: info.firstIndex })
            }
        }

        candidates.sort(function(a, b) {
            if (a.firstIndex !== b.firstIndex) return a.firstIndex - b.firstIndex
            return compareByCharOrder(a.name, b.name)
        })

        return candidates.map(function(c) { return c.name })
    }

    // 目前只顯示「最佳匹配」(matchedNames 排序後的第一筆)。
    // 如果你想要同時列出多筆匹配結果,可以改成走訪 matchedNames 疊出多排 SlotColumn。
    readonly property string bestMatch: matchedNames.length > 0 ? matchedNames[0] : ""

    // 目前要顯示的整個「詞」:有匹配就顯示匹配到的程式名稱,
    // 沒匹配到就直接顯示目前打的字(不再用隨機亂數字串)。
    readonly property string displayText: bestMatch.length > 0 ? bestMatch : filterText
    readonly property bool isMatch: bestMatch.length > 0

    // bestMatch 裡「真正被輸入字元比對到」的位置索引。
    // 例如打 "ff" 比對到 "firefox":第一個 f 在 index0、第二個 f 在 index4 -> [0, 4]
    // 只有這些位置的字元要上色 color15,其餘(包含上下裝飾列)都是 color1。
    readonly property var matchedIndices: isMatch
        ? fuzzyMatchInfo(filterText, bestMatch).matchedIndices
        : []

    // 顯示用欄數,至少 1 欄(輸入為空時給個空白佔位)
    readonly property int columnCount: Math.max(1, displayText.length)

    // ------------------------------------------------------------------
    // 執行程式
    // ------------------------------------------------------------------

    // 大部分程式直接用同名指令啟動;osu! 比較特別,要透過 nvidia-offload 啟動。
    // 之後如果還有其他特例,直接在這裡加對應關係就好。
    function commandFor(name) {
        switch (name) {
            case "osu!": return "nvidia-offload osu!"
            default: return name
        }
    }

    // 用 sh 把指令叫起來,並 disown 讓它脫離這個 process、不受 launcher 生命週期影響。
    function launchProgram(name) {
        if (!name) return
        launchProcess.command = ["sh", "-c", commandFor(name) + " & disown"]
        launchProcess.running = true
    }

    Process {
        id: launchProcess
        running: false
    }

    // ------------------------------------------------------------------
    // Keyboard Dispatcher
    // ------------------------------------------------------------------

    function handleKey(event) {
        handleSearchKey(event)
        event.accepted = true
    }

    function handleSearchKey(event) {
        switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
            // enter:有匹配到程式就啟動它,接著清空搜尋字串、回到 NORMAL MODE、收起面板
            if (root.isMatch) {
                root.launchProgram(root.bestMatch)
            }
            Window.Backend.popWindow("launcher")
            break

            case Qt.Key_Backspace:
            root.filterText = root.filterText.slice(0, -1)
            break

            default:
            // 每按一個可見字元就即時 filter 一次
            if (event.text && event.text.length > 0 && event.text.charCodeAt(0) >= 0x20) {
                root.filterText += event.text
            }
            break
        }
    }

    Variants {
        id: panelVariants          // 加上 id,之後才能存取 instances
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
            WlrLayershell.layer: WlrLayer.Top

            // 檢查當前螢幕是否是focused monitor
            readonly property bool isThisMonitorFocused: {
                var focusedMon = Hyprland.focusedMonitor
                return focusedMon && focusedMon.name === screenName
            }

            // 根據是否是focused monitor和可見性來決定鍵盤焦點
            WlrLayershell.keyboardFocus: {
                if (visible && isThisMonitorFocused) {
                    Utils.Functions.imeEnable(false)
                    return WlrKeyboardFocus.Exclusive
                }
                return WlrKeyboardFocus.None
            }

            Rectangle {
                id: panel
                radius: 20
                color: "transparent"
                visible: true

                // ---- 螢幕參數(目前寫死 1920x1080;若要支援其他解析度的螢幕,
                //      可以改成 panelWindow.width / panelWindow.height) ----
                readonly property int screenWidth: 1920
                readonly property int screenHeight: 1080
                readonly property int bottomGap: 20 // 離底部的間距

                // 水平置中、貼齊底部往上留 bottomGap。
                // 因為只有 width 會變動(height 固定 3 列),
                // 這兩條 binding 會讓面板在變寬時保持「以底部中線為錨點」左右展開。
                x: (screenWidth - width) / 2
                y: screenHeight - bottomGap - height

                // ---- 版面參數:改這裡調整字型大小/間距 ----
                readonly property int rowHeight: 30
                readonly property int charWidth: 20
                readonly property int margin: 20 // Row 四周的留白
                property font slotFont: Qt.font({ family: "monospace", pixelSize: 20 })

                width: root.columnCount * charWidth + margin * 2
                height: 3 * rowHeight + margin * 2

                onWidthChanged: Window.Backend.updateWindow({
                    name: "launcher",
                    regions: { panel: [5, width, height, 0] }
                })

                // 一整排「整體滾輪」:每一欄自己貫穿上/中/下三列,
                // 目標字元會從上面或下面滾過,最後落定在中間那格。
                // 四周留 panel.margin(20px)的間距 —— 這是靠下面 syncSize() 把
                // panel 尺寸算成「Row 本身大小 + margin*2」,再用 centerIn 置中做到的。
                Row {
                    id: reelRow
                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                        model: root.columnCount

                        // ---- 以下是原本 SlotColumn.qml 的內容,直接內嵌成 delegate ----
                        // 一整欄「貫穿上/中/下三列」的拉霸滾軸。三列其實是同一條帶子上
                        // 相鄰的三格,目標字元從上面或下面滾入時會先經過上/下那格,
                        // 再捲到中間落定,視覺上是一個整體。
                        delegate: Item {
                            id: cell
                            required property int index

                            // 這一欄現在應該落定的字元;字比欄數短時補空白
                            readonly property string ch: index < root.displayText.length
                                ? root.displayText[index]
                                : " "
                            // 只有這個位置是「輸入字元實際比對到」的才用 highlightColor,
                            // 其餘字元(包含這欄自己的上下裝飾格、跟其他欄)都是 baseColor。
                            readonly property bool isMatched: root.matchedIndices.indexOf(index) !== -1

                            readonly property color baseColor: Utils.Colors.color1
                            readonly property color highlightColor: Utils.Colors.color15
                            readonly property int rowHeight: panel.rowHeight
                            readonly property int charWidth: panel.charWidth
                            readonly property font targetFont: panel.slotFont

                            readonly property var charset: "abcdefghijklmnopqrstuvwxyz0123456789!@#$%".split("")

                            // 目前顯示中的整條帶子;每一格是 {ch, isTarget}。
                            // isTarget 標記「這一格是不是落定後的目標字元格」,只有它才可能用
                            // highlightColor,其餘(含上下鄰居格、滾動過場的隨機字元)一律 baseColor。
                            property var _sequence: [
                                { ch: " ", isTarget: false },
                                { ch: cell.ch, isTarget: true },
                                { ch: " ", isTarget: false }
                            ]

                            width: charWidth
                            height: rowHeight * 3 // 固定顯示三格(上/中/下)
                            clip: true

                            Column {
                                id: reel
                                width: cell.width

                                Repeater {
                                    model: cell._sequence
                                    delegate: Text {
                                        required property var modelData
                                        text: modelData.ch
                                        font: cell.targetFont
                                        width: cell.width
                                        height: cell.rowHeight
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        color: (modelData.isTarget && cell.isMatched) ? cell.highlightColor : cell.baseColor
                                    }
                                }
                            }

                            NumberAnimation {
                                id: anim
                                target: reel
                                property: "y"
                                duration: 380 + Math.random() * 220
                                easing.type: Easing.OutCubic
                            }

                            function _randomChar() {
                                return charset[Math.floor(Math.random() * charset.length)]
                            }

                            // direction:
                            //   "bottom" -> 目標字從「下方」滾入,整條帶子向上移動後落定
                            //   "top"    -> 目標字從「上方」滾入,整條帶子向下移動後落定
                            function roll(direction) {
                                var padding = 3 + Math.floor(Math.random() * 3) // 過場用的隨機格數
                                var settled = [
                                    { ch: _randomChar(), isTarget: false },
                                    { ch: cell.ch, isTarget: true },
                                    { ch: _randomChar(), isTarget: false }
                                ]

                                var padCells = []
                                for (var i = 0; i < padding; i++) padCells.push({ ch: _randomChar(), isTarget: false })

                                if (direction === "bottom") {
                                    cell._sequence = padCells.concat(settled)
                                    reel.y = 0
                                    anim.to = -padding * rowHeight
                                } else {
                                    cell._sequence = settled.concat(padCells)
                                    reel.y = -padding * rowHeight
                                    anim.to = 0
                                }
                                anim.restart()
                            }

                            // 第一次建立時的落定畫面
                            Component.onCompleted: roll(Math.random() < 0.5 ? "top" : "bottom")

                            // 只有在字元「真的變了」才會觸發 —— 連續匹配的欄位不會重新轉動的關鍵
                            onChChanged: roll(Math.random() < 0.5 ? "top" : "bottom")
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }
            }
            contentItem {
                focus: true
                Keys.onPressed: event => {
                    root.handleKey(event)
                }
            }

            function callback(str) {
                panelVariants.instances.forEach(p => {
                    const active = p.screenName === screenName && str !== "";
                    p.visible = active;

                    if (!active) return;

                    p.panel.visible = str.includes("panel");
                });
            }
        }
    }
    
    IpcHandler {
        target: `launcher`

        function toggle() {
            if (!Hyprland.focusedMonitor)
            return

            // 從 instances 裡找到對應 focusedMonitor 的那個 PanelWindow
            const targetPanel = panelVariants.instances.find(
                p => p.screenName === Hyprland.focusedMonitor.name
            )

            if (!targetPanel) {
                console.warn("找不到對應螢幕的 panel:", Hyprland.focusedMonitor.name)
                return
            }

            if(!targetPanel.visible) {
                // 初始大小:1 個字元寬 x 3 列高(跟面板實際的 syncSize() 公式保持一致)。
                // 之後輸入文字時只有寬度會變(高度永遠是固定的 3 列),見 panel.syncSize()。
                const p = targetPanel.panel
                const initWidth = 1 * p.charWidth + p.margin * 2
                const initHeight = 3 * p.rowHeight + p.margin * 2

                root.filterText = ""

                Window.Backend.pushWindow({
                        "screenName": Hyprland.focusedMonitor.name,
                        "name": "launcher",
                        "regions": {
                            "panel": [5, initWidth, initHeight, 0],
                        },
                        "callback": targetPanel.callback
                })
            }
            else{
                Window.Backend.popWindow("launcher")
            }
        }
    }
}
