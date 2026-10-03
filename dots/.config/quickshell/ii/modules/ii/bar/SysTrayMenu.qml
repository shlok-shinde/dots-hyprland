pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// A layer of its own rather than a popup of the bar: the glass plugin only
// reaches layers, and a popup would show the desktop through it unglassed.
PanelWindow {
    id: root
    required property QsMenuHandle trayItemMenuHandle
    required property Item anchorItem // the tray icon it opens from
    property string trayItemId: ""
    property real popupBackgroundMargin: 0

    signal menuClosed
    signal menuOpened(qsWindow: var) // Correct type is QsWindow, but QML does not like that

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    visible: false
    screen: root.anchorItem.QsWindow.window?.screen ?? null
    WlrLayershell.namespace: "quickshell:trayMenu"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        top: true
    }

    // Where the icon is on the screen, taken when the menu opens. The icon's
    // window is a layer too, placed by its anchors and margins.
    property rect anchorRect: Qt.rect(0, 0, 0, 0)
    function measureAnchor() {
        const item = root.anchorItem;
        const win = item?.QsWindow.window;
        const screen = win?.screen;
        if (!win || !screen)
            return;
        const p = item.mapToItem(null, 0, 0);
        const a = win.anchors, m = win.margins;
        const x = a.left ? m.left : a.right ? screen.width - win.width - m.right : (screen.width - win.width) / 2;
        const y = a.top ? m.top : a.bottom ? screen.height - win.height - m.bottom : (screen.height - win.height) / 2;
        root.anchorRect = Qt.rect(x + p.x, y + p.y, item.width, item.height);
    }
    // Below the icon (above it on a bottom bar, beside it on a vertical one),
    // kept on screen
    readonly property real gap: 4
    margins {
        left: {
            const r = root.anchorRect;
            const sw = root.screen?.width ?? 0;
            let x;
            if (!Config.options.bar.vertical)
                x = r.x + (r.width - root.implicitWidth) / 2;
            else if (Config.options.bar.bottom) // on the right
                x = r.x - root.implicitWidth - root.gap + root.padding;
            else
                x = r.x + r.width + root.gap - root.padding;
            return Math.round(Math.max(0, Math.min(x, sw - root.implicitWidth)));
        }
        top: {
            const r = root.anchorRect;
            const sh = root.screen?.height ?? 0;
            let y;
            if (Config.options.bar.vertical)
                y = r.y + (r.height - root.implicitHeight) / 2;
            else if (Config.options.bar.bottom)
                y = r.y - root.implicitHeight - root.gap + root.padding;
            else
                y = r.y + r.height + root.gap - root.padding;
            return Math.round(Math.max(0, Math.min(y, sh - root.implicitHeight)));
        }
    }

    implicitHeight: {
        let result = 0;
        for (let child of stackView.children) {
            result = Math.max(child.implicitHeight, result);
        }
        return result + popupBackground.padding * 2 + root.padding * 2;
    }
    implicitWidth: {
        let result = 0;
        for (let child of stackView.children) {
            result = Math.max(child.implicitWidth, result);
        }
        return result + popupBackground.padding * 2 + root.padding * 2;
    }

    function open() {
        root.measureAnchor();
        root.visible = true;
        root.menuOpened(root);
    }

    function close() {
        root.visible = false;
        while (stackView.depth > 1)
            stackView.pop();
        root.menuClosed();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.RightButton
        onPressed: event => {
            if ((event.button === Qt.BackButton || event.button === Qt.RightButton) && stackView.depth > 1)
                stackView.pop();
        }

        StyledRectangularShadow {
            target: popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            readonly property real padding: 4
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: Config.options.bar.vertical ? parent.verticalCenter : undefined
                top: Config.options.bar.vertical ? undefined : Config.options.bar.bottom ? undefined : parent.top
                bottom: Config.options.bar.vertical ? undefined : Config.options.bar.bottom ? parent.bottom : undefined
                margins: root.padding
            }

            color: Appearance.colors.colLayer0
            radius: Appearance.rounding.windowRounding
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: stackView.implicitWidth + popupBackground.padding * 2
            implicitHeight: stackView.implicitHeight + popupBackground.padding * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

            StackView {
                id: stackView
                anchors {
                    fill: parent
                    margins: popupBackground.padding
                }
                pushEnter: NoAnim {}
                pushExit: NoAnim {}
                popEnter: NoAnim {}
                popExit: NoAnim {}

                implicitWidth: currentItem.implicitWidth
                implicitHeight: currentItem.implicitHeight

                initialItem: SubMenu {
                    handle: root.trayItemMenuHandle
                }
            }
        }
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: ColumnLayout {
        id: submenu
        required property QsMenuHandle handle
        property bool isSubMenu: false
        property bool shown: false
        opacity: shown ? 1 : 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        QsMenuOpener {
            id: menuOpener
            menu: submenu.handle
        }

        spacing: 0

        Loader {
            Layout.fillWidth: true
            visible: submenu.isSubMenu
            active: visible
            sourceComponent: RippleButton {
                id: backButton
                buttonRadius: popupBackground.radius - popupBackground.padding
                horizontalPadding: 12
                implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                implicitHeight: 36

                downAction: () => stackView.pop()

                contentItem: RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        leftMargin: backButton.horizontalPadding
                        rightMargin: backButton.horizontalPadding
                    }
                    spacing: 8
                    MaterialSymbol {
                        iconSize: 20
                        text: "chevron_left"
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Back")
                    }
                }
            }
        }
        RippleButton {
            id: pinEntry
            buttonRadius: popupBackground.radius - popupBackground.padding
            horizontalPadding: 12
            implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
            implicitHeight: 36
            Layout.topMargin: 0
            Layout.bottomMargin: 0
            Layout.fillWidth: true

            visible: root.trayItemId !== undefined && root.trayItemId.length > 0 && stackView.depth === 1
            releaseAction: () => TrayService.togglePin(root.trayItemId);

            contentItem: RowLayout {
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: pinEntry.horizontalPadding
                    rightMargin: pinEntry.horizontalPadding
                }
                spacing: 8

                MaterialSymbol {
                    iconSize: 18
                    text: "push_pin"
                }

                StyledText {
                    Layout.fillWidth: true
                    text: TrayService.isPinned(root.trayItemId) ? Translation.tr("Unpin") : Translation.tr("Pin")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colSubtext
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        Repeater {
            id: menuEntriesRepeater
            property bool iconColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].icon.length > 0)
                        return true;
                }
                return false;
            }
            property bool specialInteractionColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].buttonType !== QsMenuButtonType.None)
                        return true;
                }
                return false;
            }
            model: menuOpener.children
            delegate: SysTrayMenuEntry {
                required property QsMenuEntry modelData
                forceIconColumn: menuEntriesRepeater.iconColumnNeeded
                forceSpecialInteractionColumn: menuEntriesRepeater.specialInteractionColumnNeeded
                menuEntry: modelData

                buttonRadius: popupBackground.radius - popupBackground.padding

                onDismiss: root.close()
                onOpenSubmenu: handle => {
                    stackView.push(subMenuComponent.createObject(null, {
                        handle: handle,
                        isSubMenu: true
                    }));
                }
            }
        }
    }

    Component {
        id: subMenuComponent
        SubMenu {}
    }
}
