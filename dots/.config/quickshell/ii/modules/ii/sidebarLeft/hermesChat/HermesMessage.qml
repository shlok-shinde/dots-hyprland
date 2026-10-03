import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarLeft.aiChat
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/**
 * A message in the Hermes chat: yours, Hermes' reply (reasoning folded into a
 * think block), or a note from the sidebar. Replies that continue a turn after
 * a tool call go without a header.
 */
Rectangle {
    id: root
    property var entry
    property bool showHeader: true
    property bool renderMarkdown: true
    property real messagePadding: 7

    readonly property bool isUser: entry?.kind === "user"
    readonly property bool isNotice: entry?.kind === "notice"
    property list<var> messageBlocks: StringUtils.splitMarkdownBlocks(root.entry?.content ?? "")

    implicitHeight: columnLayout.implicitHeight + root.messagePadding * 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    ColumnLayout {
        id: columnLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.messagePadding
        }
        spacing: 3

        Rectangle { // Header
            visible: root.showHeader
            Layout.fillWidth: true
            implicitHeight: Math.max(headerRowLayout.implicitHeight, 30) + 4 * 2
            color: Appearance.colors.colSecondaryContainer
            radius: Appearance.rounding.small

            RowLayout {
                id: headerRowLayout
                anchors {
                    fill: parent
                    margins: 4
                    leftMargin: 14
                }
                spacing: 12

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.m3colors.m3onSecondaryContainer
                    text: root.isUser ? "person" : root.isNotice ? "settings" : "neurology"
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                    text: root.isUser ? (SystemInfo.username || Translation.tr("You")) : root.isNotice ? Translation.tr("Interface") : "Hermes"
                }
                StyledText {
                    visible: root.entry?.queued ?? false
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: Translation.tr("Queued")
                }

                ButtonGroup {
                    spacing: 5

                    AiMessageControlButton {
                        id: copyButton
                        buttonIcon: activated ? "inventory" : "content_copy"
                        onClicked: {
                            Quickshell.clipboardText = root.entry?.text ?? "";
                            copyButton.activated = true;
                            copyIconTimer.restart();
                        }
                        Timer {
                            id: copyIconTimer
                            interval: 1500
                            onTriggered: copyButton.activated = false
                        }
                        StyledToolTip {
                            text: Translation.tr("Copy")
                        }
                    }
                    AiMessageControlButton {
                        activated: !root.renderMarkdown
                        buttonIcon: "code"
                        onClicked: root.renderMarkdown = !root.renderMarkdown
                        StyledToolTip {
                            text: Translation.tr("View Markdown source")
                        }
                    }
                }
            }
        }

        ColumnLayout { // Content
            spacing: 0
            Layout.fillWidth: true

            Item { // Waiting for the first words
                Layout.fillWidth: true
                implicitHeight: loadingIndicatorLoader.shown ? loadingIndicatorLoader.implicitHeight : 0
                implicitWidth: loadingIndicatorLoader.implicitWidth
                visible: implicitHeight > 0
                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                FadeLoader {
                    id: loadingIndicatorLoader
                    anchors.centerIn: parent
                    shown: root.messageBlocks.length < 1 && !(root.entry?.done ?? true)
                    sourceComponent: MaterialLoadingIndicator {
                        loading: true
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: root.messageBlocks
                }
                delegate: DelegateChooser {
                    role: "type"

                    DelegateChoice {
                        roleValue: "code"
                        MessageCodeBlock {
                            renderMarkdown: root.renderMarkdown
                            segmentContent: modelData.content
                            segmentLang: modelData.lang
                            messageData: root.entry
                        }
                    }
                    DelegateChoice {
                        roleValue: "think"
                        MessageThinkBlock {
                            renderMarkdown: root.renderMarkdown
                            segmentContent: modelData.content
                            messageData: root.entry
                            done: root.entry?.done ?? false
                            completed: modelData.completed ?? false
                        }
                    }
                    DelegateChoice {
                        roleValue: "text"
                        MessageTextBlock {
                            renderMarkdown: root.renderMarkdown
                            enableMouseSelection: true
                            segmentContent: modelData.content
                            messageData: root.entry
                            done: root.entry?.done ?? false
                            forceDisableChunkSplitting: root.entry?.content.includes("```") ?? true
                        }
                    }
                }
            }
        }
    }
}
