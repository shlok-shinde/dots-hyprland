import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

// One reading in a bar chip's panel: label, big number, its last few minutes as a line
Rectangle {
    id: root
    required property string icon
    required property string label
    required property real value // 0-1
    property string valueText: `${Math.round(root.value * 100)}%`
    property string detail: ""
    property list<real> history: []
    property bool warning: false

    readonly property color lineColor: root.warning ? Appearance.colors.colError : Appearance.hasAccent ? Appearance.accent : Appearance.colors.colPrimary

    implicitWidth: 150
    implicitHeight: column.implicitHeight + 24
    Layout.fillHeight: true // level with its row
    radius: Appearance.rounding.normal
    // A pane within the glass: a shade lighter in dark mode, darker in light
    color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, Appearance.m3colors.darkmode ? 0.93 : 0.95)
    clip: true

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 2

        RowLayout {
            spacing: 4
            MaterialSymbol {
                text: root.icon
                fill: 1
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
        }
        StyledText {
            text: root.valueText
            font.pixelSize: 30
            color: root.warning ? Appearance.colors.colError : Appearance.colors.colOnLayer0
        }
        Graph {
            Layout.fillWidth: true
            visible: root.history.length > 0
            Layout.topMargin: 4
            implicitHeight: 30
            values: root.history
            points: Math.max(2, root.history.length)
            color: root.lineColor
            fillOpacity: 0.18
            alignment: Graph.Alignment.Right
        }
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: root.detail.length > 0
            text: root.detail
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
        }
    }
}
