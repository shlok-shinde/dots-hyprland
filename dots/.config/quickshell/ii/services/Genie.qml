pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import QtQuick
import Quickshell
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

    function minimizeClient(client) {
        if (!client?.address)
            return;
        Quickshell.execDetached(["hyprctl", "hyprglass", "minimize", `address:${client.address}`, ...root.rectArgs(root.iconRect(client.class))]);
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

    IpcHandler {
        target: "genie"

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
