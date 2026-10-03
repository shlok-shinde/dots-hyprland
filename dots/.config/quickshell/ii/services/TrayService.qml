pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property bool smartTray: Config.options.tray.filterPassive
    property list<var> itemsInUserList: SystemTray.items.values.filter(i => (Config.options.tray.pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))
    property list<var> itemsNotInUserList: SystemTray.items.values.filter(i => (!Config.options.tray.pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))

    property bool invertPins: Config.options.tray.invertPinnedItems
    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList

    function getTooltipForItem(item) {
        var result = item.tooltipTitle.length > 0 ? item.tooltipTitle
                : (item.title.length > 0 ? item.title : item.id);
        if (item.tooltipDescription.length > 0) result += " • " + item.tooltipDescription;
        if (Config.options.tray.showItemId) result += "\n[" + item.id + "]";
        return result;
    }

    // Icons. Apps name freedesktop icons the current theme may not have
    // (blueman's bluetooth-symbolic isn't in Breeze): try the plain name, then
    // a Material symbol, rather than show the missing-icon checkerboard.
    function themeIconName(icon) {
        return icon.startsWith("image://icon/") && !icon.includes("?path=") ? icon.slice("image://icon/".length) : "";
    }
    // A source that will load, or "" (then try iconSymbol())
    function iconSource(icon) {
        const name = root.themeIconName(icon);
        if (name.length === 0 || Quickshell.hasThemeIcon(name))
            return icon;
        const plain = name.replace(/-symbolic$/, "");
        return plain !== name && Quickshell.hasThemeIcon(plain) ? Quickshell.iconPath(plain) : "";
    }
    readonly property var iconSymbols: [
        [/bluetooth.*(disabled|off)/, "bluetooth_disabled"], [/bluetooth/, "bluetooth"],
        [/addon|plugin|extension/, "extension"], [/exit|quit|shutdown/, "logout"],
        [/help|about/, "help"], [/find|search/, "search"], [/recent|history/, "history"],
        [/send|share/, "send"], [/settings|preferences|properties|configure/, "settings"],
        [/wireless|wifi/, "wifi"], [/network/, "lan"], [/device|computer/, "devices"],
        [/volume|audio/, "volume_up"], [/error/, "error"], [/warning/, "warning"],
        [/info/, "info"], [/open|folder/, "folder_open"], [/close|cancel/, "close"],
    ]
    function iconSymbol(icon, fallback) {
        const name = root.themeIconName(icon);
        if (name.length === 0)
            return "";
        const match = root.iconSymbols.find(([pattern]) => pattern.test(name));
        return match ? match[1] : (fallback ?? "");
    }

    // Pinning
    function pin(itemId) {
        var pins = Config.options.tray.pinnedItems;
        if (pins.includes(itemId)) return;
        Config.options.tray.pinnedItems.push(itemId);
    }
    function unpin(itemId) {
        Config.options.tray.pinnedItems = Config.options.tray.pinnedItems.filter(id => id !== itemId);
    }
    function isPinned(itemId) {
        for (var i = 0; i < root.pinnedItems.length; i++) {
            if (root.pinnedItems[i].id === itemId)
                return true;
        }
        return false;
    }

    function togglePin(itemId) {
        var pins = Config.options.tray.pinnedItems;
        if (pins.includes(itemId)) {
            unpin(itemId)
        } else {
            pin(itemId)
        }
    }

}
