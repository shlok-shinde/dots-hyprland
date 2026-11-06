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
    // The rim follows Settings > Liquid glass, like the compositor's glass
    highlightDirection: ({ "none": 0, "top": 1, "diagonal": 2 })[Config.options.appearance.liquidGlass.highlights] ?? 1
    darkEdge: Config.options.appearance.liquidGlass.darkEdge ? (root.light ? 0.43 : 0.88) : 0
    nearReflection: Config.options.appearance.liquidGlass.nearReflection ? 0.5 : 0

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "white"
    }
}
