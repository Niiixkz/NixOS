import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import qs.Utils as Utils

Variants {
    model: Quickshell.screens
    id: root
    PanelWindow {
        id: panelWindow
        property var modelData
        screen: modelData
        readonly property var screenName: modelData.name
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        mask: Region { }
        WlrLayershell.layer: WlrLayer.Top

        // 面板池：每個項目描述一個 Rect 的狀態
        // roles: x, y, w, h, shown
        ListModel {
            id: rectModel
        }

        // 匈牙利演算法 (Kuhn-Munkres, O(n^3))
        // 輸入: costMatrix[i][j] = 第 i 個 row 配對第 j 個 col 的成本 (方陣，n x n)
        // 輸出: rowAssign[i] = 配對到的 col index (0-indexed)
        // 內部採用 1-indexed 版本（經典 e-maxx 實作），最後轉回 0-indexed
        function hungarianSolve(costMatrix) {
            const n = costMatrix.length
            const INF = 1e15

            const u = new Array(n + 1).fill(0)
            const v = new Array(n + 1).fill(0)
            const p = new Array(n + 1).fill(0) // p[j] = 配對到 col j 的 row (1-indexed)，0 表示未配對
            const way = new Array(n + 1).fill(0)

            for (let i = 1; i <= n; i++) {
                p[0] = i
                let j0 = 0
                const minv = new Array(n + 1).fill(INF)
                const used = new Array(n + 1).fill(false)
                do {
                    used[j0] = true
                    const i0 = p[j0]
                    let delta = INF
                    let j1 = -1
                    for (let j = 1; j <= n; j++) {
                        if (!used[j]) {
                            const cur = costMatrix[i0 - 1][j - 1] - u[i0] - v[j]
                            if (cur < minv[j]) {
                                minv[j] = cur
                                way[j] = j0
                            }
                            if (minv[j] < delta) {
                                delta = minv[j]
                                j1 = j
                            }
                        }
                    }
                    for (let j = 0; j <= n; j++) {
                        if (used[j]) {
                            u[p[j]] += delta
                            v[j] -= delta
                        } else {
                            minv[j] -= delta
                        }
                    }
                    j0 = j1
                } while (p[j0] !== 0)
                do {
                    const j1 = way[j0]
                    p[j0] = p[j1]
                    j0 = j1
                } while (j0)
            }

            // rowAssign[i-1] (0-indexed row) = j-1 (0-indexed col)
            const rowAssign = new Array(n).fill(-1)
            for (let j = 1; j <= n; j++) {
                if (p[j] > 0)
                    rowAssign[p[j] - 1] = j - 1
            }
            return rowAssign
        }

        // 對「已顯示的舊視窗」與「新需求」做全域最小總距離配對
        // shownItems: [{index, cx, cy}]，remainingOps: [{opIndex, x, y, w, h, cx, cy}]
        // 回傳: { slotIndex(model index) -> op }
        function solveAssignment(shownItems, remainingOps) {
            const assignment = {}
            const n = shownItems.length
            const m = remainingOps.length
            if (n === 0 || m === 0)
                return assignment

            const size = Math.max(n, m)
            const PADDING_COST = 1e6 // 遠大於任何真實距離，代表虛擬配對

            // 建立方陣：超出 n 或 m 的部分為虛擬 row/col，成本設為極大值，
            // 讓演算法自然避免使用它們（除非別無選擇）
            const cost = []
            for (let i = 0; i < size; i++) {
                const row = []
                for (let j = 0; j < size; j++) {
                    if (i < n && j < m) {
                        const s = shownItems[i]
                        const o = remainingOps[j]
                        const dx = s.cx - o.cx
                        const dy = s.cy - o.cy
                        row.push(Math.sqrt(dx * dx + dy * dy))
                    } else {
                        row.push(PADDING_COST)
                    }
                }
                cost.push(row)
            }

            const rowAssign = hungarianSolve(cost)

            for (let i = 0; i < n; i++) {
                const j = rowAssign[i]
                if (j >= 0 && j < m) {
                    assignment[shownItems[i].index] = remainingOps[j]
                }
            }
            return assignment
        }

        // 依「最近中心點距離」進行舊視窗優先配對，不足才建立新視窗
        function updateRects(operations) {
            // 收集目前已顯示的項目
            let shownItems = []
            for (let i = 0; i < rectModel.count; i++) {
                const it = rectModel.get(i)
                if (it.shown) {
                    shownItems.push({
                        index: i,
                        cx: it.x + it.w / 2,
                        cy: it.y + it.h / 2
                    })
                }
            }

            // 待滿足的新需求
            let remainingOps = []
            for (let j = 0; j < operations.length; j++) {
                const op = operations[j]
                remainingOps.push({
                    opIndex: j,
                    x: op[0],
                    y: op[1],
                    w: op[2],
                    h: op[3],
                    cx: op[0] + op[2] / 2,
                    cy: op[1] + op[3] / 2
                })
            }

            // 用匈牙利演算法求「已顯示項目」對「新需求」的全域最小總距離配對
            // （比貪婪最近優先更好：貪婪法可能因為搶先配對到局部最近而導致全局總移動量更大）
            const assignment = solveAssignment(shownItems, remainingOps)
            const usedSlots = new Set(Object.keys(assignment).map(k => parseInt(k)))
            const usedOps = new Set(Object.values(assignment).map(o => o.opIndex))

            // 未被配對到需求的「已顯示」項目 -> 淡出隱藏（保留在池中）
            for (const s of shownItems) {
                if (!usedSlots.has(s.index)) {
                    rectModel.setProperty(s.index, "shown", false)
                }
            }

            // 套用配對結果：移動既有已顯示視窗
            for (const key in assignment) {
                const idx = parseInt(key)
                const o = assignment[key]
                rectModel.setProperty(idx, "x", o.x)
                rectModel.setProperty(idx, "y", o.y)
                rectModel.setProperty(idx, "w", o.w)
                rectModel.setProperty(idx, "h", o.h)
                // 本來就是 shown = true，維持不變 -> 呈現「移動」動畫
            }

            // 尚未被滿足的新需求
            let leftoverOps = remainingOps.filter(o => !usedOps.has(o.opIndex))

            // 優先重用池中「隱藏」的舊視窗
            for (let i = 0; i < rectModel.count && leftoverOps.length > 0; i++) {
                const it = rectModel.get(i)
                if (!it.shown) {
                    const o = leftoverOps.shift()
                    // 此時 shown 仍為 false，x/y 的 Behavior 會被 enabled: shown 停用
                    // 因此座標會瞬間跳到新位置，不會有移動動畫
                    rectModel.setProperty(i, "x", o.x)
                    rectModel.setProperty(i, "y", o.y)
                    rectModel.setProperty(i, "w", o.w)
                    rectModel.setProperty(i, "h", o.h)
                    // shown 由 false -> true 是「屬性變化」，會觸發 opacity/scale 的淡入動畫
                    rectModel.setProperty(i, "shown", true)
                }
            }

            // 舊視窗（含隱藏池）仍不夠滿足需求，才建立新視窗
            for (const o of leftoverOps) {
                rectModel.append({
                    x: o.x,
                    y: o.y,
                    w: o.w,
                    h: o.h,
                    shown: false // 先以隱藏狀態建立，座標直接到位
                })
                const newIndex = rectModel.count - 1
                // 延後到下一個事件循環才設為 true，
                // 讓 shown 的變化被視為「屬性改變」而非初始值，才能觸發淡入動畫
                Qt.callLater(function () {
                    if (newIndex < rectModel.count)
                        rectModel.setProperty(newIndex, "shown", true)
                })
            }
        }

        Connections {
            target: Backend
            function onWindowChange(screenName, operations) {
                if (screenName !== panelWindow.screenName)
                    return
                panelWindow.updateRects(operations)
            }
        }

        Repeater {
            model: rectModel
            delegate: Rectangle {
                id: popup
                x: model.x
                y: model.y

                width: model.w
                height: model.h

                radius: 20

                color: Utils.Colors.semiTransparentBackground
                border.color: Utils.Colors.color5
                border.width: 2

                property bool shown: model.shown
                visible: shown || opacity > 0
                opacity: shown ? 1 : 0
                scale: shown ? 1.0 : 0.87

                transformOrigin: Item.Center

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }

                Behavior on x {
                    enabled: popup.shown
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                    }
                }

                Behavior on y {
                    enabled: popup.shown
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                    }
                }

                Behavior on width {
                    enabled: popup.shown
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                    }
                }

                Behavior on height {
                    enabled: popup.shown
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
                    }
                }
            }
        }
    }
}
