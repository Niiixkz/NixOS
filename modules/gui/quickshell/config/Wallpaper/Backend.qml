pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.Utils as Utils

Singleton {
    id: root

    // ───────────────────────── 設定 ─────────────────────────
    readonly property string wallpaperRoot: Quickshell.env("HOME") + "/Wallpaper"
    readonly property int changeInterval: 5 * 60 * 1000   // 換桌布間隔
    readonly property int fadeDuration: 500               // 淡入時間 (Frontend 共用)
    readonly property int clockDelay: 500                 // 換完桌布後多久移動時鐘

    // ───────────────────────── 狀態 ─────────────────────────
    // 兩個圖層 (slot 0 / 1) 輪流當 "上層" 與 "下層"，桌布不會被重新載入：
    //   idle    : 閒置。下層 = 目前桌布，上層是空的 (透明)
    //   loading : 新桌布載入到上層 (透明)
    //   fading  : 上層 opacity 0 -> 1
    //   淡入結束 : 兩層對調 -> 剛淡入的上層直接變成下層，舊下層清空當新的上層
    property string phase: "idle"
    readonly property bool overlayVisible: phase === "fading"

    property var slots: ["", ""]           // 每個圖層載入的桌布編號
    property int topSlot: 0                // 目前當作上層的圖層
    property string currentWallpaper: ""   // 目前顯示的桌布編號
    property string pendingIndex: ""       // 已挑好、正在讀資料的桌布
    readonly property string pendingDir: wallpaperRoot + "/" + pendingIndex

    property int wallpaperTotal: 0
    property var themeJson: ({})

    // 時鐘 (Frontend 使用)
    property var clockFail: ({ "H": true, "V": true })
    property var clockLeftMargin: ({ "H": 0, "V": 0 })
    property var clockTopMargin: ({ "H": 0, "V": 0 })
    property var clockTone: ({ "H": "dark", "V": "dark" })

    // 預先三角剖分好的區域 (換桌布時算一次，之後抽點很便宜)
    property var _hRegions: ({ regions: [], totalRatio: 0 })
    property var _vRegions: ({ regions: [], totalRatio: 0 })

    // 已完成載入的螢幕名稱
    property var _ready: ({})

    readonly property var _fallback: ({ fail: true, x: 0, y: 0, tone: "dark" })

    Component.onCompleted: listProcess.running = true

    function wallpaperUrl(index, orientation) {
        return index === "" ? "" : `${wallpaperRoot}/${index}/${orientation}.avif`;
    }

    // ───────────────────────── 流程 ─────────────────────────

    // 1. 計算桌布數量
    Process {
        id: listProcess
        command: [
            "find", root.wallpaperRoot,
            "-mindepth", "1", "-maxdepth", "1",
            "-type", "d", "-name", "[0-9][0-9][0-9]"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpaperTotal = text.split("\n").filter(l => l.length > 0).length;
                root.fetchWallpaperData();
            }
        }
    }

    // 2. 隨機挑一張 (不重複目前這張) 並讀取它的 json
    function fetchWallpaperData() {
        if (wallpaperTotal <= 0)
            return;

        let index;
        do {
            index = Math.floor(Math.random() * wallpaperTotal).toString().padStart(3, "0");
        } while (wallpaperTotal > 1 && index === currentWallpaper);

        pendingIndex = index;
        dataProcess.running = true;
    }

    Process {
        id: dataProcess
        command: [
            "jq", "-n",
            "--slurpfile", "h", `${root.pendingDir}/_H.json`,
            "--slurpfile", "v", `${root.pendingDir}/_V.json`,
            "--slurpfile", "t", `${root.pendingDir}/theme.json`,
            "{h:$h[0],v:$v[0],theme:$t[0]}"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let obj;
                try {
                    obj = JSON.parse(text);
                } catch (e) {
                    console.warn("Wallpaper: failed to read data of", root.pendingIndex);
                    root.fetchWallpaperData();
                    return;
                }

                root.themeJson = obj.theme;
                root._hRegions = root.prepareRegions(obj.h);
                root._vRegions = root.prepareRegions(obj.v);

                // 第一次直接載入，之後等待下一個週期
                if (root.currentWallpaper === "")
                    checkProcess.running = true;
                else
                    wallpaperTimer.restart();
            }
        }
    }

    Timer {
        id: wallpaperTimer
        interval: root.changeInterval
        onTriggered: checkProcess.running = true
    }

    // 3. 檢查是否有不該被打斷的程式 (例如 osu!)
    //    '[o]su!' 的寫法可避免 pgrep 比對到自己
    Process {
        id: checkProcess
        command: ["bash", "-c", "! pgrep -f '[o]su!' >/dev/null"]
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 || root.pendingIndex === root.currentWallpaper) {
                wallpaperTimer.restart();
                return;
            }
            root.startLoading();
        }
    }

    function _setSlot(i, index) {
        const s = slots.slice();
        s[i] = index;
        slots = s;
    }

    // 4. 把新桌布放到上層 (透明) 開始載入
    function startLoading() {
        _ready = ({});
        phase = "loading";
        _setSlot(topSlot, pendingIndex);
    }

    function _allReady() {
        return Quickshell.screens.every(s => _ready[s.name] === true);
    }

    // 上層載入完成 (每個螢幕各呼叫一次)
    function overlayReady(name) {
        if (phase !== "loading")
            return;

        _ready[name] = true;
        if (_allReady())
            startFade();
    }

    function overlayFailed() {
        if (phase !== "loading")
            return;

        console.warn("Wallpaper: failed to load", pendingIndex);
        phase = "idle";
        _setSlot(topSlot, "");
        fetchWallpaperData();
    }

    // 5. 上層 0 -> 1
    function startFade() {
        _ready = ({});
        phase = "fading";
        Utils.Colors.updateInternalColor(themeJson);
        fadeTimer.restart();
    }

    Timer {
        id: fadeTimer
        interval: root.fadeDuration
        onTriggered: root.finishFade()
    }

    // 6. 淡入完成：兩層對調。
    //    剛淡入的上層直接變成下層 (不重新載入、不閃爍)；
    //    舊的下層清空，成為下一次的上層，並瞬間回到透明。
    function finishFade() {
        const oldBase = 1 - topSlot;

        currentWallpaper = slots[topSlot];
        _setSlot(oldBase, "");
        topSlot = oldBase;
        phase = "idle";

        clockTimer.restart();
    }

    Timer {
        id: clockTimer
        interval: root.clockDelay
        onTriggered: {
            root.updateClockPosition();
            root.fetchWallpaperData();
        }
    }

    // ───────────────────────── 時鐘位置 ─────────────────────────

    function updateClockPosition() {
        const H = pickPoint(_hRegions);
        const V = pickPoint(_vRegions);

        clockFail       = { H: H.fail, V: V.fail };
        clockLeftMargin = { H: H.x,    V: V.x    };
        clockTopMargin  = { H: H.y,    V: V.y    };
        clockTone       = { H: H.tone, V: V.tone };
    }

    // 把 json 內每個多邊形剖成三角形並預先算好面積
    function prepareRegions(json) {
        const regions = [];
        let totalRatio = 0;

        for (const poly of (json?.polys ?? [])) {
            const tris = triangulate(poly.points);
            if (!tris.length)
                continue;

            let area = 0;
            for (const t of tris) {
                t.area = Math.abs((t.bx - t.ax) * (t.cy - t.ay)
                                - (t.cx - t.ax) * (t.by - t.ay)) / 2;
                area += t.area;
            }

            const ratio = Number(poly.ratio ?? 1);
            regions.push({ ratio: ratio, tone: poly.tone, tris: tris, area: area });
            totalRatio += ratio;
        }

        return { regions: regions, totalRatio: totalRatio };
    }

    // 依權重 / 面積抽出一個均勻隨機點
    function pickPoint(prepared) {
        const regions = prepared.regions;
        if (!regions.length)
            return _fallback;

        let r = Math.random() * prepared.totalRatio;
        let region = regions[regions.length - 1];
        for (const g of regions) {
            r -= g.ratio;
            if (r <= 0) { region = g; break; }
        }

        let t = Math.random() * region.area;
        let tri = region.tris[region.tris.length - 1];
        for (const tr of region.tris) {
            t -= tr.area;
            if (t <= 0) { tri = tr; break; }
        }

        const r1 = Math.sqrt(Math.random());
        const r2 = Math.random();
        const u = 1 - r1;
        const v = r1 * (1 - r2);
        const w = r1 * r2;

        return {
            fail: false,
            x: Math.floor(u * tri.ax + v * tri.bx + w * tri.cx),
            y: Math.floor(u * tri.ay + v * tri.by + w * tri.cy),
            tone: region.tone
        };
    }

    // Ear clipping 三角剖分 (支援凹多邊形)
    function triangulate(points) {
        if (!points || points.length < 3)
            return [];

        let pts = points;

        // 正規化為逆時針
        let signedArea = 0;
        for (let i = 0; i < pts.length; i++) {
            const j = (i + 1) % pts.length;
            signedArea += pts[i][0] * pts[j][1] - pts[j][0] * pts[i][1];
        }
        if (signedArea < 0)
            pts = pts.slice().reverse();

        const cross = (a, b, c) =>
            (pts[b][0] - pts[a][0]) * (pts[c][1] - pts[a][1])
          - (pts[c][0] - pts[a][0]) * (pts[b][1] - pts[a][1]);

        const inside = (a, b, c, p) => {
            const [ax, ay] = pts[a], [bx, by] = pts[b], [cx, cy] = pts[c], [px, py] = pts[p];
            const d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by);
            const d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy);
            const d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay);
            const hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
            const hasPos = d1 > 0 || d2 > 0 || d3 > 0;
            return !(hasNeg && hasPos);
        };

        const makeTri = (a, b, c) => ({
            ax: pts[a][0], ay: pts[a][1],
            bx: pts[b][0], by: pts[b][1],
            cx: pts[c][0], cy: pts[c][1],
            area: 0
        });

        const indices = Array.from({ length: pts.length }, (_, i) => i);
        const triangles = [];

        const isEar = (i) => {
            const n = indices.length;
            const a = indices[(i - 1 + n) % n];
            const b = indices[i];
            const c = indices[(i + 1) % n];
            if (cross(a, b, c) <= 0)
                return false;
            for (let j = 0; j < n; j++) {
                const p = indices[j];
                if (p === a || p === b || p === c)
                    continue;
                if (inside(a, b, c, p))
                    return false;
            }
            return true;
        };

        while (indices.length > 3) {
            let clipped = false;
            for (let i = 0; i < indices.length; i++) {
                if (!isEar(i))
                    continue;
                const n = indices.length;
                triangles.push(makeTri(indices[(i - 1 + n) % n], indices[i], indices[(i + 1) % n]));
                indices.splice(i, 1);
                clipped = true;
                break;
            }
            if (!clipped)
                break;
        }

        if (indices.length === 3)
            triangles.push(makeTri(indices[0], indices[1], indices[2]));

        return triangles;
    }
}
