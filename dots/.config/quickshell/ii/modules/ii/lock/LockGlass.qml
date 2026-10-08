import qs.modules.common
import qs.modules.common.widgets
import QtQuick

// The lock screen's glass for panes that carry text: it follows the mode,
// smoked in dark, milky in light. Shaped as a rounded rectangle (`radius`).
LiquidGlassEffect {
    id: root
    readonly property bool light: !Appearance.m3colors.darkmode
    property real radius: height / 2

    brightness: root.light ? 1.03 : 0.8
    adaptiveDim: root.light ? 0 : 0.8
    adaptiveBoost: root.light ? 0.85 : 0
    tint: root.light ? Qt.rgba(0.98, 0.98, 0.99, 0.45) : Qt.rgba(0.04, 0.04, 0.05, 0.25)
    shadow: root.light ? 0.2 : 0.28

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "white"
    }
}
