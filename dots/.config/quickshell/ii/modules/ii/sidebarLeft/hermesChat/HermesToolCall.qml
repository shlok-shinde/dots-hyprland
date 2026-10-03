import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * A tool call Hermes made: what it did and how it went. Click for the details
 * (the command or arguments, and the result).
 */
Rectangle {
    id: root
    property var entry
    property bool expanded: false

    readonly property string status: entry?.status ?? ""
    readonly property bool running: (status === "pending" || status === "in_progress") && !(entry?.done ?? true)
    readonly property bool failed: status === "failed"
    readonly property string details: [entry?.input ?? "", entry?.output ?? ""].filter(text => text.length > 0).join("\n\n")

    implicitHeight: columnLayout.implicitHeight + 6 * 2
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer1

    function kindIcon(kind) {
        switch (kind) {
        case "execute":
            return "terminal";
        case "read":
            return "description";
        case "edit":
            return "edit_note";
        case "delete":
            return "delete";
        case "move":
            return "drive_file_move";
        case "search":
            return "search";
        case "fetch":
            return "travel_explore";
        case "think":
            return "psychology";
        default:
            return "build";
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 6
            leftMargin: 10
            rightMargin: 8
        }
        spacing: 6

        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: root.kindIcon(root.entry?.toolKind ?? "")
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                text: (root.entry?.title ?? "").length > 0 ? root.entry.title : (root.entry?.input ?? "")
            }
            Item {
                implicitWidth: Appearance.font.pixelSize.larger
                implicitHeight: Appearance.font.pixelSize.larger
                MaterialSymbol { // working
                    anchors.centerIn: parent
                    visible: root.running
                    text: "progress_activity"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colSubtext
                    RotationAnimation on rotation {
                        running: root.running
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }
                MaterialSymbol { // done
                    anchors.centerIn: parent
                    visible: !root.running
                    text: root.failed ? "error" : "check_circle"
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.failed ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                }
            }
            MaterialSymbol {
                visible: root.details.length > 0
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colSubtext
            }
        }

        Loader { // Details
            Layout.fillWidth: true
            active: root.expanded && root.details.length > 0
            visible: active
            sourceComponent: Rectangle {
                implicitHeight: Math.min(detailsText.implicitHeight + 8 * 2, 280)
                radius: Appearance.rounding.verysmall
                color: Appearance.colors.colLayer2

                Flickable {
                    id: detailsFlickable
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    contentHeight: detailsText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: StyledScrollBar {}

                    TextEdit {
                        id: detailsText
                        width: detailsFlickable.width
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.MarkdownText
                        renderType: Text.NativeRendering
                        font.family: Appearance.font.family.reading
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                        selectionColor: Appearance.colors.colSecondaryContainer
                        selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                        text: root.details
                    }
                }
            }
        }
    }

    MouseArea {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: headerRow.height + 6 * 2
        enabled: root.details.length > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.expanded = !root.expanded
    }
}
