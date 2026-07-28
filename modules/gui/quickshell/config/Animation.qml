
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property var colorAnimation: ColorAnimation {
        duration: 250
        easing.type: Easing.InOutQuad
    }
}

