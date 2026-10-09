import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.panels.lock
import qs.modules.ii.bar as Bar
import Quickshell
import Quickshell.Services.SystemTray

MouseArea {
    id: root
    required property LockContext context
    property bool active: false
    property bool showInputField: active || context.currentText.length > 0
    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower

    // Force focus on entry
    function forceFieldFocus() {
        passwordBox.forceActiveFocus();
    }
    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus();
        }
    }
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: mouse => {
        forceFieldFocus();
    }
    onPositionChanged: mouse => {
        forceFieldFocus();
    }

    // Toolbar appearing animation
    property real toolbarScale: 0.9
    property real toolbarOpacity: 0
    Behavior on toolbarScale {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }
    }
    Behavior on toolbarOpacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    // Init
    Component.onCompleted: {
        forceFieldFocus();
        toolbarScale = 1;
        toolbarOpacity = 1;
    }

    // Key presses
    property bool ctrlHeld: false
    Keys.onPressed: event => {
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = true;
        }
        if (event.key === Qt.Key_Escape) { // Esc to clear
            root.context.currentText = "";
        } 
        forceFieldFocus();
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = false;
        }
        forceFieldFocus();
    }

    // RippleButton {
    //     anchors {
    //         top: parent.top
    //         left: parent.left
    //         leftMargin: 10
    //         topMargin: 10
    //     }
    //     implicitHeight: 40
    //     colBackground: Appearance.colors.colLayer2
    //     onClicked: {
    //         context.unlocked(LockContext.ActionEnum.Unlock);
    //         GlobalStates.screenLocked = false;
    //     }
    //     contentItem: StyledText {
    //         text: "[[ DEBUG BYPASS ]]"
    //     }
    // }

    // Liquid glass. The compositor's glass can't reach a lock surface, so the
    // lock draws the wallpaper itself and its own glass over it
    // (LiquidGlassEffect): a glass clock and glass under the three toolbars.
    readonly property bool liquid: Appearance.liquidGlass
    readonly property bool light: !Appearance.m3colors.darkmode
    readonly property string wallpaperPath: {
        const path = Config.options.background.wallpaperPath;
        const isVideo = [".mp4", ".webm", ".mkv", ".avi", ".mov"].some(ext => path.endsWith(ext));
        return isVideo ? Config.options.background.thumbnailPath : path;
    }

    Item {
        id: lockBackdrop
        anchors.fill: parent
        visible: root.liquid
        Image {
            anchors.fill: parent
            source: root.liquid ? root.wallpaperPath : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.width, root.height)
            cache: false
        }
        Rectangle { // A little darker than the desktop, like a screen at rest
            anchors.fill: parent
            color: "black"
            opacity: 0.25
        }
    }

    Loader {
        id: liquidClockLoader
        active: root.liquid
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: root.height * 0.11
        }
        sourceComponent: Column {
            spacing: 2
            StyledText { // Date, in the dot-matrix face
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Appearance.font.family.title
                font.pixelSize: Math.round(root.height * 0.024)
                color: Qt.rgba(1, 1, 1, 0.9)
                text: DateTime.longDate
            }
            LiquidGlassEffect { // The time, in glass: clear and light, like the lock screen's in Tahoe
                anchors.horizontalCenter: parent.horizontalCenter
                width: clockText.implicitWidth
                height: clockText.implicitHeight
                backdrop: lockBackdrop
                bezel: 10
                refraction: 16
                bodyLens: 0
                frost: 1.5
                rim: 1.0
                brightness: 1.1
                adaptiveDim: 0.1
                tint: Qt.rgba(1, 1, 1, 0.18)
                dispersion: 0.2
                shadow: 0.45

                Text {
                    // Solid strokes: dot-matrix digits would each turn into a bead of glass
                    id: clockText
                    text: DateTime.time
                    color: "white"
                    font.family: "Google Sans Flex"
                    font.pixelSize: Math.round(root.height * 0.17)
                    font.weight: Font.Black
                    font.variableAxes: ({ "wght": 820 }) // it's a variable font: weight goes by axis
                    font.letterSpacing: -2
                }
            }
        }
    }

    // What's playing and the notifications you haven't seen, under the clock
    // (on the right without glass, where the desktop's own clock leaves room)
    ColumnLayout {
        id: lockWidgets
        readonly property real topY: root.liquid ? liquidClockLoader.y + liquidClockLoader.height + root.height * 0.028 : 40
        width: Math.min(420, root.width - 40)
        x: root.liquid ? (root.width - width) / 2 : root.width - width - 40
        y: topY
        spacing: 14
        scale: root.toolbarScale
        opacity: root.toolbarOpacity
        // Room down to the password field
        readonly property real room: mainIsland.y - 24 - topY

        LockCard {
            id: mediaCard
            Layout.fillWidth: true
            visible: Config.options.lock.showMedia && (MprisController.activePlayer?.trackTitle?.length ?? 0) > 0
            backdrop: lockBackdrop
            mapTick: root.toolbarScale + lockWidgets.y
            padding: 14

            NowPlaying {
                Layout.fillWidth: true
                artSize: 52
                compact: true
                visualizerBleed: mediaCard.padding
                visualizerRadius: mediaCard.radius
            }
        }

        LockNotifications {
            Layout.fillWidth: true
            visible: Config.options.lock.notifications.enable && appNames.length > 0
            backdrop: lockBackdrop
            mapTick: root.toolbarScale + lockWidgets.y + y
            maxHeight: lockWidgets.room - (mediaCard.visible ? mediaCard.height + lockWidgets.spacing : 0)
        }
    }

    // Glass under the toolbars (declared first so it sits behind them); the
    // toolbars themselves go see-through in glass mode. (The clock and date
    // sit on the wallpaper and stay as they are, as on a Mac.)
    component IslandGlass: LockGlass {
        required property Item island
        anchors.fill: island
        visible: root.liquid
        scale: island.scale
        opacity: island.opacity
        mapTick: root.toolbarScale
        backdrop: lockBackdrop
    }
    IslandGlass {
        island: mainIsland
    }
    IslandGlass {
        island: leftIsland
    }
    IslandGlass {
        island: rightIsland
    }

    // Main toolbar: password box
    Toolbar {
        id: mainIsland
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: root.liquid ? root.height * 0.08 : 20
        }
        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        colBackground: root.liquid ? "transparent" : Appearance.m3colors.m3surfaceContainer
        enableShadow: !root.liquid

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        // Fingerprint
        Loader {
            Layout.leftMargin: 10
            Layout.rightMargin: 6
            Layout.alignment: Qt.AlignVCenter
            active: root.context.fingerprintsConfigured
            visible: active

            sourceComponent: MaterialSymbol {
                id: fingerprintIcon
                fill: 1
                text: "fingerprint"
                iconSize: Appearance.font.pixelSize.hugeass
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        ToolbarTextField {
            id: passwordBox
            Layout.rightMargin: -Layout.leftMargin
            placeholderText: GlobalStates.screenUnlockFailed ? Translation.tr("Incorrect password") : Translation.tr("Enter password")

            // Style
            clip: true
            font.pixelSize: Appearance.font.pixelSize.small
            selectedTextColor: materialShapeChars ? "transparent" : Appearance.colors.colOnSecondaryContainer
            selectionColor: materialShapeChars ? "transparent" : Appearance.colors.colSecondaryContainer

            // Password
            enabled: !root.context.unlockInProgress
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData

            // Synchronizing (across monitors) and unlocking
            onTextChanged: root.context.currentText = this.text
            onAccepted: {
                root.context.tryUnlock(ctrlHeld);
            }
            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    passwordBox.text = root.context.currentText;
                }
            }

            Keys.onPressed: event => {
                root.context.resetClearTimer();
            }
            
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: passwordBox.width - 8
                    height: passwordBox.height
                    radius: height / 2
                }
            }

            // Shake when wrong password
            ErrorShakeAnimation {
                id: wrongPasswordShakeAnim
                target: passwordBox
            }
            Connections {
                target: GlobalStates
                function onScreenUnlockFailedChanged() {
                    if (GlobalStates.screenUnlockFailed) wrongPasswordShakeAnim.restart();
                }
            }

            // We're drawing dots manually
            property bool materialShapeChars: Config.options.lock.materialShapeChars
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, materialShapeChars ? 1 : 0)
            Loader {
                active: passwordBox.materialShapeChars
                anchors {
                    fill: parent
                    leftMargin: passwordBox.padding
                    rightMargin: passwordBox.padding
                }
                sourceComponent: PasswordChars {
                    length: root.context.currentText.length
                    selectionStart: passwordBox.selectionStart
                    selectionEnd: passwordBox.selectionEnd
                    cursorPosition: passwordBox.cursorPosition
                }
            }
        }

        ToolbarButton {
            id: confirmButton
            implicitWidth: height
            toggled: true
            enabled: !root.context.unlockInProgress
            colBackgroundToggled: Appearance.colors.colPrimary

            onClicked: root.context.tryUnlock()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: 24
                text: {
                    if (root.context.targetAction === LockContext.ActionEnum.Unlock) {
                        return root.ctrlHeld ? "coffee" : "arrow_right_alt";
                    } else if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                        return "power_settings_new";
                    } else if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                        return "restart_alt";
                    }
                }
                color: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
            }
        }
    }

    // Left toolbar
    Toolbar {
        id: leftIsland
        anchors {
            right: mainIsland.left
            top: mainIsland.top
            bottom: mainIsland.bottom
            rightMargin: 10
        }
        colBackground: root.liquid ? "transparent" : Appearance.m3colors.m3surfaceContainer
        enableShadow: !root.liquid
        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        // Username
        IconAndTextPair {
            Layout.leftMargin: 8
            icon: "account_circle"
            text: SystemInfo.username
        }

        // Keyboard layout (Xkb)
        Loader {
            Layout.rightMargin: 8
            Layout.fillHeight: true

            active: true
            visible: active

            sourceComponent: Row {
                spacing: 8

                MaterialSymbol {
                    id: keyboardIcon
                    anchors.verticalCenter: parent.verticalCenter
                    fill: 1
                    text: "keyboard_alt"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colOnSurfaceVariant
                }
                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: StyledText {
                        text: HyprlandXkb.currentLayoutCode
                        color: Appearance.colors.colOnSurfaceVariant
                        animateChange: true
                    }
                }
            }
        }

        // Keyboard layout (Fcitx)
        Bar.SysTray {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            showSeparator: false
            showOverflowMenu: false
            pinnedItems: SystemTray.items.values.filter(i => i.id == "Fcitx")
            visible: pinnedItems.length > 0
        }
    }

    // Right toolbar
    Toolbar {
        id: rightIsland
        anchors {
            left: mainIsland.right
            top: mainIsland.top
            bottom: mainIsland.bottom
            leftMargin: 10
        }
        colBackground: root.liquid ? "transparent" : Appearance.m3colors.m3surfaceContainer
        enableShadow: !root.liquid

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        IconAndTextPair {
            visible: Battery.available
            icon: Battery.isCharging ? "bolt" : "battery_android_full"
            text: Math.round(Battery.percentage * 100)
            color: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
        }

        IconToolbarButton {
            id: sleepButton
            onClicked: Session.suspend()
            text: "dark_mode"
        }

        PasswordGuardedIconToolbarButton {
            id: powerButton
            text: "power_settings_new"
            targetAction: LockContext.ActionEnum.Poweroff
        }

        PasswordGuardedIconToolbarButton {
            id: rebootButton
            text: "restart_alt"
            targetAction: LockContext.ActionEnum.Reboot
        }
    }

    component PasswordGuardedIconToolbarButton: IconToolbarButton {
        id: guardedBtn
        required property var targetAction

        toggled: root.context.targetAction === guardedBtn.targetAction

        onClicked: {
            if (!root.requirePasswordToPower) {
                root.context.unlocked(guardedBtn.targetAction);
                return;
            }
            if (root.context.targetAction === guardedBtn.targetAction) {
                root.context.resetTargetAction();
            } else {
                root.context.targetAction = guardedBtn.targetAction;
                root.context.shouldReFocus();
            }
        }
    }

    component IconAndTextPair: Row {
        id: pair
        required property string icon
        required property string text
        property color color: Appearance.colors.colOnSurfaceVariant

        spacing: 4
        Layout.fillHeight: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 1
            text: pair.icon
            iconSize: Appearance.font.pixelSize.huge
            animateChange: true
            color: pair.color
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: pair.text
            color: pair.color
        }
    }
}
