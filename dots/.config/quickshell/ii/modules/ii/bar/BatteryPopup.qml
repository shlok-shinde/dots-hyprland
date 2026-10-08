import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

BarPopover {
    id: root
    name: "battery"

    function formatTime(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
    readonly property bool full: Battery.chargeState == UPowerDeviceState.FullyCharged
    readonly property bool low: Battery.isLow && !Battery.isCharging
    readonly property string statusText: root.full ? Translation.tr("Fully charged")
        : Battery.isCharging ? Translation.tr("Charging")
        : Battery.isPluggedIn ? Translation.tr("Plugged in, not charging")
        : Translation.tr("On battery")
    readonly property string estimate: {
        const t = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
        if (root.full || t <= 0 || Battery.energyRate <= 0.01)
            return "";
        return Battery.isCharging ? Translation.tr("%1 until full").arg(root.formatTime(t)) : Translation.tr("%1 left").arg(root.formatTime(t));
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 320
        spacing: 12

        RowLayout { // The level, big, and what it's doing
            Layout.fillWidth: true
            spacing: 14
            StyledText {
                text: `${Math.round(Battery.percentage * 100)}%`
                font.pixelSize: 40
                color: root.low ? Appearance.colors.colError : Appearance.colors.colOnLayer0
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    MaterialSymbol {
                        visible: Battery.isCharging
                        text: "bolt"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.statusText
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer0
                        wrapMode: Text.Wrap
                    }
                }
                StyledText {
                    visible: root.estimate.length > 0
                    text: root.estimate
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        Rectangle { // The level as a bar
            Layout.fillWidth: true
            implicitHeight: 8
            radius: height / 2
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
            Rectangle {
                height: parent.height
                width: Math.max(height, parent.width * Battery.percentage)
                radius: height / 2
                color: root.low ? Appearance.colors.colError : Appearance.hasAccent ? Appearance.accent : Appearance.colors.colPrimary
                Behavior on width {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            StyledPopupValueRow {
                Layout.fillWidth: true
                visible: !root.full && Battery.energyRate > 0.01
                icon: "bolt"
                label: Battery.isCharging ? Translation.tr("Charging at") : Translation.tr("Using")
                value: `${Battery.energyRate.toFixed(1)} W`
            }
            StyledPopupValueRow {
                Layout.fillWidth: true
                icon: "heart_check"
                label: Translation.tr("Health")
                value: `${Battery.health.toFixed(1)}%`
            }
        }

        // Power mode
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { profile: PowerProfile.PowerSaver, icon: "energy_savings_leaf", label: Translation.tr("Saver") },
                    { profile: PowerProfile.Balanced, icon: "airwave", label: Translation.tr("Balanced") },
                    { profile: PowerProfile.Performance, icon: "local_fire_department", label: Translation.tr("Performance") }
                ].filter(m => m.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                delegate: RippleButton {
                    id: modeButton
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1 // equal thirds
                    implicitHeight: 52
                    buttonRadius: Appearance.rounding.normal
                    toggled: PowerProfiles.profile === modelData.profile
                    colBackground: ColorUtils.transparentize(Appearance.colors.colOnLayer0, Appearance.m3colors.darkmode ? 0.93 : 0.95)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnLayer0, Appearance.m3colors.darkmode ? 0.86 : 0.9)
                    colBackgroundToggled: Appearance.hasAccent ? Appearance.accent : Appearance.colors.colPrimary
                    colBackgroundToggledHover: colBackgroundToggled
                    onClicked: PowerProfiles.profile = modelData.profile
                    readonly property color fg: toggled ? Appearance.onAccent : Appearance.colors.colOnLayer0

                    contentItem: ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: modeButton.modelData.icon
                            fill: modeButton.toggled ? 1 : 0
                            iconSize: Appearance.font.pixelSize.larger
                            color: modeButton.fg
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modeButton.modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: modeButton.fg
                        }
                    }
                }
            }
        }
    }
}
