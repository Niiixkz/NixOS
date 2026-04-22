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
            const xs = pts.map(p => p[0]);
            const ys = pts.map(p => p[1]);

            // 用三角剖分（fan triangulation）精確採樣
            // 將多邊形分成以 pts[0] 為頂點的扇形三角形
            const triangles = [];
            let totalArea = 0;
            for (let i = 1; i < pts.length - 1; i++) {
                const ax = pts[0][0], ay = pts[0][1];
                const bx = pts[i][0], by = pts[i][1];
                const cx = pts[i+1][0], cy = pts[i+1][1];
                const area = Math.abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)) / 2;
                totalArea += area;
                triangles.push({ ax, ay, bx, by, cx, cy, area });
            }

            // 依面積加權選三角形，再用均勻分佈在三角形內採樣
            let t = Math.random() * totalArea;
            let tri = triangles[triangles.length - 1];
            for (const tr of triangles) {
                t -= tr.area;
                if (t <= 0) { tri = tr; break; }
            }

            // 三角形內均勻隨機點（sqrt 修正確保均勻分布）
            const u = 1 - Math.sqrt(Math.random());
            const v = Math.random() * (1 - u);
            const w = 1 - u - v;
            return {
                fail: false,
                x: Math.floor(u * tri.ax + v * tri.bx + w * tri.cx),
                y: Math.floor(u * tri.ay + v * tri.by + w * tri.cy),
                tone: poly.tone,
            };
        }

        const H = randomPointIn(hJson);
        const V = randomPointIn(vJson);

        clockFail       = { H: H.fail,  V: V.fail  };
        clockLeftMargin = { H: H.x,     V: V.x     };
        clockTopMargin  = { H: H.y,     V: V.y     };
        clockTone       = { H: H.tone,  V: V.tone  };
    }
 
    property var clockFail: {"H": true, "V": true}
    property var clockLeftMargin: {"H": 0 , "V": 0}
    property var clockTopMargin: {"H": 0, "V": 0}
    property var clockTone: {"H": "dark", "V": "dark"}
}

