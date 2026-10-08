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

    // ------------------------------------------------------------------
    // 資料狀態
    // ------------------------------------------------------------------
    // songList 現在是「本地維護」的完整歌曲清單,來源是 mpd 的 listallinfo (整個音樂庫),
    // 不再依賴 mpd 自己的 playlist / playlist id。
    // 啟動時洗牌一次,洗牌後的陣列順序 = 我們自己的播放順序,
    // 每首歌的 id 就是它在這個陣列裡的 index(由 assignIds() 統一指定)。
    property var songList: []          // 本地歌曲清單(含 id / title / artist / albumartist / album / file)
    property string filterText: ""     // 模糊搜尋字串
    property int currentSongId: -1     // 目前「正在播放」的歌曲 id(對應 songList 裡的本地 id)
    property int selectedSongId: -1    // 目前「游標選中」的歌曲 id (j/k 移動、Enter 播放)

    // mpd 實際的 playlist 永遠只會有 0~1 首歌(就是目前正在播的那首)。
    // 每次切歌都是 clear && add <file> && play (透過 mpd socket 直接送 protocol 指令)。
    // switchingTrack 用來避免:我們自己觸發 clear/add/play 時,
    // 中間會有短暫的 "stop" 狀態,若被 idle 監聽誤判成「自然播完」
    // 會導致無限連續換歌的迴圈。
    property bool switchingTrack: false

    readonly property var currentSong: songList.find(s => s.id === currentSongId) || null

    // 目前操作模式:"normal" | "search" | "confirm"
    property string mode: "normal"

    // 固定顯示列數,不捲動;游標固定在正中間 (index = centerIndex)
    readonly property int windowSize: 39
    // 依 windowSize 動態算出,避免改 windowSize 時忘記手動同步這個數字
    readonly property int centerIndex: Math.floor(windowSize / 2)
    property var windowList: []             // 長度固定 windowSize

    property real elapsedTime: 0
    property real durationTime: 0
    property bool isPlaying: false

    // mpd unix socket 路徑
    readonly property string mpdSocketPath: "/run/mpd/socket"

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
    // 小工具:mpd protocol 字串跳脫(雙引號包起來,反斜線 / 引號需要 escape)
    // 取代原本給 shell 用的 shQuote
    // ------------------------------------------------------------------
    function mpdQuote(str) {
        return '"' + String(str).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
    }

    // ==================================================================
    // MPD 指令佇列 socket:所有一次性指令 (listallinfo / clear / add /
    // play / seekcur / pause) 都透過這條連線依序送出。
    // MPD protocol 一次只能有一個指令在途,所以這裡自己維護一個 queue,
    // 上一個指令收到 OK/ACK 之後才會送下一個。
    // ==================================================================
    Socket {
        id: cmdSocket
        path: root.mpdSocketPath
        connected: true

        property bool bannerConsumed: false
        property bool fetchedOnce: false
        property var pendingLines: []
        property var queue: []
        property var current: null

        function enqueue(command, resolve) {
            cmdSocket.queue.push({ command: command, resolve: resolve })
            cmdSocket.processQueue()
        }

        function processQueue() {
            if (!cmdSocket.bannerConsumed)
            return
            if (cmdSocket.current !== null)
            return
            if (cmdSocket.queue.length === 0)
            return

            cmdSocket.current = cmdSocket.queue.shift()
            cmdSocket.write(cmdSocket.current.command + "\n")
            cmdSocket.flush()
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!cmdSocket.bannerConsumed) {
                    // 第一行是 mpd 的 banner,例如 "OK MPD 0.23.x"
                    cmdSocket.bannerConsumed = true
                    if (!cmdSocket.fetchedOnce) {
                        cmdSocket.fetchedOnce = true
                        root.fetchLibrary()
                    }
                    cmdSocket.processQueue()
                    return
                }

                if (line.startsWith("OK") || line.startsWith("ACK")) {
                    const finished = cmdSocket.current
                    const lines = cmdSocket.pendingLines
                    cmdSocket.current = null
                    cmdSocket.pendingLines = []
                    if (finished && finished.resolve)
                    finished.resolve(lines, line)
                    cmdSocket.processQueue()
                } else {
                    cmdSocket.pendingLines.push(line)
                }
            }
        }

        onConnectedChanged: {
            if (!cmdSocket.connected) {
                cmdSocket.connected = true
            }
        }
    }

    // 送一個不需要處理回傳內容的一次性指令
    function sendMpdCommand(command, callback) {
        cmdSocket.enqueue(command, callback || function () {})
    }

    // ------------------------------------------------------------------
    // 取得完整歌曲庫
    // 用 listallinfo 拿到完整 tag 資訊,自己解析、洗牌決定播放順序、
    // 指定本地 id,然後直接播放洗牌後的第 0 首。
    // ------------------------------------------------------------------
    function fetchLibrary() {
        cmdSocket.enqueue("listallinfo", function (lines, status) {
            if (!status.startsWith("OK")) {
                console.warn("listallinfo failed:", status)
                return
            }

            const list = []
            let cur = null

            for (const line of lines) {
                const idx = line.indexOf(": ")
                if (idx === -1)
                continue

                const key = line.slice(0, idx)
                const value = line.slice(idx + 2)

                if (key === "file") {
                    if (cur)
                    list.push(cur)
                    cur = { title: "", artist: "", albumartist: "", album: "", file: value }
                } else if (cur) {
                    if (key === "Title")
                    cur.title = value
                    else if (key === "Artist")
                    cur.artist = value
                    else if (key === "AlbumArtist")
                    cur.albumartist = value
                    else if (key === "Album")
                    cur.album = value
                }
            }
            if (cur)
            list.push(cur)

            let shuffled = root.shuffleList(list)
            shuffled = root.assignIds(shuffled)

            root.songList = shuffled

            if (shuffled.length === 0)
            return

            // 嘗試向 mpd 問目前實際正在播的是哪個 file,
            // 若能對到 songList 裡的某首歌,就沿用它(id / elapsed / duration);
            // 若沒有資料(mpd 目前沒在播 / 對不到),就退回第 0 首。
            root.fetchPlaybackState(function (file, elapsed, duration) {
                const matched = file ? shuffled.find(s => s.file === file) : null

                if (matched) {
                    root.currentSongId = matched.id
                    root.selectedSongId = matched.id
                    root.elapsedTime = elapsed
                    root.durationTime = duration
                } else {
                    root.currentSongId = 0
                    root.selectedSongId = 0
                }
            })
        })
    }

    // 一次問 currentsong + status，取得「目前正在播放」的 file / elapsed / duration。
    // 若目前沒有在播（沒有 file），callback 的 file 會是 null。
    function fetchPlaybackState(callback) {
        cmdSocket.enqueue(
            "command_list_ok_begin\ncurrentsong\nstatus\ncommand_list_end",
            function (lines, status) {
                if (!status.startsWith("OK")) {
                    callback(null, 0, 0)
                    return
                }

                let file = null
                let elapsed = 0
                let duration = 0

                for (const line of lines) {
                    if (file === null && line.startsWith("file:")) {
                        file = line.slice("file:".length).trim()
                    } else if (line.startsWith("elapsed:")) {
                        elapsed = parseFloat(line.slice("elapsed:".length)) || 0
                    } else if (line.startsWith("duration:")) {
                        duration = parseFloat(line.slice("duration:".length)) || 0
                    }
                }

                callback(file, elapsed, duration)
            }
        )
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

    // 核心切歌函式:不再操作 mpd 既有的 playlist 位置,
    // 而是直接把 mpd 的 playlist 清空、塞入指定的那一首、播放。
    // switchingTrack 期間忽略 idle 監聽送來的 "stop" 事件,
    // 避免 clear -> add 中間的短暫 stop 狀態被誤判成自然播完。
    function playSongObject(song) {
        if (!song)
        return

        sendMpdCommand("setvol 44")

        root.switchingTrack = true

        cmdSocket.enqueue("clear", function (_lines1, _status1) {
            cmdSocket.enqueue("add " + root.mpdQuote(song.file), function (_lines2, _status2) {
                cmdSocket.enqueue("play", function (_lines3, _status3) {
                    root.currentSongId = song.id
                    root.selectedSongId = song.id
                    root.switchingTrack = false
                })
            })
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

    // 是否正在跑 mpd database update,U 鍵期間會被擋掉,避免重複觸發
    property bool updatingDb: false

    // ------------------------------------------------------------------
    // 搜尋列右側「通用狀態區」
    // UpdateDB 提示與刪除確認共用同一塊區域,所以改用通用名稱:
    //   statusLabel  : 固定顯示的前綴文字(空字串 = 右側不顯示)
    //   statusTarget : 需要使用者逐字輸入的目標字串(例如 "Yes",可為空)
    //   statusTyped  : 目標字串已正確輸入的字元數(已輸入的字母會變亮)
    // ------------------------------------------------------------------
    property int statusTyped: 0
    readonly property string statusTarget: root.mode === "confirm" ? root.confirmWord : ""
    readonly property string statusLabel: {
        if (root.mode === "confirm")
        return "Confirm deletion : "
        if (root.deleting)
        return "Deleting…"
        if (root.updatingDb)
        return "Song Database is updating…"
        return ""
    }

    // ------------------------------------------------------------------
    // 刪除歌曲 (d)
    // ------------------------------------------------------------------
    readonly property string musicRoot: "/home/niiixkz/Music"
    readonly property string confirmWord: "Yes"    // 大小寫必須完全一致
    property bool deleting: false
    // 刪除時「正在播放的歌也被刪」且當時確實在播放 -> 刪完後要自動播放新選中的歌
    property bool resumeAfterDelete: false

    // 只接受「專輯資料夾/檔名」這種兩層結構,避免 ".." 之類的路徑跑出 musicRoot
    function isSafeSongPath(file) {
        const parts = String(file).split("/")
        if (parts.length !== 2)
        return false
        return parts[0] !== "" && parts[0] !== "." && parts[0] !== ".." && parts[1] !== ""
    }

    // d:進入刪除確認。搜尋字串為空時不動作(避免誤刪整個音樂庫)。
    function requestDelete() {
        if (root.filterText.trim() === "")
        return
        if (root.updatingDb || root.deleting)
        return
        if (root.getFilteredList().some(s => root.isSafeSongPath(s.file)) === false)
        return

        root.statusTyped = 0
        root.mode = "confirm"
    }

    function cancelDelete() {
        root.statusTyped = 0
        root.mode = "normal"
    }

    // 確認通過後,刪除「目前搜尋結果」中的所有歌曲
    function executeDelete() {
        const targets = root.getFilteredList().filter(s => root.isSafeSongPath(s.file))

        root.statusTyped = 0
        root.mode = "normal"

        if (targets.length === 0)
        return

        root.deleting = true

        // 若正在播放的歌也要被刪:先停掉 mpd,並暫時擋住 idle 的「自然播完」判斷,
        // 避免它自動跳去播下一首同樣即將被刪除的歌。
        root.resumeAfterDelete = false
        if (targets.some(s => s.id === root.currentSongId)) {
            root.resumeAfterDelete = root.isPlaying
            root.switchingTrack = true
            root.sendMpdCommand("clear")
        }

        deleteProcess.command = ["bash", "-c", root.deleteScript, "_", root.musicRoot]
        .concat(targets.map(s => s.file))
        deleteProcess.running = true
    }

    // 刪除完成後(只處理腳本回報「確實刪掉了」的檔案)同步本地清單
    function finishDelete(deletedFiles) {
        const gone = {}
        deletedFiles.forEach(f => { gone[f] = true })

        const oldList = root.songList
        const n = oldList.length
        const currentFile = root.currentSong ? root.currentSong.file : null

        // 新游標位置:起點 = currentSongId(可用時),否則 selectedSongId;
        // 從起點開始 id++(循環)直到找到沒被刪的歌
        let selectedFile = null
        let selIdx = oldList.findIndex(s => s.id === root.currentSongId)
        if (selIdx === -1)
        selIdx = oldList.findIndex(s => s.id === root.selectedSongId)
        if (selIdx !== -1) {
            for (let i = 0; i < n; i++) {
                const cand = oldList[(selIdx + i) % n]
                if (!gone[cand.file]) {
                    selectedFile = cand.file
                    break
                }
            }
        }

        // 先拿掉搜尋,再重新指派 id,讓游標在完整清單上歸位
        root.filterText = ""

        let list = oldList.filter(s => !gone[s.file])
        list = root.assignIds(list)

        let newCurrentId = -1
        if (currentFile && !gone[currentFile]) {
            const c = list.find(s => s.file === currentFile)
            if (c)
            newCurrentId = c.id
        }

        root.currentSongId = newCurrentId
        root.songList = list

        const newSelected = selectedFile ? list.find(s => s.file === selectedFile) : null
        root.selectedSongId = newSelected ? newSelected.id : -1

        root.switchingTrack = false
        root.deleting = false

        // 通知 mpd 資料庫檔案已消失(不呼叫 fetchLibrary,所以不會重新洗牌)
        root.sendMpdCommand("update")

        // 播放被中斷(正在播的歌被刪)-> 開始播放新選中的那首
        if (root.resumeAfterDelete && newSelected)
        root.playSongObject(newSelected)
        root.resumeAfterDelete = false
    }

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
                const files = this.text.split("\n").filter(l => l !== "")
                root.finishDelete(files)
            }
        }
    }

    // u:更新歌曲資料庫
    function startLibraryUpdate() {
        if (root.updatingDb)
        return

        root.updatingDb = true

        cmdSocket.enqueue("update", function (lines, status) {
            if (!status.startsWith("OK")) {
                console.warn("update failed:", status)
                root.updatingDb = false
                return
            }
            root.pollUpdateStatus()
        })
    }

    // 反覆查 status,看 updating_db 是否還在,直到 job 結束為止
    function pollUpdateStatus() {
        cmdSocket.enqueue("status", function (lines, status) {
            if (!status.startsWith("OK")) {
                console.warn("status (update poll) failed:", status)
                root.updatingDb = false
                return
            }

            const stillUpdating = lines.some(l => l.startsWith("updating_db:"))

            if (stillUpdating) {
                updatePollTimer.start()
            } else {
                root.updatingDb = false
                root.fetchLibrary()
            }
        })
    }

    // ==================================================================
    // 狀態輪詢 socket:每 0.5 秒送一次 "status",解析 elapsed / duration /
    // state,取代原本 nc + bash case 組成的 mpdStatusScript。
    // 這條連線只負責「進度條」用的資料,不負責判斷歌曲自然播完
    // (那個責任交給下面的 idleSocket)。
    // ==================================================================
    Socket {
        id: statusSocket
        path: root.mpdSocketPath
        connected: true

        property bool bannerConsumed: false
        property bool busy: false

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!statusSocket.bannerConsumed) {
                    statusSocket.bannerConsumed = true
                    return
                }

                if (line.startsWith("elapsed:")) {
                    root.elapsedTime = parseFloat(line.slice("elapsed:".length)) || 0
                } else if (line.startsWith("duration:")) {
                    root.durationTime = parseFloat(line.slice("duration:".length)) || 0
                } else if (line.startsWith("state:")) {
                    root.isPlaying = line.slice("state:".length).trim() === "play"
                } else if (line.startsWith("OK") || line.startsWith("ACK")) {
                    statusSocket.busy = false
                }
            }
        }

        onConnectedChanged: {
            if (!statusSocket.connected) {
                statusSocket.connected = true
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
                statusSocket.write("status\n")
                statusSocket.flush()
            }
        }
    }

    Timer {
        id: updatePollTimer
        interval: 300
        repeat: false
        onTriggered: root.pollUpdateStatus()
    }

    // ==================================================================
    // idle 監聽 socket:只在乎「歌曲何時自然播完」。
    // 送 "idle player" 阻塞等待播放狀態變化,一有回應就查 "status" 拿目前
    // state,若變成 stop 且不是我們自己在切歌(switchingTrack),
    // 代表歌曲自然播完,交給 advanceTrack(1) 決定接下來播什麼。
    // 取代原本 nc + FIFO 組成的 mpdIdleScript。
    // ==================================================================
    Socket {
        id: idleSocket
        path: root.mpdSocketPath
        connected: true

        property bool bannerConsumed: false
        property string awaiting: "idle" // "idle" | "status"

        function sendIdle() {
            idleSocket.awaiting = "idle"
            idleSocket.write("idle player\n")
            idleSocket.flush()
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
                    if (line.startsWith("OK") || line.startsWith("ACK")) {
                        // idle 因為 player 有變化(或被 noidle)而返回 -> 查詢目前狀態
                        idleSocket.awaiting = "status"
                        idleSocket.write("status\n")
                        idleSocket.flush()
                    }
                    // 其餘像 "changed: player" 直接忽略
                } else {
                    if (line.startsWith("state:")) {
                        const state = line.slice("state:".length).trim()
                        if (state === "stop" && !root.switchingTrack) {
                            root.advanceTrack(1)
                        }
                    } else if (line.startsWith("OK") || line.startsWith("ACK")) {
                        idleSocket.sendIdle()
                    }
                }
            }
        }

        onConnectedChanged: {
            if (!idleSocket.connected) {
                idleSocket.connected = true
            }
        }
    }

    property var audioData: []

    Process {
        id: nixVisualizerProcess
        command: [
            "nix-visualizer",
            "--sink", "nix-visualizer_sink.monitor",       // 音訊來源 sink
            "--num-bars", "130",                 // 輸出 130 條 bar
            "--bar-max", "281",                  // 每條 bar 的數值上限
            "--fft-size", "8192",                // FFT 視窗變大,頻率解析度更高、延遲也更高
            "--fft-pad", "1",                    // 不做零填補
            "--min-freq", "20",                  // 分頻下界 20Hz
            "--max-freq", "20000",               // 分頻上界 20kHz
            "--freq-warp", "1.2",                // 輕微把更多 bar 分給高頻
            "--spatial-smooth-max-radius", "0",  // 不做跨 bar 空間平滑,保留細節
            "--peak-mix", "0.5",                 // 高頻聚合時 RMS 與峰值各半
            "--dynamic-range-db", "36",          // 動態範圍
            "--noise-gate-rise", "1",            // 背景噪音水位追蹤上升得慢
            "--noise-gate-margin", "1.2",        // 噪聲門門檻寬鬆
            "--attack", "1",                     // 上升瞬間到位,沒有延遲
            "--release", "0.75",                 // 基礎重力大小
            "--release-high-boost", "0.25",      // 高頻重力再加重
            "--gravity-db-scale", "32",          // 音量越大,下墜重力越強
            "--band-independence", "0.5",        // 頻段獨立程度
            "--fps", "120"                       // 幀數
        ]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                audioData = data.trim().split(",").map(Number)
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
    // Keyboard Dispatcher
    // ------------------------------------------------------------------

    function handleKey(event) {
        if (root.mode === "search") {
            handleSearchKey(event)
        } else if (root.mode === "confirm") {
            handleConfirmKey(event)
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
                sendMpdCommand("seekcur -5")
            }
            break

            case Qt.Key_L:
            if (shift) {
                // L:下一首歌(依 advanceTrack 的 filter 規則)
                advanceTrack(1)
            } else {
                // l:歌曲時間向後(快轉) 5 秒
                sendMpdCommand("seekcur +5")
            }
            break

            case Qt.Key_J:
            if (shift) {
                // J:播放清單游標向下翻頁
                moveSelection(windowSize)
            } else {
                // j:播放清單游標向下一格
                moveSelection(1)
            }
            break

            case Qt.Key_K:
            if (shift) {
                // K:播放清單游標向上翻頁
                moveSelection(-windowSize)
            } else {
                // k:播放清單游標向上一格
                moveSelection(-1)
            }
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
            // p:播放/暫停切換(依目前 statusSocket 輪詢到的 isPlaying 狀態決定要送 pause 0 還是 pause 1)
            sendMpdCommand(root.isPlaying ? "pause 1" : "setvol 44\npause 0")
            break

            case Qt.Key_U:
            // u:更新歌曲資料庫
            startLibraryUpdate()
            break

            case Qt.Key_D:
            // d:刪除目前搜尋結果的所有歌曲(需搜尋字串非空,並輸入 Yes 確認)
            if (!shift)
                requestDelete()
            break

            case Qt.Key_T:
            // t:複製選中歌曲的歌名
            if (!shift)
                copySelectedField("title")
            break

            case Qt.Key_A:
            if (shift) {
                // A:複製選中歌曲的專輯
                copySelectedField("album")
            } else {
                // a:複製選中歌曲的演出者(作曲家)名
                copySelectedField("artist")
            }
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
        command: ["wl-copy", "--", ""]
    }

    function copyToClipboard(text) {
        if (!text || text.length === 0)
            return

        copyProcess.command = ["wl-copy", "--", text]
        copyProcess.running = true
    }

    // 複製「目前游標選中」歌曲的指定欄位
    // field: "title" | "artist" | "album"
    function copySelectedField(field) {
        const song = root.songList.find(s => s.id === root.selectedSongId)
        if (!song)
            return

        let value = song[field]

        // 沒有 Artist tag 時,退而求其次用 AlbumArtist
        if (field === "artist" && (!value || value.length === 0))
            value = song.albumartist

        root.copyToClipboard(value)
    }

    // ---- CONFIRM MODE ----
    // 必須依序輸入 confirmWord("Yes",大小寫須一致),中途輸入錯誤就取消刪除。
    // 單純按下 Shift / Ctrl 等修飾鍵不算輸入,直接忽略(否則打大寫 Y 時會被 Shift 取消)。
    function handleConfirmKey(event) {
        const modifierKeys = [
            Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr,
            Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_CapsLock
        ]
        if (modifierKeys.indexOf(event.key) !== -1)
        return

        if (root.statusTyped >= root.confirmWord.length && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return))
        root.executeDelete()

        const expected = root.confirmWord[root.statusTyped]

        if (event.text !== expected) {
            root.cancelDelete()
            return
        }

        root.statusTyped++
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
            property alias nixVisualizer: nixVisualizer

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

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }
            }
            Rectangle {
                id: nixVisualizer

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

            function callback(str) {
                panelVariants.instances.forEach(p => {
                    const active = p.screenName === screenName && str !== "";
                    p.visible = active;

                    if (!active) return;

                    p.playlist.visible = str.includes("playlist");
                    p.cover.visible = str.includes("cover");
                    p.nixVisualizer.visible = str.includes("nixVisualizer");
                    p.playback.opacity = str.includes("playback");
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
                            "playlist": [0, 1311, 890, 0],
                            "cover": [2, 560, 560, 0],
                            "playback": [5, 1880, 141, 0],
                            "nixVisualizer": [3, 560, 321, 209.5]
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
