import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// The top line of a bar chip's panel: what it is, and a quiet detail on the right
RowLayout {
    id: root
    required property string icon
    required property string title
    property string detail: ""
    spacing: 8

    MaterialSymbol {
        text: root.icon
        fill: 1
        iconSize: Appearance.font.pixelSize.larger
        color: Appearance.hasAccent ? Appearance.accent : Appearance.colors.colOnLayer0
    }
    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: Appearance.font.pixelSize.large
        color: Appearance.colors.colOnLayer0
        elide: Text.ElideRight
    }
    StyledText {
        visible: root.detail.length > 0
        text: root.detail
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }
}
