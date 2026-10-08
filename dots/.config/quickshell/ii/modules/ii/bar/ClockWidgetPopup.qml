import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.ii.sidebarRight.calendar
import QtQuick
import QtQuick.Layouts

BarPopover {
    id: root
    name: "clock"

    // Unfinished to-dos, with their place in Todo.list (to tick them off)
    readonly property var pending: Todo.list.map((item, index) => ({ item, index })).filter(t => !t.item.done)

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        RowLayout { // Now
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 12
            StyledText {
                text: DateTime.time
                font.pixelSize: 40
                color: Appearance.colors.colOnLayer0
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: Qt.locale().toString(DateTime.clock.date, "dddd")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.hasAccent ? Appearance.accent : Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Qt.locale().toString(DateTime.clock.date, "d MMMM yyyy")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        CalendarWidget {
            Layout.alignment: Qt.AlignHCenter
        }

        // To do
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            PopoverHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                icon: "checklist"
                title: Translation.tr("To do")
                detail: root.pending.length > 4 ? Translation.tr("%1 more").arg(root.pending.length - 4) : ""
            }
            StyledText {
                Layout.leftMargin: 4
                visible: root.pending.length === 0
                text: Translation.tr("Nothing pending")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
            Repeater {
                model: root.pending.slice(0, 4)
                delegate: RippleButton {
                    id: task
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.92)
                    onClicked: Todo.markDone(task.modelData.index)

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 8
                        MaterialSymbol { // tick it off
                            text: task.hovered ? "check_circle" : "radio_button_unchecked"
                            iconSize: Appearance.font.pixelSize.larger
                            color: task.hovered && Appearance.hasAccent ? Appearance.accent : Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: task.modelData.item.content
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
