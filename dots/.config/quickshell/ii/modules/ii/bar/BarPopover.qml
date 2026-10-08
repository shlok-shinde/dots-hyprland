pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * A glass panel that drops from a bar chip when the chip is clicked (the chip
 * calls toggle()). One is open at a time; a click anywhere else or Esc closes
 * it. A layer of its own (quickshell:popup) so the compositor's glass reaches
 * it, on the chip's screen, under the chip (above it on a bottom bar, beside
 * it on a vertical one). The content goes inside, centred (`anchors.centerIn:
 * parent`), at its implicit size or a width of its own.
 */
LazyLoader {
    id: root

    required property Item anchorItem // the chip
    required property string name // which chip, unique within a bar
    default property Item contentItem
    property real padding: 16

    readonly property string key: `${root.name}@${root.anchorItem?.QsWindow.window?.screen?.name ?? ""}`
    readonly property bool isOpen: GlobalStates.barPopover === root.key

    // A click outside closes the panel before the chip under it sees the
    // press; that same press must not open it again
    property real dismissedAt: 0
    function toggle() {
        if (root.isOpen)
            root.close();
        else if (Date.now() - root.dismissedAt > 300)
            root.open();
    }
    function open() {
        GlobalStates.barPopover = root.key;
    }
    function close() {
        if (root.isOpen)
            GlobalStates.barPopover = "";
    }

    active: root.isOpen

    component: PanelWindow {
        id: popoverWindow
        color: "transparent"
        screen: root.anchorItem.QsWindow.window?.screen ?? null
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        anchors {
            left: true
            top: true
        }

        readonly property real room: Appearance.sizes.elevationMargin // for the shadow without glass
        implicitWidth: panel.implicitWidth + room * 2
        implicitHeight: panel.implicitHeight + room * 2
        mask: Region {
            item: panel
        }

        // Where the chip is on the screen. Its window is a layer, placed by
        // its anchors and margins.
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
            popoverWindow.anchorRect = Qt.rect(x + p.x, y + p.y, item.width, item.height);
        }
        readonly property real gap: 6
        margins {
            left: {
                const r = popoverWindow.anchorRect, w = popoverWindow.implicitWidth;
                const sw = popoverWindow.screen?.width ?? 0;
                let x;
                if (!Config.options.bar.vertical)
                    x = r.x + (r.width - w) / 2;
                else if (Config.options.bar.bottom) // a bar on the right
                    x = r.x - w - popoverWindow.gap + popoverWindow.room;
                else
                    x = r.x + r.width + popoverWindow.gap - popoverWindow.room;
                return Math.round(Math.max(0, Math.min(x, sw - w)));
            }
            top: {
                const r = popoverWindow.anchorRect, h = popoverWindow.implicitHeight;
                const sh = popoverWindow.screen?.height ?? 0;
                let y;
                if (Config.options.bar.vertical)
                    y = r.y + (r.height - h) / 2;
                else if (Config.options.bar.bottom)
                    y = r.y - h - popoverWindow.gap + popoverWindow.room;
                else
                    y = r.y + r.height + popoverWindow.gap - popoverWindow.room;
                return Math.round(Math.max(0, Math.min(y, sh - h)));
            }
        }

        // Placed a tick after it's made (at first the chip's window can still
        // report a stale size), and shown only once placed, so it never jumps
        visible: false
        function place() {
            popoverWindow.measureAnchor();
            popoverWindow.visible = true;
        }
        Component.onCompleted: {
            Qt.callLater(popoverWindow.place);
            GlobalFocusGrab.addDismissable(popoverWindow);
        }
        Component.onDestruction: GlobalFocusGrab.removeDismissable(popoverWindow)
        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                root.dismissedAt = Date.now();
                root.close();
            }
        }

        StyledRectangularShadow {
            target: panel
        }
        Rectangle {
            id: panel
            x: popoverWindow.room
            y: popoverWindow.room
            // the content's size: its own, or the width it was given
            implicitWidth: root.contentItem.width + root.padding * 2
            implicitHeight: root.contentItem.height + root.padding * 2
            width: implicitWidth
            height: implicitHeight
            // In glass mode this is the glass: the compositor takes the shape
            // from its alpha and lays its glass under the content
            color: Appearance.liquidGlass ? Appearance.colors.colLayer0 : Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.large
            border.width: Appearance.liquidGlass ? 0 : 1
            border.color: Appearance.colors.colLayer0Border
            children: [root.contentItem]

            focus: true
            Keys.onEscapePressed: root.close()
        }
    }
}
