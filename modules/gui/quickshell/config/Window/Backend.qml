pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.Utils as Utils

Singleton {
    // 目前所有的邊框請求，優先權高的在陣列前面（unshift 進去）
    property var requestStack: []

    // 上一次每個 owner 實際顯示的狀態（component 清單 + callback）
    // 用這一份取代原本的 previousVisibleMap + callbackRegistry，
    // owner 被 popWindow 掉之後，依然能從這裡拿到 callback 把畫面清空
    property var previousStateMap: ({})

    // ── 新增:鍵盤焦點 / 按鍵分派 ──
    property string focusName: ""      // 目前持有鍵盤的 widget
    property string focusScreen: ""
    property var keyHandlers: ({})     // name -> function(event)
    property int focusToken: 0

    function registerKeyHandler(name, fn) {
        keyHandlers[name] = fn;
    }

    // 所有 widget 的 Keys.onPressed 都丟進來,由 Backend 轉給目前的 owner
    function dispatchKey(event) {
        const h = keyHandlers[focusName];
        if (h) h(event);
        event.accepted = true;
    }

    // 堆疊最上層、需要鍵盤、而且目前真的可見的 request 就是 owner
    function updateFocus() {
        const owner = requestStack.find(r => r.keyboard && r.visible.length > 0);
        const name = owner ? owner.name : "";
        const screen = owner ? owner.screenName : "";

        if (name === focusName && screen === focusScreen) return;

        // 先清成空,讓舊 owner 放掉 Exclusive,稍後再給新 owner,
        // 這樣新 owner 一定是「None -> Exclusive」,compositor 才會把焦點重新給它
        const token = ++focusToken;
        focusName = "";
        focusScreen = "";
        if (!owner) return;

        // Utils.Functions.setTimeout(() => {
            if (token !== focusToken) return;
            focusName = name;
            focusScreen = screen;
        // }, 50);
    }

    // 螢幕目前所有可見 region 的實際座標/大小
    // regions 格式：[[x, y, width, height], ...]，空陣列代表這個螢幕沒有視窗
    signal windowChange(var screenName, var regions)

    function pushWindow(request) {
        requestStack = requestStack.filter(r => r.name !== request.name);

        requestStack.unshift({
                screenName: request.screenName,
                name: request.name,
                regions: request.regions,
                callback: request.callback,
                keyboard: request.keyboard ?? false,
                visible: []
        });

        recompute();
    }

    function updateWindow(request) {
        const target = requestStack.find(r => r.name === request.name);

        if (!target) {
            return;
        }

        if (request.keyboard !== undefined) target.keyboard = request.keyboard;   // 新增
        Object.entries(request.regions).forEach(([key, value]) => {
            target.regions[key] = value;
        });

        recompute();
    }

    function popWindow(name) {
        requestStack = requestStack.filter(r => r.name !== name);
        recompute();
    }

    // 重新計算可見性與座標,把跟上次相比有變化的 owner 分成三類處理:
    //   hide :有 region 消失 -> 先呼叫 callback 把它們收掉
    //   show :有 region 出現 -> 等 regionsResized 之後再呼叫 callback 顯示
    //   move :可見清單沒變,但 x/y/width/height 變了(例如 launcher 打字變寬)-> 立刻套用新座標
    // callback 的簽名是 callback(visibleStr, rects),
    // rects 格式:{ regionName: [x, y, width, height] },只包含目前可見的 region。
    function recompute() {
        calcVisibility();

        const currentStateMap = {};
        requestStack.forEach(r => {
                const key = r.screenName + "::" + r.name;   // <- 關鍵：帶上 screenName
                currentStateMap[key] = {
                    list: r.visible,
                    rects: computeRects(r),
                    callback: r.callback
                };
        });

        const allKeys = new Set([...Object.keys(previousStateMap), ...Object.keys(currentStateMap)]);

        const hideCalls = [];
        const showCalls = [];
        const moveCalls = [];

        allKeys.forEach(key => {
                const prev = previousStateMap[key];
                const curr = currentStateMap[key];

                const prevList = prev ? prev.list : [];
                const currList = curr ? curr.list : [];
                const currRects = curr ? curr.rects : {};

                const listSame = arraysEqual(prevList, currList);
                const rectsSame = JSON.stringify(prev ? prev.rects : {}) === JSON.stringify(currRects);

                if (listSame && rectsSame) {
                    return;
                }

                const callback = curr ? curr.callback : prev.callback;

                // 只有座標/大小變了:不需要 hide/show 流程,直接套用
                if (listSame) {
                    moveCalls.push({ callback, list: currList, rects: currRects });
                    return;
                }

                const surviving = currList.filter(c => prevList.includes(c));

                if (surviving.length < prevList.length) {
                    hideCalls.push({ callback, list: surviving, rects: currRects });
                }

                if (surviving.length < currList.length) {
                    showCalls.push({ key, callback, list: currList, rects: currRects });
                }
        });

        // show 是延遲執行的,這段時間內 rects 可能又被 move 更新過,
        // 所以執行當下改拿 previousStateMap 裡最新的 rects,避免用舊座標蓋回去。
        const show = () => {
            showCalls.forEach(({ key, callback, list, rects }) => {
                    const latest = previousStateMap[key];
                    callback(list.join(","), latest ? latest.rects : rects);
            });
        };

        const resizeAndShow = () => {
            notifyRegionResize();
            Utils.Functions.setTimeout(show, 250);
        };

        moveCalls.forEach(({ callback, list, rects }) => callback(list.join(","), rects));

        if (hideCalls.length) {
            hideCalls.forEach(({ callback, list, rects }) => callback(list.join(","), rects));
            Utils.Functions.setTimeout(resizeAndShow, 250);
        } else {
            resizeAndShow();
        }

        previousStateMap = currentStateMap;
        updateFocus();
    }

    // 算出某個 request 目前「可見」的每個 region 的實際 [x, y, width, height]
    function computeRects(r) {
        const rects = {};
        const screen = Quickshell.screens.find(s => s.name === r.screenName);

        if (!screen) {
            return rects;
        }

        r.visible.forEach(name => {
                const [index, width, height, offset] = r.regions[name];
                const [x, y] = regionToCoordinate(screen, index, width, height, offset);
                rects[name] = [x, y, width, height];
        });

        return rects;
    }

    // 只有同一個螢幕的 region 才會互相判斷碰撞；
    // 優先權高的（陣列前面）先決定可見，再往後擋住較低優先權的重疊 region
    function calcVisibility() {
        requestStack.forEach(r => {
                r.visible = Object.keys(r.regions);
        });

        for (let i = 0; i < requestStack.length; i++) {
            const upper = requestStack[i];
            const screen = Quickshell.screens.find(s => s.name === upper.screenName);
            const upperRegions = upper.visible.map(n => upper.regions[n]);

            for (let j = i + 1; j < requestStack.length; j++) {
                const lower = requestStack[j];
                if (upper.screenName !== lower.screenName) continue;

                lower.visible = lower.visible.filter(name =>
                    !upperRegions.some(r => isRegionConflict(screen, r, lower.regions[name]))
                );
            }
        }
    }

    function notifyRegionResize() {
        Quickshell.screens.forEach((screen) => {
                const regions = [];

                requestStack.forEach(r => {
                        if (r.screenName !== screen.name) return;
                        regions.push(...Object.values(computeRects(r)));
                });

                windowChange(screen.name, regions);
        });
    }

    function arraysEqual(a, b) {
        return a.length === b.length && a.every((v, i) => v === b[i]);
    }

    function isRegionConflict(screen, r0, r1) {
        const [index0, w0, h0, offset0] = r0;
        const [index1, w1, h1, offset1] = r1;

        if (index0 === index1) {
            return true;
        }

        const [x0, y0] = regionToCoordinate(screen, index0, w0, h0, offset0);
        const [x1, y1] = regionToCoordinate(screen, index1, w1, h1, offset1);

        return !(
            x0 + w0 < x1 ||
            x0 > x1 + w1 ||
            y0 + h0 < y1 ||
            y0 > y1 + h1
        );
    }

    function regionToCoordinate(screen, index, width, height, offset) {
        const W = screen.width;
        const H = screen.height;
        const CX = W / 2;
        const CY = H / 2;
        const padding = 20;

        switch (index) {
            case 0: return [0 + padding, 0 + padding];
            case 1: return [CX - width / 2 + offset, 0 + padding];
            case 2: return [W - width - padding, 0 + padding];
            case 3: return [W - width - padding, CY - height / 2 + offset];
            case 4: return [W - width - padding, H - height - padding];
            case 5: return [CX - width / 2 - offset, H - height - padding];
            case 6: return [0 + padding, H - height - padding];
            case 7: return [0 + padding, CY - height / 2 - offset];
        }
    }
}
