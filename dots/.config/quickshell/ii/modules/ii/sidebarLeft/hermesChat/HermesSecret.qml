import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Hermes asking for something it shouldn't see in the chat: your sudo password
 * for a command, or a key a skill needs. Typed masked, sent straight to Hermes,
 * never shown in the transcript.
 */
Rectangle {
    id: root
    property var entry
    readonly property string answer: entry?.answer ?? ""
    readonly property bool answered: answer.length > 0

    implicitHeight: columnLayout.implicitHeight + 10 * 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: root.answered ? 0 : 1
    border.color: Appearance.colors.colPrimary

    function send() {
        Hermes.answerSecret(root.entry, secretField.text);
        secretField.text = "";
    }

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
                text: "key"
                iconSize: Appearance.font.pixelSize.larger
                color: root.answered ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: root.entry?.title ?? ""
            }
        }

        Rectangle { // the command it is for (sudo)
            Layout.fillWidth: true
            visible: (root.entry?.input ?? "").length > 0
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
                text: root.entry?.input ?? ""
            }
        }

        MaterialTextField {
            id: secretField
            Layout.fillWidth: true
            visible: !root.answered
            echoMode: TextInput.Password
            placeholderText: (root.entry?.envVar ?? "").length > 0 ? root.entry.envVar : Translation.tr("Password")
            onAccepted: root.send()
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.answered
            spacing: 5
            Item {
                Layout.fillWidth: true
            }
            DialogButton {
                buttonText: Translation.tr("Skip")
                colEnabled: Appearance.colors.colSubtext
                onClicked: {
                    secretField.text = "";
                    Hermes.answerSecret(root.entry, "");
                }
            }
            DialogButton {
                buttonText: Translation.tr("Send")
                enabled: secretField.text.length > 0
                onClicked: root.send()
            }
        }

        StyledText {
            visible: root.answered
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: root.answer === "given" ? Translation.tr("Sent") : root.answer === "skipped" ? Translation.tr("Skipped") : Translation.tr("No answer (Hermes stopped asking)")
        }
    }
}
