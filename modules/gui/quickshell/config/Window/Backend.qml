pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs.Utils as Utils

Singleton {
    // 目前所有的邊框請求，優先權高的在陣列前面（unshift 進去）
    property var requestStack: []

    // 上一次每個 owner 實際顯示的狀態（component 清單 + callback）
    // owner 被 popWindow 掉之後，依然能從這裡拿到 callback 把畫面清空
    property var previousStateMap: ({})

    // ── 鍵盤焦點 / 按鍵分派 ──
    // focusScreen:compositor 目前的焦點螢幕(跟著滑鼠/游標走),
    //              Frontend 只有這個螢幕的 window 才有機會拿 Exclusive
    // focusName  :焦點螢幕上「最後開啟」且需要鍵盤的 request;
    //              焦點螢幕沒有這樣的 panel 時為空字串 -> 不抓任何輸入
    //              同時也是 border 高亮的對象
    property string focusName: ""
    property string focusScreen: ""

    // compositor 的焦點螢幕名稱(目前用 Hyprland 取得)
    readonly property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    onFocusedMonitorNameChanged: updateFocus()
    property var keyHandlers: ({})     // name -> function(event, screenName)

    function registerKeyHandler(name, fn) {
        keyHandlers[name] = fn;
    }

    // 唯一的按鍵入口:Frontend 在焦點螢幕上的 window 收到按鍵後呼叫這裡,
    // 直接派發給「焦點螢幕上最後開啟(堆疊最上層)、需要鍵盤、且可見」的 request
    function dispatchKey(event) {
        const target = requestStack.find(r =>
            r.screenName === focusScreen && r.keyboard && r.visible.length > 0);
        const h = target ? keyHandlers[target.name] : null;
        if (h) h(event, target.screenName);
        event.accepted = true;
    }

    function isOpen(name, screenName) {
        return requestStack.some(r => r.name === name && r.screenName === screenName);
    }

    // 焦點螢幕 = compositor 的焦點螢幕;
    // owner = 該螢幕上堆疊最上層(最後開啟)、需要鍵盤、而且目前真的可見的 request。
    // 焦點螢幕沒有 owner 就不抓輸入,滑鼠移到沒有 panel 的螢幕時輸入會還給該螢幕的視窗
    function updateFocus() {
        const hasKb = r => r.keyboard && r.visible.length > 0;

        let screen = focusedMonitorName;
        if (screen === "") {
            // 取不到 compositor 焦點時的後備:退回全域最後開啟的 panel 所在螢幕
            const top = requestStack.find(hasKb);
            screen = top ? top.screenName : "";
        }

        const owner = requestStack.find(r => r.screenName === screen && hasKb(r));
        const name = owner ? owner.name : "";

        if (name === focusName && screen === focusScreen) return;

        focusName = name;
        focusScreen = screen;
        if (owner) Utils.Functions.imeEnable(false);
    }

    // 螢幕目前所有可見 region 的實際座標/大小
    // regions 格式：[[x, y, width, height, ownerName], ...]，空陣列代表這個螢幕沒有視窗
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

        if (request.keyboard !== undefined) target.keyboard = request.keyboard;
        for (const key in request.regions) {
            target.regions[key] = request.regions[key];
        }

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
        const screens = screenMap();   // 整個流程只查一次螢幕

        calcVisibility(screens);
        updateFocus();   // 可見性算完就能決定 owner,在 notifyRegionResize 之前先定案

        const currentStateMap = {};
        for (const r of requestStack) {
            const key = r.screenName + "::" + r.name;   // 帶上 screenName
            currentStateMap[key] = {
                list: r.visible,
                rects: computeRects(r, screens),
                callback: r.callback
            };
        }

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
                if (listSame && rectsEqual(prev ? prev.rects : {}, currRects)) {
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
                    showCalls.push({ key, callback });
                }
        });

        // show 是延遲執行的,這段時間內 rects 可能又被 move 更新過,
        // 所以執行當下改拿 previousStateMap 裡最新的 rects,避免用舊座標蓋回去。
        const show = () => {
            showCalls.forEach(({ key, callback }) => {
                const latest = previousStateMap[key];
                // owner 在等待期間已被 pop(或這個螢幕上已不存在):
                // 它的 hide 早就處理過了,不能再把畫面叫回來
                if (!latest) return;
                callback(latest.list.join(","), latest.rects);
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
    }

    // screenName -> screen 物件
    function screenMap() {
        const map = {};
        Quickshell.screens.forEach(s => map[s.name] = s);
        return map;
    }

    // 算出某個 request 目前「可見」的每個 region 的實際 [x, y, width, height]
    function computeRects(r, screens = screenMap()) {
        const rects = {};
        const screen = screens[r.screenName];

        if (!screen) {
            return rects;
        }

        for (const name of r.visible) {
            const [index, width, height, offset] = r.regions[name];
            const [x, y] = regionToCoordinate(screen, index, width, height, offset);
            rects[name] = [x, y, width, height];
        }

        return rects;
    }

    // 只有同一個螢幕的 region 才會互相判斷碰撞；
    // 優先權高的（陣列前面）先決定可見，再往後擋住較低優先權的重疊 region
    function calcVisibility(screens = screenMap()) {
        const stack = requestStack;

        for (const r of stack) {
            r.visible = Object.keys(r.regions);
        }

        for (let i = 0; i < stack.length - 1; i++) {
            const upper = stack[i];
            if (upper.visible.length === 0) continue;

            const screen = screens[upper.screenName];
            // 上層 region 的座標只算一次，不用在每次比對時重算
            const upperBoxes = upper.visible.map(n => regionBox(screen, upper.regions[n]));

            for (let j = i + 1; j < stack.length; j++) {
                const lower = stack[j];
                if (upper.screenName !== lower.screenName || lower.visible.length === 0) continue;

                lower.visible = lower.visible.filter(name => {
                    const box = regionBox(screen, lower.regions[name]);
                    return !upperBoxes.some(u => boxesConflict(u, box));
                });
            }
        }
    }

    function notifyRegionResize() {
        const screens = Quickshell.screens;
        const screenMapByName = {};
        const perScreen = {};

        // 每個 rect 多帶一個 owner(request 名稱),Frontend 靠它判斷是不是焦點視窗
        screens.forEach(s => {
                screenMapByName[s.name] = s;
                perScreen[s.name] = [];
        });

        for (const r of requestStack) {
            const bucket = perScreen[r.screenName];
            if (!bucket) continue;

            const rects = computeRects(r, screenMapByName);
            for (const name in rects) {
                bucket.push([...rects[name], r.name]);
            }
        }

        screens.forEach(s => windowChange(s.name, perScreen[s.name]));
    }

    function arraysEqual(a, b) {
        return a.length === b.length && a.every((v, i) => v === b[i]);
    }

    // rects 格式 { name: [x, y, w, h] }，逐項比較（取代 JSON.stringify）
    function rectsEqual(a, b) {
        const keys = Object.keys(a);
        if (keys.length !== Object.keys(b).length) return false;

        for (const k of keys) {
            const p = a[k];
            const q = b[k];
            if (!q || p[0] !== q[0] || p[1] !== q[1] || p[2] !== q[2] || p[3] !== q[3]) {
                return false;
            }
        }
        return true;
    }

    // region -> { index, x, y, w, h }
    function regionBox(screen, region) {
        const [index, w, h, offset] = region;
        if (!screen) return { index, x: NaN, y: NaN, w, h };
        const [x, y] = regionToCoordinate(screen, index, w, h, offset);
        return { index, x, y, w, h };
    }

    function boxesConflict(a, b) {
        if (a.index === b.index) {
            return true;
        }

        // 找不到螢幕時無法算座標，只能靠 index 判斷
        if (isNaN(a.x) || isNaN(b.x)) {
            return false;
        }

        return !(
            a.x + a.w < b.x ||
            a.x > b.x + b.w ||
            a.y + a.h < b.y ||
            a.y > b.y + b.h
        );
    }

    function isRegionConflict(screen, r0, r1) {
        return boxesConflict(regionBox(screen, r0), regionBox(screen, r1));
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
