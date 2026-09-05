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
                visible: []
        });

        recompute();
    }

    function popWindow(name) {
        requestStack = requestStack.filter(r => r.name !== name);
        recompute();
    }

    // 重新計算可見性，把跟上次相比有變化的 owner 分成 hide / show 兩批呼叫，
    // 中間夾一次 regionsResized 通知，確保 frontend 先拿到新的版面大小
    // 再顯示新東西。不管是全新 region 出現還是純搬動，這套 diff 都能處理。
    function recompute() {
        calcVisibility();

        const currentStateMap = {};
        requestStack.forEach(r => {
                const key = r.screenName + "::" + r.name;   // <- 關鍵：帶上 screenName
                currentStateMap[key] = {
                    list: r.visible,
                    callback: r.callback
                };
        });

        const allKeys = new Set([...Object.keys(previousStateMap), ...Object.keys(currentStateMap)]);

        const hideCalls = [];
        const showCalls = [];

        allKeys.forEach(key => {
                const prev = previousStateMap[key];
                const curr = currentStateMap[key];

                const prevList = prev ? prev.list : [];
                const currList = curr ? curr.list : [];

                if (arraysEqual(prevList, currList)) {
                    return;
                }

                const callback = curr ? curr.callback : prev.callback;
                const surviving = currList.filter(c => prevList.includes(c));

                if (surviving.length < prevList.length) {
                    hideCalls.push({ callback, list: surviving });
                }

                if (surviving.length < currList.length) {
                    showCalls.push({ callback, list: currList });
                }
        });

        const show = () => {
            showCalls.forEach(({ callback, list }) => callback(list.join(",")));
        };

        const resizeAndShow = () => {
            notifyRegionResize();
            Utils.Functions.setTimeout(show, 250);
        };

        if (hideCalls.length) {
            hideCalls.forEach(({ callback, list }) => callback(list.join(",")));
            Utils.Functions.setTimeout(resizeAndShow, 250);
        } else {
            resizeAndShow();
        }

        previousStateMap = currentStateMap;
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
                const screenName = screen.name;
                const regions = [];

                requestStack.forEach(r => {
                        if (r.screenName !== screenName) return;

                        r.visible.forEach(name => {
                                const [index, width, height, offset] = r.regions[name];
                                const [x, y] = regionToCoordinate(screen, index, width, height, offset);
                                regions.push([x, y, width, height]);
                        });
                });

                windowChange(screenName, regions);
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
