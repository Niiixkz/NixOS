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

    // 欄位的 model:用 ListModel 一格一格 append / remove,而不是直接把整數丟給 Repeater。
    // 原因:Repeater 的 model 是整數時,數字一變(例如 1 -> 2)就會「整批銷毀再重建」所有欄位,
    // 舊欄位被重建後狀態全部歸零、又從空白滾一次 —— 這就是「已經打好的字也跟著滾」的元兇。
    // 用 ListModel 增減項目,舊欄位的 delegate 會原封不動保留(連上下的隨機鄰居字都不變)。
    ListModel { id: columnModel }

    // 每一欄「已落定」的上/中/下三格,存在 root 而不是 delegate 裡。
    // 就算 delegate 因為任何原因被重建(視窗重新顯示、model 重設...),
    // 新的 delegate 也會從這裡把舊畫面原樣接回來,字沒變就不會滾。
    property var columnState: []

    function syncColumns() {
        while (columnModel.count < columnCount) columnModel.append({ slot: columnModel.count })
        while (columnModel.count > columnCount) columnModel.remove(columnModel.count - 1)
        if (columnState.length > columnCount) columnState.length = columnCount
    }
    onColumnCountChanged: syncColumns()
    Component.onCompleted: syncColumns()

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

            // 不接受空白鍵輸入
            case Qt.Key_Space:
            break

            case Qt.Key_Backspace:
            root.filterText = root.filterText.slice(0, -1)
            break

            default:
            // 每按一個可見字元就即時 filter 一次
            if (event.text && event.text.length > 0 && event.text.charCodeAt(0) > 0x20) {
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

            mask: Region {}

            Rectangle {
                id: panel
                radius: 20
                color: "transparent"
                visible: true

                // ---- 版面參數:改這裡調整字型大小/間距 ----
                readonly property int rowHeight: 30
                readonly property int charWidth: 20
                readonly property int margin: 20 // Row 四周的留白
                property font slotFont: Qt.font({ family: "monospace", pixelSize: 20 })

                // 這裡只「提出需求」:內容需要多大。
                // 實際的 x / y / width / height 不在這裡綁定,
                // 而是 Backend 算完 regionToCoordinate 後透過 callback 賦值(見 panelWindow.callback)。
                readonly property int wantedWidth: root.columnCount * charWidth + margin * 2
                readonly property int wantedHeight: 3 * rowHeight + margin * 2

                // 需求大小變了(打字使欄數改變)就通知 Backend 重算
                onWantedWidthChanged: Window.Backend.updateWindow({
                    name: "launcher",
                    regions: { panel: [5, wantedWidth, wantedHeight, 0] }
                })

                // 一整排「整體滾輪」:每一欄自己貫穿上/中/下三列,
                // 目標字元會從上面或下面滾過,最後落定在中間那格。
                // 四周留 panel.margin(20px)的間距 —— 這是靠 wantedWidth/wantedHeight 把
                // panel 尺寸算成「Row 本身大小 + margin*2」,再用 centerIn 置中做到的。
                Row {
                    id: reelRow
                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                        model: columnModel

                        // ---- 以下是原本 SlotColumn.qml 的內容,直接內嵌成 delegate ----
                        // 一整欄「貫穿上/中/下三列」的拉霸滾軸。三列其實是同一條帶子上
                        // 相鄰的三格,目標字元從上面或下面滾入時會先經過上/下那格,
                        // 再捲到中間落定,視覺上是一個整體。
                        delegate: Item {
                            id: cell
                            required property int index

                            // 這一欄現在應該落定的字元;字比欄數短時補空白
                            readonly property string ch: (index >= 0 && index < root.displayText.length)
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
                            // 空白狀態:上/下是隨機字母、中間是空白(字母 空格 字母),
                            // 所以第一次開啟、輸入為空時就會有「x _ y」的樣子;
                            // 新增的欄位也是從這個畫面開始滾出目標字。
                            readonly property var _blank: [
                                { ch: _randomChar(), isTarget: false },
                                { ch: " ", isTarget: false },
                                { ch: _randomChar(), isTarget: false }
                            ]
                            // 上一次落定的三格(上/中/下)。下一次滾動就從這三格「當前畫面」出發,
                            // 所以舊字母會真的被捲走,而不是瞬間消失。新增的欄位從空白開始滾。
                            property var _settled: _blank
                            property var _sequence: _blank

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
                                easing.type: Easing.OutCubic
                            }

                            function _randomChar() {
                                return charset[Math.floor(Math.random() * charset.length)]
                            }

                            // direction:
                            //   "bottom" -> 新字從「下方」滾入,整條帶子向上移動後落定
                            //   "top"    -> 新字從「上方」滾入,整條帶子向下移動後落定
                            // 帶子結構:[ 舊的三格 ][ 隨機過場格 x padding ][ 新的三格 ](或反過來)
                            // 起點永遠是「目前畫面上的舊字母」,終點是新字母。
                            function roll(direction) {
                                // 每一欄各自隨機決定要滾過幾個字母
                                var padding = 2 + Math.floor(Math.random() * 10) // 2 ~ 11 格

                                // 起點:「此刻畫面上實際看到的內容」。
                                // 如果上一段動畫還在跑,reel.y 是動畫中途的位置,不能直接拿落定的字當起點,
                                // 否則畫面會瞬間跳到那個字(連續打字/刪除時看起來就是「跳」)。
                                // 所以依目前 y 算出畫面最上面那格是帶子的第 k 格、還差 frac 格的小數偏移,
                                // 取 k..k+3 共 4 格(多一格是為了涵蓋偏移),並保留這個偏移,讓動畫無縫接續。
                                var oldSeq = cell._sequence
                                var pos = Math.max(0, -reel.y / rowHeight)
                                var k = Math.min(oldSeq.length - 1, Math.floor(pos + 0.0001))
                                var frac = Math.max(0, pos - k)
                                var from = []
                                for (var j = 0; j < 4; j++) {
                                    var src = oldSeq[k + j]
                                    from.push({ ch: src ? src.ch : _randomChar(), isTarget: false })
                                }

                                var settled = [
                                    { ch: _randomChar(), isTarget: false },
                                    { ch: cell.ch, isTarget: true },
                                    { ch: _randomChar(), isTarget: false }
                                ]

                                var padCells = []
                                for (var i = 0; i < padding; i++) padCells.push({ ch: _randomChar(), isTarget: false })

                                var startY, endY
                                if (direction === "bottom") {
                                    // [舊 4 格][過場][新 3 格]:往上捲,終點讓新 3 格剛好在視窗內
                                    cell._sequence = from.concat(padCells, settled)
                                    startY = -frac * rowHeight
                                    endY = -(4 + padding) * rowHeight
                                } else {
                                    // [新 3 格][過場][舊 4 格]:往下捲,起點讓舊畫面(含偏移)在視窗內
                                    cell._sequence = settled.concat(padCells, from)
                                    startY = -((3 + padding) + frac) * rowHeight
                                    endY = 0
                                }
                                cell._settled = settled
                                root.columnState[cell.index] = settled

                                anim.stop()
                                reel.y = startY
                                anim.from = startY
                                anim.to = endY
                                // 滾得越遠花越久,讓每欄速度感覺接近,再加一點隨機
                                anim.duration = 300 + padding * 30 + Math.random() * 100
                                anim.restart()
                            }

                            // 統一的判斷點:只有「目標字」跟「上一次落定的字」不同才滾動。
                            // 用 Qt.callLater 延後到這一輪事件處理完再比對,避免 displayText 在連鎖更新
                            // 的中途出現暫時性的值(例如短暫閃成別的字再變回來),害沒變的欄位誤滾。
                            function _sync() {
                                if (cell.index < 0) return // 這一欄正在被移除
                                if (cell.ch === cell._settled[1].ch) return
                                roll(Math.random() < 0.5 ? "top" : "bottom")
                            }

                            // 新增的欄位:從空白滾到目標字;之後只要這一欄的字變了才會再滾。
                            // 例如 obs -> osu!:o 不動,b->s、s->u 滾動,新增的 "!" 也滾動。
                            Component.onCompleted: {
                                var st = root.columnState[cell.index]
                                if (st) {
                                    // 這一欄之前已經落定過:直接顯示原本的畫面,不重滾
                                    cell._settled = st
                                    cell._sequence = st
                                    reel.y = 0
                                } else {
                                    // 第一次出現的欄位:把初始畫面記下來(空白欄就是「字母 空格 字母」)
                                    root.columnState[cell.index] = cell._settled
                                }
                                Qt.callLater(cell._sync)
                            }
                            onChChanged: Qt.callLater(cell._sync)
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
                // 先清空輸入,columnCount 會變回 1,
                // 這時 wantedWidth / wantedHeight 就是初始大小(1 個字元寬 x 3 列高)。
                // 之後輸入文字時只有寬度會變(高度永遠是固定的 3 列),由 panel.onWantedWidthChanged 通知 Backend。
                const p = targetPanel.panel
                root.filterText = ""

                Window.Backend.pushWindow({
                        "screenName": Hyprland.focusedMonitor.name,
                        "name": "launcher",
                        "regions": {
                            "panel": [5, p.wantedWidth, p.wantedHeight, 0],
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
