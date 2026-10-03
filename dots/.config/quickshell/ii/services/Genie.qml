pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

/**
 * Magic-lamp minimize/restore, done by the compositor's glass plugin
 * (`hyprctl hyprglass minimize|restore`). The shell's part is knowing where
 * each app's dock icon is, so windows pour into, and come back out of, their own icon.
 */
Singleton {
    id: root

    readonly property string workspaceName: "special:minimized"
    // The glass plugin is loaded (without it the dock keeps end-4's own clicks)
    property bool available: false

    // appId (lowercase) -> function returning the icon's global rect {x, y, w, h}
    property var iconRectProviders: ({})

    function registerIcon(appId, provider) {
        root.iconRectProviders[appId.toLowerCase()] = provider;
    }

    function unregisterIcon(appId, provider) {
        const key = appId.toLowerCase();
        if (root.iconRectProviders[key] === provider)
            delete root.iconRectProviders[key];
    }

    function iconRect(appId) {
        const provider = root.iconRectProviders[(appId ?? "").toLowerCase()];
        return provider ? provider() : null;
    }

    function isMinimized(toplevel) {
        return HyprlandData.clientForToplevel(toplevel)?.workspace?.name === root.workspaceName;
    }

    function rectArgs(rect) {
        return rect ? [`${Math.round(rect.x)}`, `${Math.round(rect.y)}`, `${Math.round(rect.w)}`, `${Math.round(rect.h)}`] : [];
    }

    function minimizeClient(client, rect) {
        if (!client?.address)
            return;
        Quickshell.execDetached(["hyprctl", "hyprglass", "minimize", `address:${client.address}`, ...root.rectArgs(rect ?? root.iconRect(client.class))]);
    }

    function minimizeToplevel(toplevel, rect) {
        root.minimizeClient(HyprlandData.clientForToplevel(toplevel), rect);
    }

    // Start an app whose first window opens out of `rect` (its dock icon). The
    // plugin matches the window by class: the app id, the desktop entry's id
    // and its StartupWMClass all count.
    function launch(entry, appId, rect) {
        if (!entry)
            return;
        const classes = [appId, entry.id, entry.startupClass].filter(c => (c ?? "").length > 0).map(c => c.toLowerCase());
        if (root.available && rect && classes.length > 0)
            Quickshell.execDetached(["hyprctl", "hyprglass", "launch", [...new Set(classes)].join(","), ...root.rectArgs(rect)]);
        entry.execute();
    }

    function restoreToplevel(toplevel, rect) {
        const client = HyprlandData.clientForToplevel(toplevel);
        if (!client?.address)
            return;
        Quickshell.execDetached(["hyprctl", "hyprglass", "restore", `address:${client.address}`, ...root.rectArgs(rect ?? root.iconRect(client.class))]);
    }

    function minimizeActive() {
        const active = ToplevelManager.activeToplevel;
        if (!active?.activated)
            return;
        root.minimizeClient(HyprlandData.clientForToplevel(active));
    }

    function restoreLast() {
        // the plugin remembers the order; with no address it restores the latest
        Quickshell.execDetached(["hyprctl", "hyprglass", "restore"]);
    }

    Process {
        id: pluginCheck
        running: true
        command: ["hyprctl", "plugin", "list", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.available = JSON.parse(text).some(p => p.name === "hyprglass");
                } catch (e) {
                    root.available = false;
                }
            }
        }
    }
    Connections { // the plugin loads (or goes) with a config reload
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                pluginCheck.running = true;
        }
    }

    // A click on an app's dock icon. With the plugin the icon is a taskbar
    // button through the magic lamp: the app opens out of it, the window in
    // front goes back into it, one behind others comes forward, and a minimized
    // one comes back out. `cycle` picks among several windows to bring forward.
    function clickApp(app, entry, rect, cycle) {
        const toplevels = app?.toplevels ?? [];
        if (toplevels.length === 0) {
            root.launch(entry, app?.appId ?? "", rect);
            return;
        }
        const minimized = toplevels.filter(t => root.isMinimized(t));
        const shown = toplevels.filter(t => !root.isMinimized(t));
        if (root.available) {
            const front = shown.find(t => t.activated);
            if (front) {
                root.minimizeToplevel(front, rect);
                return;
            }
            if (shown.length === 0) {
                root.restoreToplevel(minimized[minimized.length - 1], rect);
                return;
            }
        }
        const windows = shown.length > 0 ? shown : toplevels;
        windows[Math.max(0, cycle ?? 0) % windows.length].activate();
    }

    IpcHandler {
        target: "genie"

        // What a click on the app's dock icon does (for keybinds)
        function clickApp(appId: string): void {
            const app = TaskbarApps.apps.find(a => a.appId === appId.toLowerCase());
            root.clickApp(app ?? { appId: appId, toplevels: [] }, DesktopEntries.heuristicLookup(appId), root.iconRect(appId), 0);
        }

        function minimizeActive(): void {
            root.minimizeActive();
        }

        function restoreLast(): void {
            root.restoreLast();
        }

        // Restore the most recently minimized window of an app, out of its dock icon.
        function restoreApp(appId: string): void {
            const app = TaskbarApps.apps.find(a => a.appId === appId.toLowerCase());
            const minimized = (app?.toplevels ?? []).filter(t => root.isMinimized(t));
            if (minimized.length > 0)
                root.restoreToplevel(minimized[minimized.length - 1], null);
        }
    }
}
