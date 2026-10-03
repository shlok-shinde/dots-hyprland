import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Hermes' to-do list for the task at hand, kept up to date as it works.
 */
Rectangle {
    id: root
    property var entry

    implicitHeight: columnLayout.implicitHeight + 8 * 2
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer1

    ColumnLayout {
        id: columnLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 8
            leftMargin: 10
        }
        spacing: 4

        RowLayout {
            spacing: 8
            MaterialSymbol {
                text: "checklist"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colSubtext
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: Translation.tr("Plan")
            }
        }

        Repeater {
            model: root.entry?.planEntries ?? []
            delegate: RowLayout {
                id: planRow
                required property var modelData
                readonly property string status: modelData.status ?? "pending"
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignTop
                    text: planRow.status === "completed" ? "check_circle" : planRow.status === "in_progress" ? "radio_button_partial" : "radio_button_unchecked"
                    iconSize: Appearance.font.pixelSize.normal
                    color: planRow.status === "in_progress" ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.strikeout: planRow.status === "completed"
                    color: planRow.status === "completed" ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                    text: planRow.modelData.content ?? ""
                }
            }
        }
    }
}
