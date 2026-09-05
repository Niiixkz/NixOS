import QtQuick
import QtQuick.Shapes
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
        readonly property int screenIndex: Quickshell.screens.indexOf(modelData)
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        mask: Region { }
        WlrLayershell.layer: WlrLayer.Top

        Shape {
            id: frameShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            property real inset: 5
            property real cornerRadius: 20
            property real ix1: inset + cornerRadius
            property real ix2: width - inset - cornerRadius
            property real iy1: inset + cornerRadius
            property real iy2: height - inset - cornerRadius

            ShapePath {
                fillRule: ShapePath.OddEvenFill
                fillColor: Utils.Colors.semiTransparentBackground
                strokeColor: "transparent"

                startX: 0; startY: 0
                PathLine { x: frameShape.width; y: 0 }
                PathLine { x: frameShape.width; y: frameShape.height }
                PathLine { x: 0; y: frameShape.height }
                PathLine { x: 0; y: 0 }

                PathMove { x: frameShape.ix1; y: frameShape.inset }
                PathLine { x: frameShape.ix2; y: frameShape.inset }
                PathArc { x: frameShape.width - frameShape.inset; y: frameShape.iy1
                          radiusX: frameShape.cornerRadius; radiusY: frameShape.cornerRadius }
                PathLine { x: frameShape.width - frameShape.inset; y: frameShape.iy2 }
                PathArc { x: frameShape.ix2; y: frameShape.height - frameShape.inset
                          radiusX: frameShape.cornerRadius; radiusY: frameShape.cornerRadius }
                PathLine { x: frameShape.ix1; y: frameShape.height - frameShape.inset }
                PathArc { x: frameShape.inset; y: frameShape.iy2
                          radiusX: frameShape.cornerRadius; radiusY: frameShape.cornerRadius }
                PathLine { x: frameShape.inset; y: frameShape.iy1 }
                PathArc { x: frameShape.ix1; y: frameShape.inset
                          radiusX: frameShape.cornerRadius; radiusY: frameShape.cornerRadius }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Utils.Colors.color5
                strokeWidth: 2

                startX: frameShape.ix1; startY: frameShape.inset
                PathLine { x: frameShape.ix2; y: frameShape.inset }
                PathArc { x: frameShape.width - frameShape.inset; y: frameShape.iy1
                          radiusX: frameShape.cornerRadius; radiusY: frameShape.cornerRadius }
                PathLine { x: frameShape.width - frameShape.inset; y: frameShape.iy2 }
                PathArc { x: frameShape.ix2; y: frameShape.height - frameShape.inset
                          radiusX: frameShape.cornerRadius; radiusY: frameShape.cornerRadius }
                PathLine { x: frameShape.ix1; y: frameShape.height - frameShape.inset }
                PathArc { x: frameShape.inset; y: frameShape.iy2
                          radiusX: frameShape.cornerRadius; radiusY: frameShape.cornerRadius }
                PathLine { x: frameShape.inset; y: frameShape.iy1 }
                PathArc { x: frameShape.ix1; y: frameShape.inset
                          radiusX: frameShape.cornerRadius; radiusY: frameShape.cornerRadius }
                PathLine { x: frameShape.ix1; y: frameShape.inset }
            }
        }
    }
}

