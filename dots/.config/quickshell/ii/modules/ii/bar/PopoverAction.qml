import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

// A quiet full-width button at the foot of a bar chip's panel
RippleButton {
    id: root
    property string symbol: ""
    implicitHeight: 36
    buttonRadius: Appearance.rounding.full
    colBackground: ColorUtils.transparentize(Appearance.colors.colOnLayer0, Appearance.m3colors.darkmode ? 0.93 : 0.95)
    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnLayer0, Appearance.m3colors.darkmode ? 0.86 : 0.9)
    colRipple: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.8)

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                visible: root.symbol.length > 0
                text: root.symbol
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                text: root.text
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer0
            }
        }
    }
}
