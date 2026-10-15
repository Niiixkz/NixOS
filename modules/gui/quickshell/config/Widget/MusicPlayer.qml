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

    // ==================================================================
    // 常數設定
    // ==================================================================
    readonly property string mpdSocketPath: "/run/mpd/socket"
    readonly property string musicRoot: "/home/niiixkz/Music"
    readonly property string confirmWord: "Yes"     // 刪除確認字串,大小寫必須完全一致
    readonly property int defaultVolume: 44         // 播放 / 恢復播放時套用的音量

    // 固定顯示列數,不捲動;游標固定在正中間 (index = centerIndex)
    readonly property int windowSize: 39
    readonly property int centerIndex: Math.floor(windowSize / 2)

    // listallinfo 回傳的 tag 名稱 -> 本地歌曲欄位名稱
    readonly property var tagFields: ({
        "Title": "title",
        "Artist": "artist",
        "AlbumArtist": "albumartist",
        "Album": "album"
    })

    // 純修飾鍵:在刪除確認模式下不算輸入
    readonly property var modifierKeys: [
        Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr,
        Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_CapsLock
    ]

    // ==================================================================
    // 資料狀態
    // ==================================================================
    // songList 是本地維護的完整歌曲清單(來源為 mpd 的 listallinfo),
    // 啟動時洗牌一次,陣列順序即本地播放順序,
    // 每首歌的 id 就是它在陣列中的 index(由 assignIds() 統一指定)。
    // 欄位: id / title / artist / albumartist / album / file / searchText
    property var songList: []
    property string filterText: ""      // 模糊搜尋字串
    property int currentSongId: -1      // 正在播放的歌曲 id
    property int selectedSongId: -1     // 游標選中的歌曲 id (j/k 移動、Enter 播放)
    readonly property var currentSong: songById(currentSongId) || null

    // 操作模式: "normal" | "search" | "confirm"
    property string mode: "normal"

    property var windowList: []         // 畫面上顯示的歌曲,長度固定 windowSize,空位為 null

    // 播放進度(由 statusSocket 輪詢更新)
    property real elapsedTime: 0
    property real durationTime: 0
    property bool isPlaying: false

    // 視覺化頻譜資料(由 nixVisualizerProcess 更新)
    property var audioData: []

    // ==================================================================
    // 流程旗標
    // ==================================================================
    // mpd 的 playlist 永遠只有 0~1 首(目前播放的那首),每次切歌都是 clear + add + play。
    // 切歌期間會短暫出現 stop 狀態,switchingTrack 用來避免 idle 監聽把它誤判成
    // 「自然播完」而造成連續換歌。
    property bool switchingTrack: false
    property bool updatingDb: false         // 正在更新 mpd 資料庫(期間擋掉重複的 u 鍵)
    property bool deleting: false           // 正在刪除檔案
    property bool resumeAfterDelete: false  // 刪除了正在播放的歌,且當時在播放 -> 刪完後自動播放新選中的歌

    // ------------------------------------------------------------------
    // 搜尋列右側「通用狀態區」(資料庫更新提示與刪除確認共用)
    //   statusLabel  : 固定顯示的前綴文字(空字串 = 不顯示)
    //   statusTarget : 需要逐字輸入的目標字串(可為空)
    //   statusTyped  : 目標字串已正確輸入的字元數(已輸入的字母會變亮)
    // ------------------------------------------------------------------
    property int statusTyped: 0
    readonly property string statusTarget: mode === "confirm" ? confirmWord : ""
    readonly property string statusLabel: {
        if (mode === "confirm")
            return "Confirm deletion : "
        if (deleting)
            return "Deleting…"
        if (updatingDb)
            return "Song Database is updating…"
        return ""
    }

    // ==================================================================
    // 小工具
    // ==================================================================

    // 將 index 包回 [0, length) 範圍(正確處理負數)
    function wrapIndex(index, length) {
        return ((index % length) + length) % length
    }

    // 以 id 查詢歌曲,找不到回傳 undefined
    function songById(id) {
        return songList.find(s => s.id === id)
    }

    // mpd protocol 字串跳脫(雙引號包起來,反斜線 / 引號需要 escape)
    function mpdQuote(str) {
        return '"' + String(str).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
    }

    // mpd 回應結束行(OK 或 ACK)
    function isResponseEnd(line) {
        return line.startsWith("OK") || line.startsWith("ACK")
    }

    function isOk(status) {
        return status.startsWith("OK")
    }

    // 解析 "key: value" 形式的回應行,不是此格式則回傳 null
    function parseField(line) {
        const sep = line.indexOf(":")
        if (sep === -1)
            return null
        return { key: line.slice(0, sep), value: line.slice(sep + 1).trim() }
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

    // 依陣列目前順序重新指定 id = index
    function assignIds(list) {
        return list.map((song, index) => Object.assign({}, song, { id: index }))
    }

    // ------------------------------------------------------------------
    // 篩選 / 模糊搜尋
    // ------------------------------------------------------------------

    // 以空白切開關鍵字,每個關鍵字都必須出現在 title / artist / album 合併文字中
    function getFilteredList() {
        const keywords = filterText.toLowerCase().split(/\s+/).filter(k => k.length > 0)
        if (keywords.length === 0)
            return songList

        return songList.filter(song => keywords.every(k => song.searchText.includes(k)))
    }

    // ==================================================================
    // MPD socket
    // ==================================================================

    // 共用的 mpd socket:斷線自動重連、記錄是否已收到第一行 banner、送出一行文字
    component MpdSocket: Socket {
        property bool bannerConsumed: false

        connected: true
        onConnectedChanged: {
            if (!connected)
                connected = true
        }

        function sendLine(text) {
            write(text + "\n")
            flush()
        }
    }

    // 指令佇列 socket:所有一次性指令都透過這條連線依序送出。
    // mpd protocol 一次只能有一個指令在途,所以自行維護 queue,
    // 上一個指令收到 OK/ACK 後才會送出下一個。
    MpdSocket {
        id: commandSocket
        path: root.mpdSocketPath

        property var queue: []              // 等待送出的 { command, callback }
        property var inFlight: null         // 已送出、等待回應的指令
        property var responseLines: []      // 目前指令已收到的回應行

        function enqueue(command, callback) {
            queue.push({ command: command, callback: callback })
            processQueue()
        }

        function processQueue() {
            if (!bannerConsumed || inFlight !== null || queue.length === 0)
                return

            inFlight = queue.shift()
            sendLine(inFlight.command)
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                // 第一行是 mpd 的 banner,例如 "OK MPD 0.23.x"
                if (!commandSocket.bannerConsumed) {
                    commandSocket.bannerConsumed = true
                    root.fetchLibrary()
                    commandSocket.processQueue()
                    return
                }

                if (!root.isResponseEnd(line)) {
                    commandSocket.responseLines.push(line)
                    return
                }

                const finished = commandSocket.inFlight
                const lines = commandSocket.responseLines
                commandSocket.inFlight = null
                commandSocket.responseLines = []

                if (finished && finished.callback)
                    finished.callback(lines, line)
                commandSocket.processQueue()
            }
        }
    }

    // 送出單一指令。callback(lines, status) 可省略
    function sendMpdCommand(command, callback) {
        commandSocket.enqueue(command, callback)
    }

    // 以 command list 一次送出多個指令(整串只會收到一個 OK/ACK)
    function sendMpdCommandList(commands, callback) {
        sendMpdCommand("command_list_begin\n" + commands.join("\n") + "\ncommand_list_end", callback)
    }

    // 狀態輪詢 socket:每 0.5 秒送一次 "status",更新進度條所需的
    // elapsed / duration / state。不負責判斷歌曲是否播完(交給 idleSocket)。
    MpdSocket {
        id: statusSocket
        path: root.mpdSocketPath

        property bool busy: false           // 已送出 status、尚未收到回應

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!statusSocket.bannerConsumed) {
                    statusSocket.bannerConsumed = true
                    return
                }

                if (root.isResponseEnd(line)) {
                    statusSocket.busy = false
                    return
                }

                const field = root.parseField(line)
                if (!field)
                    return

                switch (field.key) {
                case "elapsed":
                    root.elapsedTime = parseFloat(field.value) || 0
                    break
                case "duration":
                    root.durationTime = parseFloat(field.value) || 0
                    break
                case "state":
                    root.isPlaying = field.value === "play"
                    break
                }
            }
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (statusSocket.connected && statusSocket.bannerConsumed && !statusSocket.busy) {
                statusSocket.busy = true
                statusSocket.sendLine("status")
            }
        }
    }

    // idle 監聽 socket:只在乎「歌曲何時自然播完」。
    // 送 "idle player" 阻塞等待播放狀態變化,有回應就查 "status",
    // 若 state 變成 stop 且不是自己在切歌(switchingTrack),
    // 代表自然播完,交給 advanceTrack(1) 決定接下來播什麼。
    MpdSocket {
        id: idleSocket
        path: root.mpdSocketPath

        property string awaiting: "idle"    // 正在等待哪個指令的回應: "idle" | "status"

        function sendIdle() {
            awaiting = "idle"
            sendLine("idle player")
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!idleSocket.bannerConsumed) {
                    idleSocket.bannerConsumed = true
                    idleSocket.sendIdle()
                    return
                }

                if (idleSocket.awaiting === "idle") {
                    // idle 因 player 有變化而返回 -> 查詢目前狀態
                    // (其餘如 "changed: player" 直接忽略)
                    if (root.isResponseEnd(line)) {
                        idleSocket.awaiting = "status"
                        idleSocket.sendLine("status")
                    }
                    return
                }

                if (root.isResponseEnd(line)) {
                    idleSocket.sendIdle()
                    return
                }

                const field = root.parseField(line)
                if (field && field.key === "state" && field.value === "stop" && !root.switchingTrack)
                    root.advanceTrack(1)
            }
        }
    }

    // ==================================================================
    // 歌曲庫載入
    // ==================================================================

    // 解析 listallinfo 的回應行,回傳歌曲陣列(尚未洗牌、未指定 id)
    function parseLibrary(lines) {
        const songs = []
        let song = null

        for (const line of lines) {
            const sep = line.indexOf(": ")
            if (sep === -1)
                continue

            const key = line.slice(0, sep)
            const value = line.slice(sep + 2)

            if (key === "file") {
                song = { title: "", artist: "", albumartist: "", album: "", file: value }
                songs.push(song)
            } else if (song && tagFields[key]) {
                song[tagFields[key]] = value
            }
        }

        // 預先組好搜尋用文字,避免每次篩選都重新串接
        songs.forEach(s => {
            s.searchText = (s.title + " " + s.artist + " " + s.album).toLowerCase()
        })
        return songs
    }

    // 查詢 mpd 目前實際播放的 file / elapsed / duration。
    // 若沒有在播放,callback 的 file 為 null。
    function fetchPlaybackState(callback) {
        sendMpdCommandList(["currentsong", "status"], (lines, status) => {
            if (!isOk(status)) {
                callback(null, 0, 0)
                return
            }

            let file = null
            let elapsed = 0
            let duration = 0

            for (const line of lines) {
                const field = parseField(line)
                if (!field)
                    continue

                if (field.key === "file" && file === null)
                    file = field.value
                else if (field.key === "elapsed")
                    elapsed = parseFloat(field.value) || 0
                else if (field.key === "duration")
                    duration = parseFloat(field.value) || 0
            }

            callback(file, elapsed, duration)
        })
    }

    // 取得完整歌曲庫:洗牌並指定本地 id,
    // 若 mpd 正在播放其中一首就沿用其進度,否則停在第 0 首。
    function fetchLibrary() {
        sendMpdCommand("listallinfo", (lines, status) => {
            if (!isOk(status)) {
                console.warn("listallinfo failed:", status)
                return
            }

            const songs = assignIds(shuffleList(parseLibrary(lines)))
            songList = songs

            if (songs.length === 0)
                return

            fetchPlaybackState((file, elapsed, duration) => {
                const playing = file ? songs.find(s => s.file === file) : null

                if (playing) {
                    currentSongId = playing.id
                    selectedSongId = playing.id
                    elapsedTime = elapsed
                    durationTime = duration
                } else {
                    currentSongId = 0
                    selectedSongId = 0
                }
            })
        })
    }

    // 以新的歌曲順序取代 songList(洗牌 / 刪除後共用)。
    // id 會依新順序重新指定,所以以 file 為準,把正在播放與游標選中的歌對回新 id;
    // 對不到(file 為 null 或已不在新清單中)則為 -1,之後由 ensureSelection() 補上游標。
    // 先更新兩個 id 再換清單,避免中間出現指向錯誤歌曲的狀態。
    function applySongList(list, playingFile, selectedFile) {
        const songs = assignIds(list)
        const idOfFile = file => {
            const song = file ? songs.find(s => s.file === file) : null
            return song ? song.id : -1
        }

        currentSongId = idOfFile(playingFile)
        selectedSongId = idOfFile(selectedFile)
        songList = songs
    }

    // s 鍵:重新洗牌本地播放順序,不中斷目前播放,游標回到正在播放的歌
    function reshuffle() {
        if (songList.length === 0)
            return

        const playingFile = currentSong ? currentSong.file : null
        applySongList(shuffleList(songList), playingFile, playingFile)
    }

    // ==================================================================
    // 播放控制
    // ==================================================================

    // 清空 mpd playlist、加入指定歌曲並播放
    function playSong(song) {
        if (!song)
            return

        switchingTrack = true
        sendMpdCommandList(
            ["setvol " + defaultVolume, "clear", "add " + mpdQuote(song.file), "play"],
            () => {
                currentSongId = song.id
                selectedSongId = song.id
                switchingTrack = false
            }
        )
    }

    // Enter:播放游標選中的歌曲
    function playSelected() {
        playSong(songById(selectedSongId))
    }

    // H / L 以及「自然播完」共用的換歌邏輯。
    // direction: -1 = 上一首, +1 = 下一首
    //   - 正在播放的歌在篩選結果中 -> 播放篩選結果中的上一首 / 下一首
    //   - 不在篩選結果中           -> 不分方向,播放游標選中的那首
    function advanceTrack(direction) {
        const filtered = getFilteredList()
        if (filtered.length === 0)
            return

        const currentIndex = filtered.findIndex(s => s.id === currentSongId)
        if (currentIndex === -1) {
            playSelected()
            return
        }

        playSong(filtered[wrapIndex(currentIndex + direction, filtered.length)])
    }

    // ==================================================================
    // 資料庫更新 (u)
    // ==================================================================

    function startLibraryUpdate() {
        if (updatingDb)
            return

        updatingDb = true
        sendMpdCommand("update", (lines, status) => {
            if (!isOk(status)) {
                console.warn("update failed:", status)
                updatingDb = false
                return
            }
            pollUpdateStatus()
        })
    }

    // 反覆查詢 status,直到 updating_db 消失,再重新載入歌曲庫
    function pollUpdateStatus() {
        sendMpdCommand("status", (lines, status) => {
            if (!isOk(status)) {
                console.warn("status (update poll) failed:", status)
                updatingDb = false
                return
            }

            if (lines.some(l => l.startsWith("updating_db:"))) {
                updatePollTimer.start()
            } else {
                updatingDb = false
                fetchLibrary()
            }
        })
    }

    Timer {
        id: updatePollTimer
        interval: 300
        repeat: false
        onTriggered: root.pollUpdateStatus()
    }

    // ==================================================================
    // 刪除歌曲 (d)
    // ==================================================================

    // 檔案與專輯資料夾都有 +i,所以流程是:
    //   1. 先解除涉及的專輯資料夾的 +i(否則資料夾內不能刪檔)
    //   2. 解除歌曲 +i 並刪除,成功的才回報 (stdout 一行一個 file)
    //   3. 檢查每個動到的資料夾:除了 cover.avif 外沒有其他檔案 -> 刪封面、刪資料夾;
    //      否則把資料夾 +i 補回去
    // chattr 需要 root,這裡用 `sudo -n chattr`(需 sudoers 設 NOPASSWD)。
    readonly property string deleteScript: [
        'root="$1"; shift',
        'declare -A dirs',
        'for f in "$@"; do dirs["${f%%/*}"]=1; done',
        'for d in "${!dirs[@]}"; do sudo -n chattr -i "$root/$d"; done',
        'for f in "$@"; do',
        '  sudo -n chattr -i "$root/$f"',
        '  rm -f -- "$root/$f"',
        '  if [ ! -e "$root/$f" ]; then echo "$f"; fi',
        'done',
        'for d in "${!dirs[@]}"; do',
        '  p="$root/$d"',
        '  if [ -z "$(find "$p" -mindepth 1 -maxdepth 1 ! -name cover.avif -print -quit)" ]; then',
        '    sudo -n chattr -i "$p/cover.avif" 2>/dev/null',
        '    rm -f -- "$p/cover.avif"',
        '    rmdir -- "$p" 2>/dev/null || sudo -n chattr +i "$p"',
        '  else',
        '    sudo -n chattr +i "$p"',
        '  fi',
        'done'
    ].join("\n")

    Process {
        id: deleteProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root.finishDelete(this.text.split("\n").filter(l => l !== ""))
            }
        }
    }

    // 只接受「專輯資料夾/檔名」兩層結構,避免 ".." 之類的路徑跑出 musicRoot
    function isSafeSongPath(file) {
        const parts = String(file).split("/")
        return parts.length === 2
            && parts[0] !== "" && parts[0] !== "." && parts[0] !== ".."
            && parts[1] !== ""
    }

    // d:進入刪除確認。搜尋字串為空時不動作(避免誤刪整個音樂庫)
    function requestDelete() {
        if (filterText.trim() === "" || updatingDb || deleting)
            return
        if (!getFilteredList().some(s => isSafeSongPath(s.file)))
            return

        statusTyped = 0
        mode = "confirm"
    }

    function cancelDelete() {
        statusTyped = 0
        mode = "normal"
    }

    // 確認通過後,刪除「目前搜尋結果」中的所有歌曲
    function executeDelete() {
        const targets = getFilteredList().filter(s => isSafeSongPath(s.file))

        statusTyped = 0
        mode = "normal"

        if (targets.length === 0)
            return

        deleting = true

        // 正在播放的歌也要被刪:先清空 mpd,並暫時擋住 idle 的「自然播完」判斷,
        // 避免它自動跳去播下一首同樣即將被刪除的歌
        resumeAfterDelete = false
        if (targets.some(s => s.id === currentSongId)) {
            resumeAfterDelete = isPlaying
            switchingTrack = true
            sendMpdCommand("clear")
        }

        deleteProcess.command = ["bash", "-c", deleteScript, "_", musicRoot].concat(targets.map(s => s.file))
        deleteProcess.running = true
    }

    // 刪除後游標該停在哪首:從正在播放(不可用則游標)的歌開始往後循環,
    // 找到第一首沒被刪除的歌;全部都被刪光則回傳 null
    function findNextSurvivor(deleted) {
        let start = songList.findIndex(s => s.id === currentSongId)
        if (start === -1)
            start = songList.findIndex(s => s.id === selectedSongId)
        if (start === -1)
            return null

        for (let i = 0; i < songList.length; i++) {
            const song = songList[(start + i) % songList.length]
            if (!deleted.has(song.file))
                return song
        }
        return null
    }

    // 刪除完成後,依腳本回報「確實刪掉了」的檔案同步本地清單
    function finishDelete(deletedFiles) {
        const deleted = new Set(deletedFiles)
        const survivors = songList.filter(s => !deleted.has(s.file))
        const playingFile = currentSong ? currentSong.file : null    // 若已被刪,applySongList 會對應成 -1
        const next = findNextSurvivor(deleted)

        // 先清掉搜尋,讓游標在完整清單上歸位
        filterText = ""
        applySongList(survivors, playingFile, next ? next.file : null)

        switchingTrack = false
        deleting = false

        // 通知 mpd 檔案已消失(不呼叫 fetchLibrary,所以不會重新洗牌)
        sendMpdCommand("update")

        // 正在播的歌被刪 -> 開始播放新游標所在的那首
        if (resumeAfterDelete)
            playSelected()
        resumeAfterDelete = false
    }

    // ==================================================================
    // 頻譜視覺化
    // ==================================================================

    Process {
        id: nixVisualizerProcess
        command: [
            "nix-visualizer",
            "--sink", "nix-visualizer_sink.monitor",    // 音訊來源 sink
            "--num-bars", "130",                        // 輸出 130 條 bar
            "--bar-max", "281",                         // 每條 bar 的數值上限
            "--fft-size", "8192",                       // FFT 視窗變大,頻率解析度更高、延遲也更高
            "--fft-pad", "1",                           // 不做零填補
            "--min-freq", "20",                         // 分頻下界 20Hz
            "--max-freq", "20000",                      // 分頻上界 20kHz
            "--freq-warp", "1.2",                       // 輕微把更多 bar 分給高頻
            "--spatial-smooth-max-radius", "0",         // 不做跨 bar 空間平滑,保留細節
            "--peak-mix", "0.5",                        // 高頻聚合時 RMS 與峰值各半
            "--dynamic-range-db", "36",                 // 動態範圍
            "--noise-gate-rise", "1",                   // 背景噪音水位追蹤上升得慢
            "--noise-gate-margin", "1.2",               // 噪聲門門檻寬鬆
            "--attack", "1",                            // 上升瞬間到位,沒有延遲
            "--release", "0.75",                        // 基礎重力大小
            "--release-high-boost", "0.25",             // 高頻重力再加重
            "--gravity-db-scale", "32",                 // 音量越大,下墜重力越強
            "--band-independence", "0.5",               // 頻段獨立程度
            "--fps", "120"                              // 幀數
        ]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root.audioData = data.trim().split(",").map(Number)
            }
        }
    }

    // ==================================================================
    // 游標(選取)與顯示視窗
    // ==================================================================

    // 確保 selectedSongId 在目前篩選結果中仍然有效;
    // 無效時優先退回正在播放的歌,否則退回第一首
    function ensureSelection() {
        const filtered = getFilteredList()

        if (filtered.length === 0) {
            selectedSongId = -1
        } else if (!filtered.some(s => s.id === selectedSongId)) {
            const playing = filtered.find(s => s.id === currentSongId)
            selectedSongId = (playing || filtered[0]).id
        }

        computeWindow()
    }

    // 游標在篩選結果中循環移動 delta 格
    function moveSelection(delta) {
        const filtered = getFilteredList()
        if (filtered.length === 0)
            return

        const selectedIndex = filtered.findIndex(s => s.id === selectedSongId)
        selectedSongId = filtered[wrapIndex(selectedIndex + delta, filtered.length)].id
    }

    // 以游標為中心,在固定 windowSize 個格子中填入前後的歌曲。
    // 歌曲數不足 windowSize 時只填中間的 visibleCount 格(不重複填滿),其餘為 null;
    // 歌曲數 >= windowSize 時整個視窗填滿並循環銜接。
    function computeWindow() {
        const filtered = getFilteredList()
        const total = filtered.length
        const slots = new Array(windowSize).fill(null)

        if (total > 0) {
            const anchor = Math.max(0, filtered.findIndex(s => s.id === selectedSongId))
            const visibleCount = Math.min(total, windowSize)
            const firstSlot = centerIndex - Math.floor((visibleCount - 1) / 2)

            for (let i = 0; i < visibleCount; i++) {
                const slot = firstSlot + i
                slots[slot] = filtered[wrapIndex(anchor + slot - centerIndex, total)]
            }
        }

        windowList = slots
    }

    onSongListChanged: ensureSelection()
    onFilterTextChanged: ensureSelection()
    onSelectedSongIdChanged: computeWindow()

    // ==================================================================
    // 剪貼簿
    // ==================================================================

    Process {
        id: pasteProcess
        command: ["wl-paste", "-n"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.filterText += this.text.replace("\n", "")
            }
        }
    }

    Process {
        id: copyProcess
    }

    function copyToClipboard(text) {
        if (!text)
            return

        copyProcess.command = ["wl-copy", "--", text]
        copyProcess.running = true
    }

    // 複製游標選中歌曲的指定欄位,field: "title" | "artist" | "album"
    function copySelectedField(field) {
        const song = songById(selectedSongId)
        if (!song)
            return

        let value = song[field]

        // 沒有 Artist tag 時,退而求其次用 AlbumArtist
        if (field === "artist" && !value)
            value = song.albumartist

        copyToClipboard(value)
    }

    // ==================================================================
    // 鍵盤分派
    // ==================================================================

    function handleKey(event) {
        if (mode === "search")
            handleSearchKey(event)
        else if (mode === "confirm")
            handleConfirmKey(event)
        else
            handleNormalKey(event)

        event.accepted = true
    }

    // ---- NORMAL MODE ----
    function handleNormalKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0

        switch (event.key) {
        case Qt.Key_H:
            // h:倒退 5 秒 / H:上一首
            if (shift)
                advanceTrack(-1)
            else
                sendMpdCommand("seekcur -5")
            break

        case Qt.Key_L:
            // l:快轉 5 秒 / L:下一首
            if (shift)
                advanceTrack(1)
            else
                sendMpdCommand("seekcur +5")
            break

        case Qt.Key_J:
            // j:游標下移一格 / J:下翻一頁
            moveSelection(shift ? windowSize : 1)
            break

        case Qt.Key_K:
            // k:游標上移一格 / K:上翻一頁
            moveSelection(shift ? -windowSize : -1)
            break

        case Qt.Key_Return:
        case Qt.Key_Enter:
            // Enter:播放游標選中的歌曲
            playSelected()
            break

        case Qt.Key_S:
            // s:重新洗牌(不中斷目前播放)
            reshuffle()
            break

        case Qt.Key_C:
            // c:游標跳回正在播放的歌曲
            if (currentSongId !== -1)
                selectedSongId = currentSongId
            break

        case Qt.Key_P:
            // p:播放 / 暫停切換
            if (isPlaying)
                sendMpdCommand("pause 1")
            else
                sendMpdCommandList(["setvol " + defaultVolume, "pause 0"])
            break

        case Qt.Key_U:
            // u:更新歌曲資料庫
            startLibraryUpdate()
            break

        case Qt.Key_D:
            // d:刪除目前搜尋結果的所有歌曲(需搜尋字串非空,並輸入確認字串)
            if (!shift)
                requestDelete()
            break

        case Qt.Key_T:
            // t:複製選中歌曲的歌名
            if (!shift)
                copySelectedField("title")
            break

        case Qt.Key_A:
            // a:複製選中歌曲的演出者 / A:複製選中歌曲的專輯
            copySelectedField(shift ? "album" : "artist")
            break

        case Qt.Key_Slash:
            // /:進入 SEARCH MODE
            mode = "search"
            break

        case Qt.Key_Escape:
            // esc:清空搜尋字串,游標回到正在播放的歌曲
            filterText = ""
            selectedSongId = currentSongId
            break
        }
    }

    // ---- SEARCH MODE ----
    function handleSearchKey(event) {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            pasteProcess.running = true
            return
        }

        switch (event.key) {
        case Qt.Key_Escape:
            // esc:清空搜尋字串並回到 NORMAL MODE
            filterText = ""
            mode = "normal"
            break

        case Qt.Key_Return:
        case Qt.Key_Enter:
            // enter:保留搜尋字串並回到 NORMAL MODE
            mode = "normal"
            break

        case Qt.Key_Backspace:
            filterText = filterText.slice(0, -1)
            break

        default:
            // 可見字元即時加入搜尋字串
            if (event.text && event.text.charCodeAt(0) >= 0x20)
                filterText += event.text
            break
        }
    }

    // ---- CONFIRM MODE ----
    // 必須依序輸入 confirmWord,中途輸入錯誤就取消刪除;
    // 全部輸入完成後按 Enter 才會執行刪除。
    // 單純按下修飾鍵不算輸入(否則打大寫 Y 時會被 Shift 取消)。
    function handleConfirmKey(event) {
        if (modifierKeys.indexOf(event.key) !== -1)
            return

        const isEnter = event.key === Qt.Key_Enter || event.key === Qt.Key_Return
        if (isEnter && statusTyped >= confirmWord.length) {
            executeDelete()
            return
        }

        if (event.text !== confirmWord[statusTyped]) {
            cancelDelete()
            return
        }

        statusTyped++
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
            property alias nixVisualizer: nixVisualizer

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            color: "transparent"
            visible: false
            WlrLayershell.layer: WlrLayer.Overlay

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
                id: playlist
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

                            readonly property bool isSearchBarSlot: index === (root.windowSize - 1) && (root.mode === "search" || root.filterText !== "" || root.statusLabel !== "")
                            readonly property bool isSelected: !isSearchBarSlot && index === root.centerIndex && modelData !== null
                            readonly property bool isPlaying: !isSearchBarSlot && modelData !== null && modelData.id === root.currentSongId

                            color: isSelected ? Utils.Colors.color15 : "transparent"

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
                                color: delegateItem.isSelected ? Utils.Colors.color0 : Utils.Colors.color15
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
                                color: delegateItem.isSelected ? Utils.Colors.color0 : Utils.Colors.color15
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            // 搜尋列內容(左側)
                            Text {
                                visible: delegateItem.isSearchBarSlot && (root.mode === "search" || root.filterText !== "")
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.mode === "search" ? "/ " : "Search: ") + root.filterText
                                + (root.mode === "search" ? "▏" : "")
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 20
                                color: Utils.Colors.color15
                            }

                            // 通用狀態區(右側):UpdateDB 提示 / 刪除確認共用
                            // 前綴文字固定 color15;目標字串(如 "Yes")尚未輸入的字母是 color1,
                            // 已正確輸入的字母變成 color15。
                            Row {
                                visible: delegateItem.isSearchBarSlot && root.statusLabel !== ""
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: root.statusLabel
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 20
                                    color: Utils.Colors.color15
                                }

                                Repeater {
                                    model: root.statusTarget.length

                                    Text {
                                        text: root.statusTarget[index]
                                        font.family: "DejaVu Sans Mono"
                                        font.pixelSize: 20
                                        color: index < root.statusTyped ? Utils.Colors.color15 : Utils.Colors.color1
                                    }
                                }
                            }
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
            ClippingRectangle {
                id: cover
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

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }
            }
            Rectangle {
                id: nixVisualizer
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
                            height: root.audioData[index]
                            color: Utils.Colors.color15

                            anchors.bottom: parent.bottom

                            Behavior on height {
                                NumberAnimation { duration: 50 }
                            }
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
            Rectangle {
                id: playback
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
                    anchors.margins: 20
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20

                    spacing: 8

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
                            color: Utils.Colors.color15
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
                            color: Utils.Colors.color15
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
                        color: Utils.Colors.color1
                        clip: true
                        Rectangle {
                            height: parent.height
                            radius: 3
                            width: parent.width * Math.min(1, Math.max(0, playback.progress))
                            color: Utils.Colors.color15
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
                            color: Utils.Colors.color15
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: playback.formatTime(root.durationTime)
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 20
                            color: Utils.Colors.color15
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
                        playlist: 0,
                        cover: 2,
                        nixVisualizer: 0,
                        playback: 0
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
                nixVisualizerProcess.signal(10)
                Window.Backend.pushWindow({
                        "screenName": Hyprland.focusedMonitor.name,
                        "name": "musicPlayer",
                        "regions": {
                            "playlist": [0, 1310, 890, 0],
                            "cover": [2, 560, 560, 0],
                            "playback": [5, 1880, 140, 0],
                            "nixVisualizer": [3, 560, 320, 210]
                        },
                        "callback": targetPanel.callback
                })
            }
            else{
                Window.Backend.popWindow("musicPlayer")
                nixVisualizerProcess.signal(12)
            }
        }
    }
}
