pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * The notifications you haven't seen yet (since you last opened the
 * notification list), one card per app, newest first, as many as fit in
 * `maxHeight`. An app with several stacks them: tap the stack to spread it
 * out, which gives it the whole list until you fold it back.
 * They can be cleared here; acting on one (opening, replying) waits for the
 * unlock.
 */
ColumnLayout {
    id: root
    required property Item backdrop
    property real maxHeight: 400
    property real mapTick: 0
    readonly property bool showContent: Config.options.lock.notifications.showContent

    readonly property var unseen: Notifications.list.filter(n => n.time > Notifications.readUntil)
    readonly property var groups: Notifications.groupsForList(root.unseen)
    readonly property var appNames: Notifications.appNameListForGroups(root.groups)
    property string expandedApp: "" // the spread-out stack, if any
    onAppNamesChanged: {
        if (root.expandedApp !== "" && !root.appNames.includes(root.expandedApp))
            root.expandedApp = "";
    }
    // Entries a spread-out stack has room for
    readonly property int expandedFit: Math.max(1, Math.min(6, Math.floor((root.maxHeight - header.implicitHeight - root.spacing - 60) / 62)))

    // How many cards fit, in order: a later one never shows in place of an
    // earlier one. Room for the "+N more" line only when some don't fit.
    function cardsFitting(room) {
        let used = header.implicitHeight;
        let n = 0;
        for (let i = 0; i < cards.count; i++) {
            const card = cards.itemAt(i);
            if (!card)
                break;
            used += root.spacing + card.implicitHeight + card.stackPeek;
            if (used > room)
                break;
            n++;
        }
        return n;
    }
    readonly property int fitCount: {
        cards.count;
        const all = root.cardsFitting(root.maxHeight);
        return all === cards.count ? all : root.cardsFitting(root.maxHeight - moreLabel.implicitHeight - root.spacing);
    }

    visible: root.appNames.length > 0
    spacing: 8

    function clearGroup(appName) {
        root.groups[appName]?.notifications.map(n => n.notificationId).forEach(id => Notifications.discardNotification(id));
    }

    RowLayout { // How many (or back from a spread-out stack), and clear them: small glass pills (any wallpaper is behind them)
        id: header
        Layout.fillWidth: true
        GlassPill {
            CardButton {
                anchors.fill: parent
                enabled: root.expandedApp !== ""
                opacity: 1
                symbol: root.expandedApp !== "" ? "chevron_left" : "notifications"
                label: root.expandedApp !== "" ? root.expandedApp
                    : root.unseen.length === 1 ? Translation.tr("1 notification") : Translation.tr("%1 notifications").arg(root.unseen.length)
                onClicked: root.expandedApp = ""
            }
        }
        Item {
            Layout.fillWidth: true
        }
        GlassPill {
            CardButton {
                anchors.fill: parent
                symbol: "clear_all"
                label: Translation.tr("Clear")
                onClicked: {
                    if (root.expandedApp !== "")
                        root.clearGroup(root.expandedApp);
                    else
                        root.unseen.map(n => n.notificationId).forEach(id => Notifications.discardNotification(id));
                }
            }
        }
    }

    Repeater {
        id: cards
        model: root.appNames
        delegate: Item {
            id: card
            required property string modelData
            required property int index
            readonly property var group: root.groups[modelData]
            readonly property var notifications: (group?.notifications ?? []).slice().reverse() // newest first
            readonly property bool stacked: notifications.length > 1
            readonly property bool expanded: root.expandedApp === modelData
            // The stack's edge peeking out under a closed stack
            readonly property real stackPeek: stacked && !expanded ? 9 : 0

            Layout.fillWidth: true
            Layout.bottomMargin: stackPeek
            visible: root.expandedApp === "" ? index < root.fitCount : expanded
            implicitHeight: pane.implicitHeight

            LockGlass { // the stack's edge
                visible: card.stackPeek > 0 && Appearance.liquidGlass
                x: 14
                width: parent.width - 28
                y: pane.height - height + card.stackPeek
                height: 30
                radius: Appearance.rounding.normal
                backdrop: root.backdrop
                mapTick: root.mapTick + card.y
                opacity: 0.85
            }
            Rectangle {
                visible: card.stackPeek > 0 && !Appearance.liquidGlass
                x: 14
                width: parent.width - 28
                y: pane.height - height + card.stackPeek
                height: 30
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainerHigh
            }

            LockCard {
                id: pane
                width: parent.width
                backdrop: root.backdrop
                mapTick: root.mapTick + card.y + pane.height
                padding: 12

                RowLayout { // Which app, when, and dismiss
                    Layout.fillWidth: true
                    spacing: 8
                    NotificationAppIcon {
                        implicitSize: 22
                        appIcon: card.group?.appIcon ?? ""
                        summary: card.notifications[0]?.summary ?? ""
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: card.modelData || Translation.tr("Notification")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: NotificationUtils.getFriendlyNotifTimeString(card.group?.time)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    CardButton {
                        implicitHeight: 22
                        visible: card.stacked
                        symbol: card.expanded ? "unfold_less" : ""
                        label: card.expanded ? "" : `${card.notifications.length}`
                        onClicked: root.expandedApp = card.expanded ? "" : card.modelData
                    }
                    CardButton {
                        implicitHeight: 22
                        symbol: "close"
                        onClicked: root.clearGroup(card.modelData)
                    }
                }

                Repeater { // The newest, or all of them (up to four) when spread out
                    model: card.notifications.slice(0, card.expanded ? root.expandedFit : 1)
                    delegate: ColumnLayout {
                        id: entry
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 1

                        Rectangle { // between entries of a spread-out stack
                            visible: entry.index > 0
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            implicitHeight: 1
                            color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.88)
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.showContent ? entry.modelData.summary : (card.stacked && !card.expanded ? Translation.tr("%1 new notifications").arg(card.notifications.length) : Translation.tr("New notification"))
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: root.showContent && text.length > 0
                            text: NotificationUtils.processNotificationBody(entry.modelData.body, entry.modelData.appName).replace(/<[^>]*>/g, "").replace(/\n+/g, " ").trim()
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.Wrap
                            maximumLineCount: card.expanded ? 3 : 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            MouseArea { // Tap a stack to spread it out (the buttons above take their own clicks)
                anchors.fill: pane
                z: -1
                enabled: card.stacked
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.expandedApp = card.expanded ? "" : card.modelData
            }
        }
    }

    GlassPill { // What didn't fit
        id: moreLabel
        Layout.alignment: Qt.AlignHCenter
        readonly property int hidden: root.expandedApp !== "" ? Math.max(0, (root.groups[root.expandedApp]?.notifications.length ?? 0) - root.expandedFit) : root.appNames.length - root.fitCount
        visible: hidden > 0
        CardButton {
            anchors.fill: parent
            enabled: false
            opacity: 1
            label: Translation.tr("%1 more").arg(moreLabel.hidden)
        }
    }

    // A glass pill sized to the one button inside it
    component GlassPill: Item {
        id: pill
        implicitWidth: children[children.length - 1].implicitWidth
        implicitHeight: children[children.length - 1].implicitHeight
        LockGlass {
            anchors.fill: parent
            visible: Appearance.liquidGlass
            backdrop: root.backdrop
            mapTick: root.mapTick + pill.y
        }
        Rectangle {
            anchors.fill: parent
            visible: !Appearance.liquidGlass
            radius: height / 2
            color: Appearance.m3colors.m3surfaceContainer
        }
    }

    component CardButton: RippleButton {
        id: button
        property string symbol: ""
        property string label: ""
        implicitHeight: 26
        implicitWidth: Math.max(implicitHeight, buttonRow.implicitWidth + (label.length > 0 ? 20 : 0))
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.8)
        colRipple: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.7)

        contentItem: Item {
            RowLayout {
                id: buttonRow
                anchors.centerIn: parent
                spacing: 3
                MaterialSymbol {
                    visible: button.symbol.length > 0
                    text: button.symbol
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    visible: button.label.length > 0
                    text: button.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer0
                }
            }
        }
    }
}
