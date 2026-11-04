pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Settings > Shortcuts and Default apps: the keys each default shortcut uses and
 * the app each app shortcut opens. Kept in shortcuts.json; Hyprland reads them
 * from shortcuts.lua through hypr/hyprland/shortcuts.lua, which writes back every
 * default shortcut it bound, with its description, to keybinds.json.
 */
Singleton {
    id: root

    readonly property string dir: FileUtils.trimFileProtocol(`${Directories.state}/user/generated`)
    property var keys: ({})    // default keys (normalized) -> chosen keys, "" = off
    property var apps: ({})    // app variable (terminal, browser...) -> command
    property var appIds: ({})  // app variable -> desktop entry id it came from
    property var defaults: []  // [{ keys, description }] as Hyprland last bound them
    property bool loaded: false

    // The same keys written another way give the same id (as hypr/hyprland/shortcuts.lua)
    readonly property var modifierNames: ({ SUPER: "SUPER", WIN: "SUPER", MOD4: "SUPER", META: "SUPER", CTRL: "CTRL", CONTROL: "CTRL", SHIFT: "SHIFT", ALT: "ALT", MOD1: "ALT" })
    function normalize(combo) {
        const mods = {};
        let key = "";
        for (const raw of `${combo}`.split("+")) {
            const part = raw.trim();
            const mod = root.modifierNames[part.toUpperCase()];
            if (mod) mods[mod] = true;
            else if (part !== "") key = part.toLowerCase();
        }
        return [...["SUPER", "CTRL", "SHIFT", "ALT"].filter(m => mods[m]), key].join(" + ");
    }

    // As shown: a modifier on its own ("SUPER + SUPER_L") is just its name
    function label(combo) {
        return `${combo}`.replace(/^(SUPER|CTRL|SHIFT|ALT) \+ (Super|Control|Shift|Alt)_[LR]$/i, "$1");
    }

    function chosenKeys(defaultKeys) { // undefined when it keeps its default
        return root.keys[root.normalize(defaultKeys)];
    }
    function effectiveKeys(defaultKeys) {
        return root.chosenKeys(defaultKeys) ?? defaultKeys;
    }
    // Descriptions (or the keys, for undescribed ones) of the other shortcuts on these keys
    function conflicts(combo, exceptDefaultKeys) {
        const id = root.normalize(combo);
        if (combo === "" || id === root.normalize(exceptDefaultKeys)) return [];
        const out = [];
        for (const bind of root.defaults) {
            if (root.normalize(bind.keys) === root.normalize(exceptDefaultKeys)) continue;
            if (root.normalize(root.effectiveKeys(bind.keys)) === id) {
                const name = bind.description ?? bind.keys;
                if (!out.includes(name)) out.push(name);
            }
        }
        return out;
    }

    function setKeys(defaultKeys, combo) {
        const next = Object.assign({}, root.keys);
        const id = root.normalize(defaultKeys);
        if (combo !== "" && root.normalize(combo) === id) delete next[id];
        else next[id] = combo;
        root.keys = next;
        root.save();
    }
    function resetKeys(defaultKeys) {
        const next = Object.assign({}, root.keys);
        delete next[root.normalize(defaultKeys)];
        root.keys = next;
        root.save();
    }

    // command "" = back to the automatic choice (the first one installed)
    function setApp(name, command, desktopId) {
        const nextApps = Object.assign({}, root.apps);
        const nextIds = Object.assign({}, root.appIds);
        if (command === "") {
            delete nextApps[name];
            delete nextIds[name];
        } else {
            nextApps[name] = command;
            if (desktopId) nextIds[name] = desktopId; else delete nextIds[name];
        }
        root.apps = nextApps;
        root.appIds = nextIds;
        root.save();
    }
    // What opens links, folders or text files: desktop entry id -> its MIME types
    function setSystemDefault(desktopId, mimeTypes) {
        Quickshell.execDetached(["xdg-mime", "default", desktopId.endsWith(".desktop") ? desktopId : `${desktopId}.desktop`, ...mimeTypes]);
    }

    // While the page waits for new keys, no shortcut may run: an empty submap
    // (hypr/hyprland/shortcuts.lua). Left again on its own after 15 s, should
    // this app close before it does.
    function startCapture() {
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("nl_capture")']);
        Quickshell.execDetached(["sh", "-c", `sleep 15; [ "$(hyprctl submap)" = nl_capture ] && hyprctl dispatch 'hl.dsp.submap("reset")'`]);
    }
    function endCapture() {
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("reset")']);
    }

    function luaString(s) {
        return `"${`${s}`.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
    }
    function save() {
        stateFile.setText(JSON.stringify({ keys: root.keys, apps: root.apps, appIds: root.appIds }, null, 2) + "\n");
        const keyLines = Object.keys(root.keys).map(k => `    [${root.luaString(k)}] = ${root.luaString(root.keys[k])},`);
        const appLines = Object.keys(root.apps).map(k => `    ${k} = ${root.luaString(root.apps[k])},`);
        luaFile.setText(`-- written by the shell (Settings > Shortcuts, Default apps); read by hypr/hyprland/shortcuts.lua\nreturn {\n  keys = {\n${keyLines.join("\n")}\n  },\n  apps = {\n${appLines.join("\n")}\n  },\n}\n`);
        reloadTimer.restart();
    }
    Timer {
        id: reloadTimer
        interval: 150
        onTriggered: Quickshell.execDetached(["hyprctl", "reload"])
    }

    FileView {
        id: stateFile
        path: `${root.dir}/shortcuts.json`
        printErrors: false // it does not exist until something is changed
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.keys = saved.keys ?? {};
                root.apps = saved.apps ?? {};
                root.appIds = saved.appIds ?? {};
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
    FileView {
        id: luaFile
        path: `${root.dir}/shortcuts.lua`
        printErrors: false
    }
    FileView {
        id: defaultsFile
        path: `${root.dir}/keybinds.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.defaults = JSON.parse(text());
            } catch (e) {}
        }
    }
}
