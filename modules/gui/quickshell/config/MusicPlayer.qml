import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import qs

Scope {
    id: root

    // ------------------------------------------------------------------
    // 資料狀態
    // ------------------------------------------------------------------
    // songList 現在是「本地維護」的完整歌曲清單,來源是 mpc listall (整個音樂庫),
    // 不再依賴 mpd 自己的 playlist / playlist id。
    // 啟動時洗牌一次,洗牌後的陣列順序 = 我們自己的播放順序,
    // 每首歌的 id 就是它在這個陣列裡的 index(由 assignIds() 統一指定)。
    property var songList: []          // 本地歌曲清單(含 id / title / artist / albumartist / album / file)
    property string filterText: ""     // 模糊搜尋字串
    property int currentSongId: -1     // 目前「正在播放」的歌曲 id(對應 songList 裡的本地 id)
    property int selectedSongId: -1    // 目前「游標選中」的歌曲 id (j/k 移動、Enter 播放)

    // mpd 實際的 playlist 永遠只會有 0~1 首歌(就是目前正在播的那首)。
    // 每次切歌都是 mpc clear && mpc add <file> && mpc play。
    // switchingTrack 用來避免:我們自己觸發 clear/add/play 時,
    // 中間會有短暫的 "stop" 狀態,若被 idle 監聽誤判成「自然播完」
    // 會導致無限連續換歌的迴圈。
    property bool switchingTrack: false

    readonly property var currentSong: songList.find(s => s.id === currentSongId) || null

    // 目前操作模式:"normal" | "search"
    property string mode: "normal"

    // 固定顯示列數,不捲動;游標固定在正中間 (index = centerIndex)
    readonly property int windowSize: 39
    // 依 windowSize 動態算出,避免改 windowSize 時忘記手動同步這個數字
    readonly property int centerIndex: Math.floor(windowSize / 2)
    property var windowList: []             // 長度固定 windowSize

    property real elapsedTime: 0
    property real durationTime: 0
    property bool isPlaying: false

    // ------------------------------------------------------------------
    // 篩選 / 模糊搜尋
    // ------------------------------------------------------------------

    // 對 title / artist / album 合併後做模糊比對
    function matchesFilter(song) {
        const trimmed = filterText.trim()
        if (trimmed === "")
        return true

        const combined = (song.title + " " + song.artist + " " + song.album).toLowerCase()
        const keywords = trimmed.toLowerCase().split(/\s+/).filter(k => k.length > 0)

        return keywords.every(k => combined.includes(k))
    }

    function getFilteredList() {
        return songList.filter(matchesFilter)
    }

    // ------------------------------------------------------------------
    // 小工具:shell 單引號跳脫,避免檔名含空白 / 特殊字元時指令炸掉
    // ------------------------------------------------------------------
    function shQuote(str) {
        return "'" + String(str).replace(/'/g, "'\\''") + "'"
    }

    readonly property string mpdStatusScript: `
    FIFO="/tmp/mpd_status_$$.fifo"
    mkfifo "$FIFO"
    exec 3<>"$FIFO"
    rm -f "$FIFO"
    # 外層 while true:nc 斷線(例如 mpd 重啟)時自動重連,
    # 避免一次斷線就永遠停止更新播放進度。
    while true; do
    nc localhost 6600 <&3 | {
    read -r _banner
    while true; do
    printf 'status\n' >&3
    while IFS= read -r line; do
    case "$line" in
    elapsed:*)  printf 'E:%s\n' "\${line#elapsed: }" ;;
    duration:*) printf 'D:%s\n' "\${line#duration: }" ;;
    state:*)    printf 'S:%s\n' "\${line#state: }" ;;
    OK*) break ;;
    esac
    done
    sleep 0.5
    done
}
    sleep 1
    done`

    // 這個 process 只負責「進度條」用的 elapsed / duration / isPlaying,
    // 不再拿來判斷「歌曲自然播完」——那個責任交給下面的 mpdIdleScript,
    // 用 idle 事件即時判斷,才不會有 0.5 秒的延遲。
    Process {
        running: true
        command: [ "bash", "-c", root.mpdStatusScript ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (line.startsWith("E:")) {
                    root.elapsedTime = parseFloat(line.slice(2)) || 0
                } else if (line.startsWith("D:")) {
                    root.durationTime = parseFloat(line.slice(2)) || 0
                } else if (line.startsWith("S:")) {
                    root.isPlaying = line.slice(2).trim() === "play"
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 游標(選取)邏輯
    // ------------------------------------------------------------------

    // 確保 selectedSongId 在目前篩選結果中仍然有效,
    // 若無效則優先退回「目前播放中」的歌,否則退回第一首
    function ensureSelection() {
        const filtered = getFilteredList()

        if (filtered.length === 0) {
            selectedSongId = -1
            computeWindow()
            return
        }

        const stillValid = filtered.some(s => s.id === selectedSongId)
        if (!stillValid) {
            const curIdx = filtered.findIndex(s => s.id === currentSongId)
            selectedSongId = curIdx !== -1 ? filtered[curIdx].id : filtered[0].id
        }

        computeWindow()
    }

    function moveSelection(delta) {
        const filtered = getFilteredList()
        if (filtered.length === 0)
        return

        let idx = filtered.findIndex(s => s.id === selectedSongId)

        idx = (idx + delta + filtered.length) % filtered.length
        selectedSongId = filtered[idx].id
    }

    // Enter:播放目前選中的那首歌
    function playSelected() {
        if (selectedSongId === -1)
        return

        const song = songList.find(s => s.id === selectedSongId)
        playSongObject(song)
    }

    // 以 selectedSongId 為中心,往前後各取一半組成「僅包含實際歌曲數」的視窗
    // 不再頭尾相接填滿整個 windowSize;若歌曲數不足 windowSize,
    // 超出範圍的格子維持 null(空白),只有中間 visibleCount 格會顯示歌曲。
    // 當歌曲數 >= windowSize 時,行為與原本相同(整個視窗填滿)。
    function computeWindow() {
        const filtered = getFilteredList()
        const n = filtered.length

        if (n === 0) {
            windowList = new Array(windowSize).fill(null)
            return
        }

        let anchor = filtered.findIndex(s => s.id === selectedSongId)
        if (anchor === -1)
        anchor = 0

        const win = new Array(windowSize).fill(null)

        // 實際要顯示的格數,不超過清單長度,避免資料不足時重複填滿
        const visibleCount = Math.min(n, windowSize)
        // 讓 visibleCount 格對稱地置中在 centerIndex 上
        const half = Math.floor((visibleCount - 1) / 2)
        const start = centerIndex - half

        for (let i = 0; i < visibleCount; i++) {
            const pos = start + i
            const offset = pos - centerIndex
            // 只在這 visibleCount 格範圍內循環,而不是整個 windowSize,
            // 所以歌曲數少時不會被拉伸重複填滿。
            const idx = ((anchor + offset) % n + n) % n
            win[pos] = filtered[idx]
        }

        windowList = win
    }

    onSongListChanged: ensureSelection()
    onFilterTextChanged: ensureSelection()
    onSelectedSongIdChanged: computeWindow()

    // ------------------------------------------------------------------
    // 取得完整歌曲庫(取代原本的 mpc playlist)
    // 啟動時抓一次全部歌曲、洗牌決定播放順序、指定本地 id,
    // 然後直接播放洗牌後的第 0 首。
    // ------------------------------------------------------------------
    Process {
        id: libraryFetcher
        running: true
        command: [ "mpc", "listall", "-f", "%title%\t%artist%\t%albumartist%\t%album%\t%file%" ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.length > 0)
                let list = lines.map(line => {
                        const parts = line.split("\t")
                        return {
                            title: parts[0] || "",
                            artist: parts[1] || "",
                            albumartist: parts[2] || "",
                            album: parts[3] || "",
                            file: parts[4] || ""
                        }
                })

                list = root.shuffleList(list)
                list = root.assignIds(list)

                root.songList = list

                if (list.length > 0) {
                    root.playSongObject(list[0])
                }
            }
        }
    }

    // Fisher-Yates 洗牌,回傳新陣列(不改動原陣列)
    function shuffleList(list) {
        const arr = list.slice()
        for (let i = arr.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1))
            const tmp = arr[i]
            arr[i] = arr[j]
            arr[j] = tmp
        }
        return arr
    }

    // 依陣列目前順序,重新指定 id = index(本地播放順序的依據)
    function assignIds(list) {
        return list.map((s, idx) => Object.assign({}, s, { id: idx }))
    }

    // s 鍵:重新洗牌本地播放順序。
    // 目前正在播放的那首歌不會被中斷,只是重新指定它在新順序中的 id,
    // 游標(selectedSongId)交由 ensureSelection() 依新的 currentSongId 自動歸位。
    function reshuffle() {
        if (root.songList.length === 0)
        return

        const currentFile = root.currentSong ? root.currentSong.file : null

        let list = root.shuffleList(root.songList)
        list = root.assignIds(list)

        if (currentFile) {
            const newCur = list.find(s => s.file === currentFile)
            if (newCur)
            root.currentSongId = newCur.id
            root.selectedSongId = newCur.id
        }

        root.songList = list
    }

    // ------------------------------------------------------------------
    // 一次性 mpc / bash 指令執行器
    // 每次呼叫都動態建立一個新的 Process,跑完自動銷毀,
    // 避免多個按鍵連續觸發時互相搶用同一個 Process
    // ------------------------------------------------------------------
    Component {
        id: mpcCommandComponent
        Process {
            running: true
            stdout: StdioCollector {}
        }
    }

    function runMpc(args) {
        const obj = mpcCommandComponent.createObject(root, {
                command: ["mpc"].concat(args)
        })
        if (!obj)
        return

        obj.stdout.streamFinished.connect(function () {
                obj.destroy()
        })
    }

    // 核心切歌函式:不再操作 mpd 既有的 playlist 位置,
    // 而是直接把 mpd 的 playlist 清空、塞入指定的那一首、播放。
    // switchingTrack 期間忽略 idle 監聽送來的 "stop" 事件,
    // 避免 clear -> add 中間的短暫 stop 狀態被誤判成自然播完。
    function playSongObject(song) {
        if (!song)
        return

        root.switchingTrack = true

        const cmd = "mpc clear >/dev/null && mpc add " + root.shQuote(song.file)
        + " >/dev/null && mpc play >/dev/null"

        const obj = mpcCommandComponent.createObject(root, {
                command: ["bash", "-c", cmd]
        })
        if (!obj) {
            root.switchingTrack = false
            return
        }

        obj.stdout.streamFinished.connect(function () {
                root.currentSongId = song.id
                root.selectedSongId = song.id
                obj.destroy()
                root.switchingTrack = false
        })
    }

    // H / L(shift)以及「自然播完」共用的換歌邏輯。
    // direction: -1 = 上一首(H), +1 = 下一首(L) / 自然播完視為 +1。
    //
    // 情況一:目前播放的歌「在」目前篩選(搜尋)結果中
    //         -> 行為跟沒有 filter 時一樣,播放篩選清單中的上一首/下一首。
    // 情況二:目前播放的歌「不在」目前篩選結果中
    //         -> 不管方向,一律播放目前游標選中的那首歌。
    function advanceTrack(direction) {
        const filtered = root.getFilteredList()
        if (filtered.length === 0)
        return

        const curIdx = filtered.findIndex(s => s.id === root.currentSongId)

        if (curIdx !== -1) {
            const idx = (curIdx + direction + filtered.length) % filtered.length
            root.playSongObject(filtered[idx])
        } else {
            const selected = root.songList.find(s => s.id === root.selectedSongId)
            root.playSongObject(selected)
        }
    }

    // ------------------------------------------------------------------
    // 透過 nc 監聽 mpd (localhost:6600),只在乎「歌曲何時自然播完」。
    // 用 idle player 阻塞等待播放狀態變化,一有事件就查 status 拿目前 state,
    // 若變成 stop 且不是我們自己在切歌(switchingTrack),
    // 代表歌曲自然播完(mpd 自己的 1 首 playlist 播完後沒有下一首可接),
    // 這時交給 advanceTrack(1) 決定接下來播什麼。
    // 用具名管線(FIFO)讓 nc 可以雙向通訊(送指令 + 讀回應)。
    // 外層 while true 做斷線重連,避免 mpd 重啟或網路短暫斷開後
    // 這個腳本整個死掉、自然換歌功能永遠停擺。
    // ------------------------------------------------------------------
    readonly property string mpdIdleScript: `
    FIFO="/tmp/mpd_idle_$$.fifo"
    mkfifo "$FIFO"
    exec 3<>"$FIFO"
    rm -f "$FIFO"
    while true; do
    nc localhost 6600 <&3 | {
    read -r _banner
    while true; do
    printf 'idle player\n' >&3
    while IFS= read -r line; do
    case "$line" in
    OK*) break ;;
    esac
    done

    printf 'status\n' >&3
    while IFS= read -r line; do
    case "$line" in
    state:*) printf 'STATE:%s\n' "\${line#state: }" ;;
    OK*) break ;;
    esac
    done
    done
}
    sleep 1
    done
    `

    Process {
        running: true
        command: [ "bash", "-c", root.mpdIdleScript ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (line.startsWith("STATE:")) {
                    const state = line.slice("STATE:".length).trim()
                    if (state === "stop" && !root.switchingTrack) {
                        root.advanceTrack(1)
                    }
                }
            }
        }
    }

    property var audioData: []

    Process {
        id: cavaProcess
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/my_config"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                audioData = data.trim().split(";").map(Number)
            }
        }
    }

    // ------------------------------------------------------------------
    // Keyboard Dispatcher
    // ------------------------------------------------------------------

    function handleKey(event) {
        if (root.mode === "search") {
            handleSearchKey(event)
        } else {
            handleNormalKey(event)
        }
        event.accepted = true
    }

    // ---- NORMAL MODE ----
    function handleNormalKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0

        switch (event.key) {
            case Qt.Key_H:
            if (shift) {
                // H:上一首歌(依 advanceTrack 的 filter 規則)
                advanceTrack(-1)
            } else {
                // h:歌曲時間向前(倒退) 5 秒
                runMpc(["seek", "-5"])
            }
            break

            case Qt.Key_L:
            if (shift) {
                // L:下一首歌(依 advanceTrack 的 filter 規則)
                advanceTrack(1)
            } else {
                // l:歌曲時間向後(快轉) 5 秒
                runMpc(["seek", "+5"])
            }
            break

            case Qt.Key_J:
            // j:播放清單游標向下一格
            moveSelection(1)
            break

            case Qt.Key_K:
            // k:播放清單游標向上一格
            moveSelection(-1)
            break

            case Qt.Key_Return:
            case Qt.Key_Enter:
            // Enter:播放目前選中的那首歌
            playSelected()
            break

            case Qt.Key_S:
            // s:重新洗牌本地播放順序(不中斷目前播放)
            reshuffle()
            break

            case Qt.Key_C:
            // c:跳回目前正在播放的歌曲(置中)
            if (root.currentSongId !== -1) {
                root.selectedSongId = root.currentSongId
            }
            break

            case Qt.Key_P:
            // p:播放/暫停切換
            runMpc(["toggle"])
            break

            case Qt.Key_Slash:
            // /:進入 SEARCH MODE
            root.mode = "search"
            break

            case Qt.Key_Escape:
            // esc:清空搜尋字串(停留在 NORMAL MODE)
            root.filterText = ""
            root.selectedSongId = root.currentSongId
            break
        }
    }

    // ---- SEARCH MODE ----
    function handleSearchKey(event) {
        switch (event.key) {
            case Qt.Key_Escape:
            // esc:清空搜尋字串並回到 NORMAL MODE
            root.filterText = ""
            root.mode = "normal"
            break

            case Qt.Key_Return:
            case Qt.Key_Enter:
            // enter:固定目前搜尋字串並回到 NORMAL MODE
            root.mode = "normal"
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

            property alias playlist: playlist
            property alias cover: cover
            property alias playback: playback
            property alias cava: cava

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
                if (playlistColumn.opacity > 0.0 && isThisMonitorFocused) {
                    return WlrKeyboardFocus.Exclusive
                }
                return WlrKeyboardFocus.None
            }

            Rectangle {
                id: playlist

                x: 20
                y: 20

                width: 1311
                height: 890

                radius: 20

                color: "transparent"
                visible: true

                clip: true

                // 固定列數,不可捲動;只有內容資料會被替換
                // 最後一列在有搜尋字串 / 搜尋模式時會變成搜尋列,
                // 沒有時則自動恢復成一般的歌曲列
                Column {
                    id: playlistColumn

                    anchors.fill: parent
                    anchors.margins: 12

                    spacing: 0   // 剛好塞進容器高度,不留間距以避免超出

                    Repeater {
                        model: root.windowList
                        delegate: Rectangle {
                            id: delegateItem
                            width: playlistColumn.width
                            height: 22
                            radius: 20

                            readonly property bool isSearchBarSlot: index === (root.windowSize - 1)
                            && (root.mode === "search" || root.filterText !== "")
                            readonly property bool isSelected: !isSearchBarSlot && index === root.centerIndex && modelData !== null
                            readonly property bool isPlaying: !isSearchBarSlot && modelData !== null && modelData.id === root.currentSongId

                            color: isSelected ? Colors.color15 : "transparent"

                            // ---- 動態寬度計算 ----
                            readonly property real rowMargin: 12
                            readonly property real minGap: 10 // 歌名與演出者之間至少保留的間距(約一個空格寬)
                            readonly property real availableRowWidth: Math.max(delegateItem.width - rowMargin * 2 - minGap, 0)
                            readonly property real titleNaturalWidth: titleText.implicitWidth
                            readonly property real artistNaturalWidth: artistText.implicitWidth

                            readonly property var rowWidths: {
                                var avail = availableRowWidth
                                var tW = titleNaturalWidth
                                var aW = artistNaturalWidth

                                // 兩者都塞得下,不截斷
                                if (tW + aW <= avail) {
                                    return { title: tW, artist: aW }
                                }

                                var titleQuota = avail * 0.7
                                var artistQuota = avail * 0.3

                                // 只有歌曲名過長:演出者維持原長,歌曲名用剩餘空間
                                if (aW <= artistQuota) {
                                    return { title: Math.max(avail - aW, 0), artist: aW }
                                }
                                // 只有演出者過長:歌曲名維持原長,演出者用剩餘空間
                                if (tW <= titleQuota) {
                                    return { title: tW, artist: Math.max(avail - tW, 0) }
                                }
                                // 兩者都過長:固定 0.7 : 0.3
                                return { title: titleQuota, artist: artistQuota }
                            }

                            // 一般歌曲列:標題
                            Text {
                                id: titleText
                                visible: !delegateItem.isSearchBarSlot
                                anchors.left: parent.left
                                anchors.leftMargin: delegateItem.rowMargin
                                anchors.verticalCenter: parent.verticalCenter
                                width: delegateItem.rowWidths.title
                                text: modelData ? ((delegateItem.isPlaying ? "󰐊 " : "") + modelData.title) : ""
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 20
                                font.bold: delegateItem.isPlaying
                                color: delegateItem.isSelected ? Colors.color0 : Colors.color15
                                elide: Text.ElideRight
                            }

                            // 一般歌曲列:演出者
                            Text {
                                id: artistText
                                visible: !delegateItem.isSearchBarSlot
                                anchors.right: parent.right
                                anchors.rightMargin: delegateItem.rowMargin
                                anchors.verticalCenter: parent.verticalCenter
                                width: delegateItem.rowWidths.artist
                                text: modelData ? modelData.artist : ""
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 20
                                color: delegateItem.isSelected ? Colors.color0 : Colors.color15
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            // 搜尋列內容
                            Text {
                                visible: delegateItem.isSearchBarSlot
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.mode === "search" ? "/ " : "Search: ") + root.filterText
                                + (root.mode === "search" ? "▏" : "")
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 20
                                color: Colors.color15
                            }
                        }
                    }
                }
            }
            ClippingRectangle {
                id: cover

                x: 1342
                y: 22

                width: 556
                height: 556

                radius: 20

                color: "transparent"
                visible: true

                Image {
                    anchors.fill: parent

                    source: currentSong ? `/home/niiixkz/Music/${currentSong.file.split("/")[0]}/cover.avif` : ""

                    fillMode: Image.PreserveAspectFit
                    horizontalAlignment: Image.AlignHCenter
                    verticalAlignment: Image.AlignVCenter

                    smooth: true
                    antialiasing: true
                }
            }
            Rectangle {
                id: cava

                x: 1340
                y: 600

                width: 560
                height: 321

                radius: 20

                color: "transparent"
                visible: true

                // Render the visualizer window via LayerShell
                Row {
                    anchors.fill: parent
                    anchors.margins: 20
                    anchors.centerIn: parent

                    Repeater {
                        model: root.audioData

                        Rectangle {
                            width: 4
                            height: Math.max(0.001, root.audioData[index])
                            color: Colors.color15

                            anchors.bottom: parent.bottom

                            Behavior on height {
                                NumberAnimation { duration: 50 }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: playback
                x: 20
                y: 930
                width: 1880
                height: 141
                radius: 20
                color: "transparent"
                visible: true

                readonly property real progress: root.durationTime > 0
                ? root.elapsedTime / root.durationTime
                : 0

                function formatTime(sec) {
                    const s = Math.max(0, Math.floor(sec))
                    const m = Math.floor(s / 60)
                    const r = s % 60
                    return m + ":" + (r < 10 ? "0" : "") + r
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20

                    spacing: 4

                    // 第一行: Title (跑馬燈)
                    Item {
                        id: titleMarquee
                        width: parent.width
                        height: titleFontMetrics.height + 4
                        clip: true

                        property string fullText: root.currentSong ? root.currentSong.title : ""
                        readonly property string separator: "   ‧   "  // 循環時中間的分隔符
                        property bool needsScroll: titleMeasure.implicitWidth > width
                        property int charIndex: 0

                        onFullTextChanged: charIndex = 0   // 換歌時重置捲動位置

                        FontMetrics {
                            id: titleFontMetrics
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 22
                            font.bold: true
                        }

                        // 隱藏文字,僅用來量測原始寬度以判斷要不要跑馬燈
                        Text {
                            id: titleMeasure
                            visible: false
                            text: titleMarquee.fullText
                            font: titleFontMetrics.font
                        }

                        Text {
                            id: titleDisplay
                            text: titleMarquee.needsScroll
                            ? (titleMarquee.fullText + titleMarquee.separator + titleMarquee.fullText)
                            : titleMarquee.fullText
                            font: titleFontMetrics.font
                            color: Colors.color15
                            x: titleMarquee.needsScroll
                            ? -titleMarquee.charIndex * titleFontMetrics.averageCharacterWidth
                            : (titleMarquee.width - titleMeasure.implicitWidth) / 2
                        }

                        Timer {
                            interval: 1000
                            running: titleMarquee.needsScroll
                            repeat: true
                            onTriggered: {
                                titleMarquee.charIndex++
                                if (titleMarquee.charIndex >= titleMarquee.fullText.length + titleMarquee.separator.length)
                                titleMarquee.charIndex = 0
                            }
                        }
                    }

                    // 第二行: artist / albumartist / album (跑馬燈)
                    Item {
                        id: infoMarquee
                        width: parent.width
                        height: infoFontMetrics.height + 4
                        clip: true

                        property string fullText: root.currentSong
                        ? (root.currentSong.artist + "  |  "  + (root.currentSong.albumartist == "" ? "" : `${root.currentSong.albumartist}  |  `) + root.currentSong.album)
                        : ""
                        readonly property string separator: "   ‧   "
                        property bool needsScroll: infoMeasure.implicitWidth > width
                        property int charIndex: 0

                        onFullTextChanged: charIndex = 0

                        FontMetrics {
                            id: infoFontMetrics
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 16
                        }

                        Text {
                            id: infoMeasure
                            visible: false
                            text: infoMarquee.fullText
                            font: infoFontMetrics.font
                        }

                        Text {
                            id: infoDisplay
                            text: infoMarquee.needsScroll
                            ? (infoMarquee.fullText + infoMarquee.separator + infoMarquee.fullText)
                            : infoMarquee.fullText
                            font: infoFontMetrics.font
                            color: Colors.color15
                            x: infoMarquee.needsScroll
                            ? -infoMarquee.charIndex * infoFontMetrics.averageCharacterWidth
                            : (infoMarquee.width - infoMeasure.implicitWidth) / 2
                        }

                        Timer {
                            interval: 1000
                            running: infoMarquee.needsScroll
                            repeat: true
                            onTriggered: {
                                infoMarquee.charIndex++
                                if (infoMarquee.charIndex >= infoMarquee.fullText.length + infoMarquee.separator.length)
                                infoMarquee.charIndex = 0
                            }
                        }
                    }

                    // 第三行: progress bar
                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Colors.color1
                        clip: true
                        Rectangle {
                            height: parent.height
                            radius: 3
                            width: parent.width * Math.min(1, Math.max(0, playback.progress))
                            color: Colors.color15
                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    // 第四行: 目前時間 / 歌曲時長
                    Item {
                        width: parent.width
                        height: 24
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: playback.formatTime(root.elapsedTime)
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 20
                            color: Colors.color15
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: playback.formatTime(root.durationTime)
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 20
                            color: Colors.color15
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

            function callback(str) {
                console.log(screenName, str)

                panelVariants.instances.forEach(p => {
                        if(p.screenName !== screenName){
                            p.visible = false
                        } else {
                            if(str === ""){
                                p.visible = false
                            } else {
                                p.visible = true
                                p.playlist.visible = str.includes("playlist")
                                p.cover.visible = str.includes("cover")
                                p.cava.visible = str.includes("cava")
                                p.playback.visible = str.includes("playback")

                            }
                        }
                });
            }
        }
    }

    IpcHandler {
        target: `musicPlayer`

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
                WindowBackend.pushWindow({
                        "screenName": Hyprland.focusedMonitor.name,
                        "name": "MusicPlayer",
                        "regions": {
                            "playlist": [0, 1311, 890, 0],
                            "cover": [2, 560, 560, 0],
                            "playback": [5, 1880, 141, 0],
                            "cava": [3, 560, 321, 209.5]
                        },
                        "callback": targetPanel.callback
                })
            }
            else{
                WindowBackend.popWindow("MusicPlayer")
            }
        }
    }
}
