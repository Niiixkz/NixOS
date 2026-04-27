pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs

Singleton {
    property bool toggle: true

    property int wallpaperTotal: 0
    property var wallpaperIndex: "000"

    property var wallpaperCount0: ""
    property var wallpaperCount1: ""

    property int totalScreens: Quickshell.screens.length
    property int readyCount: 0

    Component.onCompleted: {
        Promise.all([
            Functions.fetchWithDelayRetry("https://api.github.com/repos/Niiixkz/Wallpaper/git/trees/main", 10000)
        ]).then(function([t]) {
            wallpaperTotal = JSON.parse(t).tree
                .filter(item => item.type === "tree")
                .length;

            fetchWallpaperData();
        });
    }

    property var hJson: {}
    property var vJson: {}
    property var themeJson: {}

    function fetchWallpaperData() {
        wallpaperIndex = (Math.floor(Math.random() * wallpaperTotal)).toString().padStart(3, "0");

        let base = `https://raw.githubusercontent.com/Niiixkz/Wallpaper/main/${wallpaperIndex}`;

        Promise.all([
            Functions.fetchWithDelayRetry(`${base}/_H.json`, 10000),
            Functions.fetchWithDelayRetry(`${base}/_V.json`, 10000),
            Functions.fetchWithDelayRetry(`${base}/theme.json`, 10000)
        ]).then(function([h, v, t]) {
            hJson     = JSON.parse(h);
            vJson     = JSON.parse(v);
            themeJson = JSON.parse(t);

            wallpaperTimer.running = true;
        });
    }

    Timer {
        id: wallpaperTimer
        interval: 0
        running: false
        onTriggered: {
            this.interval = 300000;
            checkProcess.running = true;
        }
    }

    Process {
        id: checkProcess
        running: false
        command: [
            "bash", "-c", `
                list=("osu!" "neovim")

                for process in "\${list[@]}"; do
                    if pgrep -f "\$process" | grep -v "^\$\$\\\$" >/dev/null; then
                        exit 1
                    fi
                done
                exit 0
            `
        ]
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                wallpaperTimer.running = true;
                return;
            }

            if (toggle) {
                wallpaperCount0 = wallpaperIndex;
            } else {
                wallpaperCount1 = wallpaperIndex;
            }
        }
    }

    function monitorReady() {
        if (++readyCount != totalScreens)
            return;

        readyCount = 0;
        toggle = !toggle;

        Colors.updateInternalColor(themeJson)
        Functions.setTimeout(function() {
            updateClockPosition();
            fetchWallpaperData();
        }, 1000);
    }

    function updateClockPosition() {
        const fallback = { fail: true, x: 0, y: 0, tone: "dark" };

        function earcut(pts) {
            // 正規化為逆時針
            let signedArea = 0;
            for (let i = 0; i < pts.length; i++) {
                const j = (i + 1) % pts.length;
                signedArea += pts[i][0] * pts[j][1] - pts[j][0] * pts[i][1];
            }
            if (signedArea < 0) pts = pts.slice().reverse();

            const triangles = [];
            let indices = Array.from({length: pts.length}, (_, i) => i);

            function area2(a, b, c) {
                return (pts[b][0] - pts[a][0]) * (pts[c][1] - pts[a][1])
                    - (pts[c][0] - pts[a][0]) * (pts[b][1] - pts[a][1]);
            }

            function isInsideTriangle(ax, ay, bx, by, cx, cy, px, py) {
                const d1 = (px-bx)*(ay-by) - (ax-bx)*(py-by);
                const d2 = (px-cx)*(by-cy) - (bx-cx)*(py-cy);
                const d3 = (px-ax)*(cy-ay) - (cx-ax)*(py-ay);
                const hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
                const hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
                return !(hasNeg && hasPos);
            }

            function isEar(i) {
                const n = indices.length;
                const a = indices[(i - 1 + n) % n];
                const b = indices[i];
                const c = indices[(i + 1) % n];
                if (area2(a, b, c) <= 0) return false;
                for (let j = 0; j < n; j++) {
                    const idx = indices[j];
                    if (idx === a || idx === b || idx === c) continue;
                    if (isInsideTriangle(
                        pts[a][0], pts[a][1],
                        pts[b][0], pts[b][1],
                        pts[c][0], pts[c][1],
                        pts[idx][0], pts[idx][1]
                    )) return false;
                }
                return true;
            }

            while (indices.length > 3) {
                let clipped = false;
                for (let i = 0; i < indices.length; i++) {
                    if (isEar(i)) {
                        const n = indices.length;
                        const a = indices[(i - 1 + n) % n];
                        const b = indices[i];
                        const c = indices[(i + 1) % n];
                        triangles.push({ ax: pts[a][0], ay: pts[a][1],
                                        bx: pts[b][0], by: pts[b][1],
                                        cx: pts[c][0], cy: pts[c][1] });
                        indices.splice(i, 1);
                        clipped = true;
                        break;
                    }
                }
                if (!clipped) break;
            }

            if (indices.length === 3) {
                const [a, b, c] = indices;
                triangles.push({ ax: pts[a][0], ay: pts[a][1],
                                bx: pts[b][0], by: pts[b][1],
                                cx: pts[c][0], cy: pts[c][1] });
            }

            return triangles;
        }

        function randomPointIn(json) {
            const polys = json?.polys;
            if (!polys?.length) return fallback;

            // 加權選多邊形
            let r = Math.random();
            let poly = polys[polys.length - 1];
            for (const p of polys) {
                r -= p.ratio;
                if (r <= 0) { poly = p; break; }
            }

            const pts = poly.points;

            // earcut 三角剖分（支援凹多邊形）
            const triangles = earcut(pts);
            if (!triangles.length) return fallback;

            let totalArea = 0;
            for (const tr of triangles) {
                tr.area = Math.abs((tr.bx - tr.ax) * (tr.cy - tr.ay)
                                - (tr.cx - tr.ax) * (tr.by - tr.ay)) / 2;
                totalArea += tr.area;
            }

            // 依面積加權選三角形
            let t = Math.random() * totalArea;
            let tri = triangles[triangles.length - 1];
            for (const tr of triangles) {
                t -= tr.area;
                if (t <= 0) { tri = tr; break; }
            }

            // 三角形內均勻隨機點
            const r1 = Math.random();
            const r2 = Math.random();
            const u = 1 - Math.sqrt(r1);
            const v = Math.sqrt(r1) * (1 - r2);
            const w = Math.sqrt(r1) * r2;

            return {
                fail: false,
                x: Math.floor(u * tri.ax + v * tri.bx + w * tri.cx),
                y: Math.floor(u * tri.ay + v * tri.by + w * tri.cy),
                tone: poly.tone,
            };
        }

        const H = randomPointIn(hJson);
        const V = randomPointIn(vJson);

        clockFail       = { H: H.fail, V: V.fail };
        clockLeftMargin = { H: H.x,    V: V.x    };
        clockTopMargin  = { H: H.y,    V: V.y    };
        clockTone       = { H: H.tone, V: V.tone };
    }
 
    property var clockFail: {"H": true, "V": true}
    property var clockLeftMargin: {"H": 0 , "V": 0}
    property var clockTopMargin: {"H": 0, "V": 0}
    property var clockTone: {"H": "dark", "V": "dark"}
}

