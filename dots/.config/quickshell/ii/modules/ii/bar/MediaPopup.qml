pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

BarPopover {
    id: root
    name: "media"

    // One per app and track: some players (VLC) show up under two bus names
    readonly property var players: MprisController.players.filter((p, i, all) => all.findIndex(q => q.identity === p.identity && q.trackTitle === p.trackTitle) === i)
    function isActive(player) {
        const active = MprisController.activePlayer;
        return active === player || (active?.identity === player.identity && active?.trackTitle === player.trackTitle);
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 340
        spacing: 12

        // Which player, when there is more than one
        Flow {
            Layout.fillWidth: true
            visible: root.players.length > 1
            spacing: 6
            Repeater {
                model: root.players
                delegate: RippleButton {
                    id: playerChip
                    required property MprisPlayer modelData
                    implicitHeight: 28
                    implicitWidth: chipRow.implicitWidth + 20
                    buttonRadius: Appearance.rounding.full
                    toggled: root.isActive(modelData)
                    colBackground: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.92)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.86)
                    colBackgroundToggled: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.75)
                    colBackgroundToggledHover: colBackgroundToggled
                    onClicked: MprisController.trackedPlayer = modelData

                    contentItem: RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: playerChip.modelData.isPlaying ? "graphic_eq" : "music_note"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            text: playerChip.modelData.identity
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                }
            }
        }

        NowPlaying {
            Layout.fillWidth: true
            visible: MprisController.activePlayer !== null
            player: MprisController.activePlayer
        }

        ColumnLayout { // Nothing to control
            Layout.fillWidth: true
            visible: MprisController.activePlayer === null
            spacing: 4
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "music_off"
                iconSize: 36
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Nothing playing")
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Translation.tr("Players that support MPRIS show up here")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
}
