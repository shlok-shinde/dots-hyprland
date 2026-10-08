pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * What's playing, with its controls: cover, title and artist, a seek line and
 * previous / play-pause / next. No background of its own: it sits on glass
 * (a bar chip's panel, the lock screen). Size it by width. `compact` puts
 * the controls beside the title and the times beside the seek line.
 */
ColumnLayout {
    id: root
    property MprisPlayer player: MprisController.activePlayer
    property color colText: Appearance.colors.colOnLayer0
    property color colSubtext: Appearance.colors.colSubtext
    property color colAccent: Appearance.hasAccent ? Appearance.accent : Appearance.colors.colPrimary
    property color colOnAccent: Appearance.hasAccent ? "white" : Appearance.colors.colOnPrimary
    property real artSize: 64
    property bool compact: false

    spacing: 10

    readonly property real progress: (root.player?.length ?? 0) > 0 ? Math.min(1, root.player.position / root.player.length) : 0

    Timer { // the position is only reported on change of state: ask while playing
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Cover art: local files as they are; web ones through the cache the media
    // controls use (Directories.coverArt, by the URL's md5)
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property bool artIsRemote: root.artUrl.startsWith("http")
    readonly property string artCachePath: `${Directories.coverArt}/${Qt.md5(root.artUrl)}`
    property bool artCached: false
    readonly property string artSource: !root.artIsRemote ? root.artUrl : root.artCached ? Qt.resolvedUrl(root.artCachePath) : ""
    onArtUrlChanged: {
        root.artCached = false;
        if (!root.artIsRemote)
            return;
        artDownloader.target = root.artUrl;
        artDownloader.path = root.artCachePath;
        artDownloader.running = true;
    }
    Component.onCompleted: root.artUrlChanged()
    Process {
        id: artDownloader
        property string target
        property string path
        command: ["bash", "-c", `mkdir -p "$(dirname "$2")"; [ -f "$2" ] || curl -4 -sSL "$1" -o "$2"`, "_", target, path]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && path === root.artCachePath)
                root.artCached = true;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle { // Cover
            id: artFrame
            implicitWidth: root.artSize
            implicitHeight: root.artSize
            radius: Appearance.rounding.small
            color: ColorUtils.transparentize(root.colText, 0.88)

            MaterialSymbol {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "music_note"
                iconSize: root.artSize * 0.45
                color: root.colSubtext
            }
            Image {
                id: art
                anchors.fill: parent
                source: root.artSource
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
                asynchronous: true
                cache: false
                visible: false
            }
            OpacityMask {
                anchors.fill: parent
                visible: art.status === Image.Ready
                source: art
                maskSource: Rectangle {
                    width: artFrame.width
                    height: artFrame.height
                    radius: artFrame.radius
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || Translation.tr("Nothing playing")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: root.colText
                elide: Text.ElideRight
                animateChange: true
                animationDistanceX: 6
                animationDistanceY: 0
            }
            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.player?.trackArtist ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.colSubtext
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.player?.identity ?? ""
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colSubtext
                opacity: 0.8
                elide: Text.ElideRight
            }
        }

        Loader {
            active: root.compact
            visible: active
            sourceComponent: controls
        }
    }

    // Seek line and times
    ColumnLayout {
        Layout.fillWidth: true
        visible: (root.player?.length ?? 0) > 0
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                visible: root.compact
                text: positionText.text
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colSubtext
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: 14
                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekArea.containsMouse ? 6 : 4
                    radius: height / 2
                    color: ColorUtils.transparentize(root.colText, 0.82)
                    Behavior on height {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Rectangle {
                        height: parent.height
                        width: Math.max(height, parent.width * (seekArea.pressed ? seekArea.preview : root.progress))
                        radius: height / 2
                        color: root.colAccent
                    }
                }
                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    enabled: root.player?.canSeek ?? false
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    property real preview: 0
                    onPressed: mouse => preview = Math.max(0, Math.min(1, mouse.x / width))
                    onPositionChanged: mouse => {
                        if (pressed)
                            preview = Math.max(0, Math.min(1, mouse.x / width));
                    }
                    onReleased: root.player.position = preview * root.player.length
                }
            }
            StyledText {
                visible: root.compact
                text: lengthText.text
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colSubtext
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !root.compact
            StyledText {
                id: positionText
                text: StringUtils.friendlyTimeForSeconds(seekArea.pressed ? seekArea.preview * root.player.length : root.player?.position)
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colSubtext
            }
            Item {
                Layout.fillWidth: true
            }
            StyledText {
                id: lengthText
                text: StringUtils.friendlyTimeForSeconds(root.player?.length)
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colSubtext
            }
        }
    }

    Loader {
        Layout.alignment: Qt.AlignHCenter
        active: !root.compact
        visible: active
        sourceComponent: controls
    }

    Component {
        id: controls
        RowLayout {
            spacing: root.compact ? 2 : 18

            ControlButton {
                symbol: "skip_previous"
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }
            ControlButton {
                symbol: root.player?.isPlaying ? "pause" : "play_arrow"
                primary: true
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player.togglePlaying()
            }
            ControlButton {
                symbol: "skip_next"
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
        }
    }

    component ControlButton: RippleButton {
        id: button
        property string symbol
        property bool primary: false
        implicitWidth: (primary ? 48 : 38) - (root.compact ? 8 : 0)
        implicitHeight: implicitWidth
        buttonRadius: Appearance.rounding.full
        colBackground: primary ? root.colAccent : "transparent"
        colBackgroundHover: primary ? ColorUtils.mix(root.colAccent, root.colText, 0.85) : ColorUtils.transparentize(root.colText, 0.88)
        colRipple: ColorUtils.transparentize(root.colText, 0.75)

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: button.symbol
            fill: 1
            iconSize: (button.primary ? 28 : 26) - (root.compact ? 2 : 0)
            color: button.primary ? root.colOnAccent : root.colText
        }
    }
}
