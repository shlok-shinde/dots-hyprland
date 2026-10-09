pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

/**
 * Every installed app in a grid, A to Z, under the search bar: what the dock's
 * apps button opens in place of the workspaces. Typing searches as before.
 */
Item {
    id: root
    property int columns: 7
    property real maxRows: 4.4 // part of the next row peeks out: there's more below
    property real cellWidth: 118
    property real cellHeight: 112
    property real padding: 14

    readonly property var apps: AppSearch.list
        .filter(app => !app.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    implicitWidth: background.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: background.implicitHeight + Appearance.sizes.elevationMargin * 2

    function launch(entry) {
        GlobalStates.overviewOpen = false;
        if (!entry.runInTerminal)
            entry.execute();
        else
            Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(entry.command.join(' '))}'`]);
    }

    signal leaveUp() // Up from the top row: back to the search bar

    function focusGrid() {
        grid.forceActiveFocus();
        if (grid.currentIndex < 0)
            grid.currentIndex = 0;
    }

    StyledRectangularShadow {
        target: background
    }
    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        implicitWidth: root.columns * root.cellWidth + root.padding * 2
        implicitHeight: Math.min(root.maxRows, Math.ceil(root.apps.length / root.columns)) * root.cellHeight + root.padding * 2
        radius: Appearance.rounding.large + root.padding / 2
        color: Appearance.colors.colBackgroundSurfaceContainer

        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: root.padding
            anchors.bottomMargin: 0 // scroll right to the pane's edge
            bottomMargin: root.padding
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            model: root.apps
            ScrollBar.vertical: StyledScrollBar {}

            Keys.onUpPressed: event => {
                if (currentIndex < root.columns)
                    root.leaveUp();
                else
                    event.accepted = false;
            }
            Keys.onReturnPressed: if (currentItem) root.launch(currentItem.modelData)
            Keys.onEnterPressed: if (currentItem) root.launch(currentItem.modelData)

            delegate: RippleButton {
                id: app
                required property var modelData
                required property int index
                readonly property bool selected: hovered || (grid.activeFocus && GridView.isCurrentItem)
                width: grid.cellWidth
                height: grid.cellHeight
                buttonRadius: Appearance.rounding.normal
                colBackground: selected ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9) : "transparent"
                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
                colRipple: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.8)
                onClicked: root.launch(modelData)

                contentItem: Column {
                    anchors.centerIn: parent
                    spacing: 8
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 52
                        source: Quickshell.iconPath(app.modelData.icon, "image-missing")
                    }
                    StyledText {
                        width: grid.cellWidth - 12
                        horizontalAlignment: Text.AlignHCenter
                        text: app.modelData.name
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
