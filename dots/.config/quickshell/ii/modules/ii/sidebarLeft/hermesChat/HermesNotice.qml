import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * A note from the sidebar or Hermes outside the conversation (a setting
 * changed, a command's one-line answer, an error): one quiet line.
 */
Item {
    id: root
    property var entry

    implicitHeight: rowLayout.implicitHeight + 4 * 2

    RowLayout {
        id: rowLayout
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 10
            rightMargin: 10
        }
        spacing: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignTop
            text: "info"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        TextEdit {
            Layout.fillWidth: true
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            renderType: Text.NativeRendering
            font.family: Appearance.font.family.reading
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            selectionColor: Appearance.colors.colSecondaryContainer
            selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
            text: root.entry?.text ?? ""
        }
    }
}
