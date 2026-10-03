import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Hermes asking before it does something (a risky command, a file edit). It
 * waits for an answer; unanswered questions are denied after Hermes' own
 * timeout (approvals.timeout in its config).
 */
Rectangle {
    id: root
    property var entry
    readonly property string answer: entry?.answer ?? ""
    readonly property bool answered: answer.length > 0
    readonly property string answerName: {
        if (answer === "cancelled")
            return Translation.tr("No answer (the turn ended)");
        const option = (entry?.options ?? []).find(option => option.optionId === answer);
        return option ? option.name : answer;
    }

    implicitHeight: columnLayout.implicitHeight + 10 * 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: root.answered ? 0 : 1
    border.color: Appearance.colors.colPrimary

    ColumnLayout {
        id: columnLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 10
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: "shield_question"
                iconSize: Appearance.font.pixelSize.larger
                color: root.answered ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: Translation.tr("Hermes asks to go ahead")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: commandText.text.length > 0
            implicitHeight: commandText.implicitHeight + 8 * 2
            radius: Appearance.rounding.verysmall
            color: Appearance.colors.colLayer2
            StyledText {
                id: commandText
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 8
                }
                wrapMode: Text.Wrap
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer2
                text: (root.entry?.input ?? "").length > 0 ? root.entry.input : (root.entry?.title ?? "")
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: !root.answered
            spacing: 5
            Repeater {
                model: root.entry?.options ?? []
                delegate: DialogButton {
                    required property var modelData
                    buttonText: modelData.name
                    colEnabled: modelData.kind.startsWith("reject") ? Appearance.m3colors.m3error : Appearance.colors.colPrimary
                    onClicked: Hermes.answerPermission(root.entry, modelData.optionId)
                }
            }
        }

        StyledText {
            visible: root.answered
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: root.answerName
        }
    }
}
