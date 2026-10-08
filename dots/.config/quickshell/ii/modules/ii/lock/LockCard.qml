import qs.modules.common
import QtQuick
import QtQuick.Layouts

/**
 * A pane on the lock screen: glass over the lock's own backdrop (the
 * compositor's glass can't reach a lock surface), or a plain pane without
 * glass. Its content stacks in a column; give the card a width.
 */
Item {
    id: root
    required property Item backdrop
    property bool liquid: Appearance.liquidGlass
    property real radius: Appearance.rounding.large
    property real padding: 14
    property real mapTick: 0 // bump while the card moves, so the glass follows
    default property alias content: column.data

    implicitHeight: column.implicitHeight + root.padding * 2

    LockGlass {
        anchors.fill: parent
        visible: root.liquid
        backdrop: root.backdrop
        radius: root.radius
        mapTick: root.mapTick
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.liquid
        radius: root.radius
        color: Appearance.m3colors.m3surfaceContainer
    }

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.padding
        }
        spacing: 6
    }
}
