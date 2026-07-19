import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Variants {
    model: Quickshell.screens
    id: root
    
    property var instanceMap: ({})
    
    // 引用TopBar來控制顯示/隱藏
    property var topBar: null
    
    /**
     * Call setCorners function for a specific screen
     * @param screenIndex - Index of the target screen
     * @param operations - Array of corner operations [[corner, width, height, offset], ...]
     */
    function setCorners(screenIndex, operations) {
        if (!instanceMap[screenIndex])
            return
        instanceMap[screenIndex].setCornersInternal(operations)
    }
    
    PanelWindow {
        id: panelWindow
        property var modelData
        screen: modelData
        
        readonly property int screenIndex: Quickshell.screens.indexOf(modelData)
        
        Component.onCompleted: {
            root.instanceMap[screenIndex] = panelWindow
        }
        
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        
        color: "transparent"
        mask: Region { }
        WlrLayershell.layer: WlrLayer.Top
        
        // Border widths: [top, right, bottom, left]
        // property var edges: [30, 5, 5, 5]
        property var edges: [5, 5, 5, 5]
        
        // Corner dimensions: [[topLeft], [top], [topRight], [right], [bottomRight], [bottom], [bottomLeft], [left]]
        // Even indices (0,2,4,6): [width, height]
        // Odd indices (1,3,5,7): [width, height, offset]
        property var corners: [[0, 0], [0, 0, 0], [0, 0], [0, 0, 0], 
                               [0, 0], [0, 0, 0], [0, 0], [0, 0, 0]]
        
        // Default border values for restoration
        // readonly property var initialEdges: [30, 5, 5, 5]
        readonly property var initialEdges: [5, 5, 5, 5]
        
        // Animation state variables
        property var animStartCorners: [[0, 0], [0, 0, 0], [0, 0], [0, 0, 0], 
                                        [0, 0], [0, 0, 0], [0, 0], [0, 0, 0]]
        property var animTargetCorners: [[0, 0], [0, 0, 0], [0, 0], [0, 0, 0], 
                                         [0, 0], [0, 0, 0], [0, 0], [0, 0, 0]]
        // property var animStartEdges: [30, 5, 5, 5]
        property var animStartEdges: [5, 5, 5, 5]
        property var animTargetEdges: [0, 0, 0, 0]
        
        // Animation progress (0.0 to 1.0)
        property real animProgress: 0.0
        
        // 追蹤當前邊框是否縮回螢幕外
        property bool borderIsHidden: false
        
        // Trigger repaint when properties change
        onEdgesChanged: canvas.requestPaint()
        onCornersChanged: canvas.requestPaint()
        
        /**
         * Interpolate between start and target values based on animation progress
         */
        onAnimProgressChanged: {
            corners = interpolateCorners(animStartCorners, animTargetCorners, animProgress)
            edges = interpolateEdges(animStartEdges, animTargetEdges, animProgress)
            
            // 檢查邊框是否完全隱藏（所有邊都是負值）
            var allNegative = edges.every(function(e) { return e < 0 })
            
            // 當動畫完成時才通知
            if (animProgress >= 1.0 && allNegative !== borderIsHidden) {
                borderIsHidden = allNegative
                notifyTopBar(borderIsHidden)
            }
        }
        
        /**
         * 通知TopBar顯示或隱藏
         */
        function notifyTopBar(hide) {
            if (root.topBar) {
                root.topBar.setVisibility(screenIndex, !hide)
            }
        }
        
        /**
         * Helper function to interpolate corner values
         */
        function interpolateCorners(start, target, progress) {
            var result = []
            for (var i = 0; i < 8; i++) {
                var w = start[i][0] + (target[i][0] - start[i][0]) * progress
                var h = start[i][1] + (target[i][1] - start[i][1]) * progress
                
                if (i % 2 === 1) {
                    // Odd indices also interpolate offset
                    var o = start[i][2] + (target[i][2] - start[i][2]) * progress
                    result.push([w, h, o])
                } else {
                    result.push([w, h])
                }
            }
            return result
        }
        
        /**
         * Helper function to interpolate edge values
         */
        function interpolateEdges(start, target, progress) {
            var result = []
            for (var i = 0; i < 4; i++) {
                result.push(start[i] + (target[i] - start[i]) * progress)
            }
            return result
        }
        
        /**
         * Two-stage animation sequence for showing/hiding corners
         * Stage 1: Exit off-screen
         * Stage 2: Enter with new values
         */
        SequentialAnimation {
            id: borderSequentialAnimation
            
            property var targetCorners: [[0, 0], [0, 0, 0], [0, 0], [0, 0, 0], 
                                         [0, 0], [0, 0, 0], [0, 0], [0, 0, 0]]
            
            // Stage 1: Exit animation
            ScriptAction {
                script: {
                    // 立即通知TopBar隱藏
                    panelWindow.notifyTopBar(true)
                    
                    panelWindow.animStartCorners = panelWindow.corners.map(c => c.slice())
                    panelWindow.animStartEdges = panelWindow.edges.slice()
                    
                    // Create exit corners (preserve offset values)
                    var exitCorners = panelWindow.corners.map(function(c, i) {
                        return i % 2 === 1 ? [-50, -50, c[2]] : [-50, -50]
                    })
                    
                    panelWindow.animTargetCorners = exitCorners
                    panelWindow.animTargetEdges = [-50, -50, -50, -50]
                    panelWindow.animProgress = 0.0
                }
            }
            NumberAnimation {
                target: panelWindow
                property: "animProgress"
                to: 1.0
                duration: 250
                easing.type: Easing.InCubic
            }
            
            // Stage 2: Enter animation
            ScriptAction {
                script: {
                    // Start from off-screen with target offsets
                    var startCorners = borderSequentialAnimation.targetCorners.map(function(c, i) {
                        return i % 2 === 1 ? [-50, -50, c[2]] : [-50, -50]
                    })
                    
                    panelWindow.animStartCorners = startCorners
                    panelWindow.animStartEdges = [-50, -50, -50, -50]
                    panelWindow.animTargetCorners = borderSequentialAnimation.targetCorners.map(c => c.slice())
                    panelWindow.animTargetEdges = panelWindow.initialEdges.slice()
                    panelWindow.animProgress = 0.0
                }
            }
            NumberAnimation {
                target: panelWindow
                property: "animProgress"
                to: 1.0
                duration: 250
                easing.type: Easing.OutCubic
                onFinished: {
                    // 動畫結束後通知TopBar顯示
                    panelWindow.notifyTopBar(false)
                }
            }
        }

        /**
         * Direct corner size adjustment animation (without exit/enter)
         */
        SequentialAnimation {
            id: directCornerAnimation
            
            property var targetCorners: [[0, 0], [0, 0, 0], [0, 0], [0, 0, 0], 
                                         [0, 0], [0, 0, 0], [0, 0], [0, 0, 0]]
            
            ScriptAction {
                script: {
                    panelWindow.animStartCorners = panelWindow.corners.map(c => c.slice())
                    panelWindow.animStartEdges = panelWindow.edges.slice()
                    panelWindow.animTargetCorners = directCornerAnimation.targetCorners.map(c => c.slice())
                    panelWindow.animTargetEdges = panelWindow.edges.slice()
                    panelWindow.animProgress = 0.0
                }
            }
            NumberAnimation {
                target: panelWindow
                property: "animProgress"
                to: 1.0
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        
        Canvas {
            id: canvas
            anchors.fill: parent
            
            onPaint: {
                var ctx = getContext("2d")
                var radius = 20
                
                ctx.clearRect(0, 0, width, height)
                
                // Fill entire canvas with semi-transparent background
                ctx.fillStyle = Colors.semiTransparentBackground
                ctx.fillRect(0, 0, width, height)
                
                // Extract border values
                var edge = {
                    top: panelWindow.edges[0],
                    right: panelWindow.edges[1],
                    bottom: panelWindow.edges[2],
                    left: panelWindow.edges[3]
                }
                
                // Extract corner values with helper function
                var corner = extractCornerValues(panelWindow.corners)
                
                // Cut out inner area with rounded corners
                ctx.fillStyle = Qt.rgba(0, 0, 0, 1)
                ctx.globalCompositeOperation = "destination-out"
                ctx.beginPath()
                
                // Start point: top-left
                ctx.moveTo(edge.left + radius, edge.top + corner.topLeft.h)

                // Draw path with corners and panels
                drawTopLeftCorner(ctx, edge, corner, radius)
                drawTopPanel(ctx, edge, corner, radius, width)
                drawTopRightCorner(ctx, edge, corner, radius, width)
                drawRightPanel(ctx, edge, corner, radius, width, height)
                drawBottomRightCorner(ctx, edge, corner, radius, width, height)
                drawBottomPanel(ctx, edge, corner, radius, width, height)
                drawBottomLeftCorner(ctx, edge, corner, radius, height)
                drawLeftPanel(ctx, edge, corner, radius, height)
                
                // Close path at top-left
                ctx.arcTo(
                    edge.left,
                    edge.top + corner.topLeft.h,
                    edge.left + radius,
                    edge.top + corner.topLeft.h,
                    radius
                )
                
                ctx.closePath()
                ctx.fill()
                
                // Draw border stroke
                ctx.globalCompositeOperation = "source-over"
                ctx.strokeStyle = Colors.color5
                ctx.lineWidth = 2
                ctx.stroke()
            }
            
            /**
             * Extract corner values into a structured object
             */
            function extractCornerValues(corners) {
                return {
                    topLeft: { w: corners[0][0], h: corners[0][1] },
                    top: { w: corners[1][0], h: corners[1][1], o: corners[1][2] },
                    topRight: { w: corners[2][0], h: corners[2][1] },
                    right: { w: corners[3][0], h: corners[3][1], o: corners[3][2] },
                    bottomRight: { w: corners[4][0], h: corners[4][1] },
                    bottom: { w: corners[5][0], h: corners[5][1], o: corners[5][2] },
                    bottomLeft: { w: corners[6][0], h: corners[6][1] },
                    left: { w: corners[7][0], h: corners[7][1], o: corners[7][2] }
                }
            }
            
            /**
             * Drawing functions for each corner and panel
             */
            function drawTopLeftCorner(ctx, edge, corner, radius) {
                if (corner.topLeft.w > 0 && corner.topLeft.h > 0) {
                    ctx.arcTo(
                        edge.left + corner.topLeft.w,
                        edge.top + corner.topLeft.h,
                        edge.left + corner.topLeft.w,
                        edge.top + corner.topLeft.h - radius,
                        radius
                    )
                    ctx.arcTo(
                        edge.left + corner.topLeft.w,
                        edge.top,
                        edge.left + corner.topLeft.w + radius,
                        edge.top,
                        radius
                    )
                }
            }
            
            function drawTopPanel(ctx, edge, corner, radius, width) {
                if (corner.top.w > 0 && corner.top.h > 0) {
                    var centerX = width / 2
                    var left = centerX - corner.top.w / 2 + corner.top.o
                    var right = centerX + corner.top.w / 2 + corner.top.o
                    
                    ctx.arcTo(left, edge.top, left, edge.top + radius, radius)
                    ctx.arcTo(left, edge.top + corner.top.h, left + radius, edge.top + corner.top.h, radius)
                    ctx.arcTo(right, edge.top + corner.top.h, right, edge.top + corner.top.h - radius, radius)
                    ctx.arcTo(right, edge.top, right + radius, edge.top, radius)
                }
            }
            
            function drawTopRightCorner(ctx, edge, corner, radius, width) {
                if (corner.topRight.w > 0 && corner.topRight.h > 0) {
                    ctx.arcTo(
                        width - edge.right - corner.topRight.w,
                        edge.top,
                        width - edge.right - corner.topRight.w,
                        edge.top + radius,
                        radius
                    )
                    ctx.arcTo(
                        width - edge.right - corner.topRight.w,
                        edge.top + corner.topRight.h,
                        width - edge.right - corner.topRight.w + radius,
                        edge.top + corner.topRight.h,
                        radius
                    )
                }
                
                ctx.arcTo(
                    width - edge.right,
                    edge.top + corner.topRight.h,
                    width - edge.right,
                    edge.top + corner.topRight.h + radius,
                    radius
                )
            }
            
            function drawRightPanel(ctx, edge, corner, radius, width, height) {
                if (corner.right.w > 0 && corner.right.h > 0) {
                    var centerY = height / 2
                    var top = centerY - corner.right.h / 2 + corner.right.o
                    var bottom = centerY + corner.right.h / 2 + corner.right.o
                    
                    ctx.arcTo(width - edge.right, top, width - edge.right - radius, top, radius)
                    ctx.arcTo(width - edge.right - corner.right.w, top, width - edge.right - corner.right.w, top + radius, radius)
                    ctx.arcTo(width - edge.right - corner.right.w, bottom, width - edge.right - corner.right.w + radius, bottom, radius)
                    ctx.arcTo(width - edge.right, bottom, width - edge.right, bottom + radius, radius)
                }
            }
            
            function drawBottomRightCorner(ctx, edge, corner, radius, width, height) {
                if (corner.bottomRight.w > 0 && corner.bottomRight.h > 0) {
                    ctx.arcTo(
                        width - edge.right,
                        height - edge.bottom - corner.bottomRight.h,
                        width - edge.right - radius,
                        height - edge.bottom - corner.bottomRight.h,
                        radius
                    )
                    ctx.arcTo(
                        width - edge.right - corner.bottomRight.w,
                        height - edge.bottom - corner.bottomRight.h,
                        width - edge.right - corner.bottomRight.w,
                        height - edge.bottom - corner.bottomRight.h + radius,
                        radius
                    )
                }
                
                ctx.arcTo(
                    width - edge.right - corner.bottomRight.w,
                    height - edge.bottom,
                    width - edge.right - corner.bottomRight.w - radius,
                    height - edge.bottom,
                    radius
                )
            }
            
            function drawBottomPanel(ctx, edge, corner, radius, width, height) {
                if (corner.bottom.w > 0 && corner.bottom.h > 0) {
                    var centerX = width / 2
                    var right = centerX + corner.bottom.w / 2 - corner.bottom.o
                    var left = centerX - corner.bottom.w / 2 - corner.bottom.o
                    
                    ctx.arcTo(right, height - edge.bottom, right, height - edge.bottom - radius, radius)
                    ctx.arcTo(right, height - edge.bottom - corner.bottom.h, right - radius, height - edge.bottom - corner.bottom.h, radius)
                    ctx.arcTo(left, height - edge.bottom - corner.bottom.h, left, height - edge.bottom - corner.bottom.h + radius, radius)
                    ctx.arcTo(left, height - edge.bottom, left - radius, height - edge.bottom, radius)
                }
            }
            
            function drawBottomLeftCorner(ctx, edge, corner, radius, height) {
                if (corner.bottomLeft.w > 0 && corner.bottomLeft.h > 0) {
                    ctx.arcTo(
                        edge.left + corner.bottomLeft.w,
                        height - edge.bottom,
                        edge.left + corner.bottomLeft.w,
                        height - edge.bottom - radius,
                        radius
                    )
                    ctx.arcTo(
                        edge.left + corner.bottomLeft.w,
                        height - edge.bottom - corner.bottomLeft.h,
                        edge.left + corner.bottomLeft.w - radius,
                        height - edge.bottom - corner.bottomLeft.h,
                        radius
                    )
                }
                
                ctx.arcTo(
                    edge.left,
                    height - edge.bottom - corner.bottomLeft.h,
                    edge.left,
                    height - edge.bottom - corner.bottomLeft.h - radius,
                    radius
                )
            }
            
            function drawLeftPanel(ctx, edge, corner, radius, height) {
                if (corner.left.w > 0 && corner.left.h > 0) {
                    var centerY = height / 2
                    var bottom = centerY + corner.left.h / 2 - corner.left.o
                    var top = centerY - corner.left.h / 2 - corner.left.o
                    
                    ctx.arcTo(edge.left, bottom, edge.left + radius, bottom, radius)
                    ctx.arcTo(edge.left + corner.left.w, bottom, edge.left + corner.left.w, bottom - radius, radius)
                    ctx.arcTo(edge.left + corner.left.w, top, edge.left + corner.left.w - radius, top, radius)
                    ctx.arcTo(edge.left, top, edge.left, top - radius, radius)
                }
            }
        }
        
        Connections {
            target: Colors
            function onColorsChanged() {
                canvas.requestPaint()
            }
        }
        
        /**
         * Set multiple corner values with animation
         * @param operations - Array of operations: [[corner, width, height, offset], ...]
         *                     corner indices: 0=topLeft, 1=top, 2=topRight, 3=right,
         *                                     4=bottomRight, 5=bottom, 6=bottomLeft, 7=left
         */
        function setCornersInternal(operations) {
            var needsExitAnimation = checkIfExitAnimationNeeded(operations)
            var newCorners = applyOperationsToCorners(panelWindow.corners, operations)
            
            if (needsExitAnimation) {
                borderSequentialAnimation.targetCorners = newCorners
                borderSequentialAnimation.start()
            } else {
                directCornerAnimation.targetCorners = newCorners
                directCornerAnimation.start()
            }
        }
        
        /**
         * Check if any operation requires exit animation (show/hide transition)
         */
        function checkIfExitAnimationNeeded(operations) {
            for (var i = 0; i < operations.length; i++) {
                var op = operations[i]
                var corner = op[0]
                var targetWidth = op[1]
                var targetHeight = op[2]
                
                var current = panelWindow.corners[corner]
                var currentIsZero = (current[0] === 0 && current[1] === 0)
                var targetIsZero = (targetWidth === 0 && targetHeight === 0)
                
                // Exit animation needed only when toggling visibility
                if (currentIsZero !== targetIsZero) {
                    return true
                }
            }
            return false
        }
        
        /**
         * Apply operations to corner array
         */
        function applyOperationsToCorners(corners, operations) {
            var newCorners = corners.map(c => c.slice())
            
            for (var i = 0; i < operations.length; i++) {
                var op = operations[i]
                var cornerIndex = op[0]
                
                if (cornerIndex % 2 === 1) {
                    // Odd index: includes offset
                    newCorners[cornerIndex] = [op[1], op[2], op[3]]
                } else {
                    // Even index: no offset
                    newCorners[cornerIndex] = [op[1], op[2]]
                }
            }
            
            return newCorners
        }
    }
}
