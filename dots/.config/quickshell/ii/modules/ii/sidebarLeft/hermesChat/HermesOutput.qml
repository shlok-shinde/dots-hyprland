import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/**
 * What a /command printed: monospace and unwrapped, so Hermes' tables stay
 * aligned (scroll sideways for wide ones). Long output folds; click to unfold.
 */
Rectangle {
    id: root
    property var entry
    property bool expanded: false
    readonly property int lineCount: (entry?.text ?? "").split("\n").length
    readonly property int foldedLines: 14
    readonly property bool foldable: lineCount > foldedLines + 2
    // Tables and boxes keep their lines (scroll sideways); prose wraps
    readonly property bool preformatted: /[─│┌┐└┘├┤┬┴┼═║╔╗╚╝╭╮╰╯]|[-=+]{4,}|\S {3,}\S/.test(entry?.text ?? "")

    implicitHeight: columnLayout.implicitHeight + 6 * 2
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer1

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
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: "terminal"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                text: root.entry?.label ?? ""
            }
            RippleButton {
                id: copyButton
                property bool copied: false
                implicitWidth: 26
                implicitHeight: 26
                buttonRadius: Appearance.rounding.full
                onClicked: {
                    Quickshell.clipboardText = root.entry?.text ?? "";
                    copied = true;
                    copiedTimer.restart();
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: copyButton.copied ? "inventory" : "content_copy"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
                Timer {
                    id: copiedTimer
                    interval: 1500
                    onTriggered: copyButton.copied = false
                }
                StyledToolTip {
                    text: Translation.tr("Copy")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.min(outputText.implicitHeight, root.foldable && !root.expanded ? outputText.lineHeightPx * root.foldedLines : outputText.implicitHeight) + 8 * 2 + (outputFlickable.contentWidth > outputFlickable.width ? 8 : 0)
            radius: Appearance.rounding.verysmall
            color: Appearance.colors.colLayer2
            clip: true

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            Flickable {
                id: outputFlickable
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                contentWidth: root.preformatted ? outputText.implicitWidth : width
                contentHeight: outputText.implicitHeight
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width
                ScrollBar.horizontal: ScrollBar { // StyledScrollBar is vertical-only
                    id: horizontalBar
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitHeight: 4
                        radius: 2
                        color: Appearance.colors.colOnSurfaceVariant
                        opacity: horizontalBar.size < 1.0 ? 0.5 : 0
                    }
                }

                TextEdit {
                    id: outputText
                    readonly property real lineHeightPx: lineCount > 0 ? contentHeight / lineCount : font.pixelSize * 1.3
                    readOnly: true
                    selectByMouse: true
                    width: root.preformatted ? implicitWidth : outputFlickable.width
                    wrapMode: root.preformatted ? TextEdit.NoWrap : TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    renderType: Text.NativeRendering
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                    selectionColor: Appearance.colors.colSecondaryContainer
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    text: (root.entry?.text ?? "").replace(/^\n+|\s+$/g, "")
                }
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.foldable
            implicitHeight: 26
            implicitWidth: foldText.implicitWidth + 12 * 2
            buttonRadius: Appearance.rounding.full
            onClicked: root.expanded = !root.expanded
            contentItem: StyledText {
                id: foldText
                anchors.centerIn: parent
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: root.expanded ? Translation.tr("Show less") : Translation.tr("Show all %1 lines").arg(root.lineCount)
            }
        }
    }
}
