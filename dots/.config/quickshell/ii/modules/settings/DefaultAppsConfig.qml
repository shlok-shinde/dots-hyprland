import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    // The app variables of hypr/hyprland/variables.lua, the shortcut that opens
    // each (its description there), the desktop categories its apps come from,
    // and the files and links it also opens system-wide
    readonly property var slots: [
        { name: "terminal", title: Translation.tr("Terminal"), icon: "terminal", shortcut: "App: Terminal", categories: ["TerminalEmulator"], mime: [] },
        { name: "fileManager", title: Translation.tr("File manager"), icon: "folder", shortcut: "App: File manager", categories: ["FileManager"], mime: ["inode/directory"] },
        { name: "browser", title: Translation.tr("Browser"), icon: "language", shortcut: "App: Browser", categories: ["WebBrowser"], mime: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"] },
        { name: "codeEditor", title: Translation.tr("Code editor"), icon: "code", shortcut: "App: Code editor", categories: ["IDE", "TextEditor"], mime: [] },
        { name: "textEditor", title: Translation.tr("Text editor"), icon: "edit_note", shortcut: "App: Text editor", categories: ["TextEditor"], mime: ["text/plain"] },
        { name: "officeSoftware", title: Translation.tr("Office"), icon: "description", shortcut: "App: Office software", categories: ["WordProcessor", "Spreadsheet", "Presentation"], mime: [] },
        { name: "taskManager", title: Translation.tr("Task manager"), icon: "monitor_heart", shortcut: "App: Task manager", categories: ["Monitor"], mime: [] },
        { name: "volumeMixer", title: Translation.tr("Volume mixer"), icon: "volume_up", shortcut: "App: Volume mixer", categories: ["Mixer"], mime: [] },
    ]

    function appsIn(categories) {
        return DesktopEntries.applications.values
            .filter(entry => !entry.noDisplay && !entry.runInTerminal && entry.categories.some(c => categories.includes(c)))
            .sort((a, b) => a.name.localeCompare(b.name));
    }
    // The entry's command line without its %u / %F placeholders
    function commandOf(entry) {
        return entry.execString.replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
    }
    function shortcutFor(description) {
        const bind = ShortcutSettings.defaults.find(b => b.description === description);
        return bind ? ShortcutSettings.effectiveKeys(bind.keys) : "";
    }

    ContentSection {
        icon: "apps"
        title: Translation.tr("Default apps")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("The app each shortcut opens. Automatic takes the first one installed of the usual ones. The browser, file manager and text editor also open links, folders and text files everywhere.")
        }
    }

    Repeater {
        model: page.slots
        delegate: ContentSection {
            id: slot
            required property var modelData
            readonly property var apps: page.appsIn(modelData.categories)
            readonly property string keys: page.shortcutFor(modelData.shortcut)
            icon: modelData.icon
            title: modelData.title

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                visible: slot.keys !== ""
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                text: Translation.tr("Opens with %1").arg(ShortcutSettings.label(slot.keys))
            }
            ConfigSelectionArray {
                currentValue: ShortcutSettings.appIds[slot.modelData.name] ?? (ShortcutSettings.apps[slot.modelData.name] ? "custom" : "")
                onSelected: newValue => {
                    if (newValue === "" || newValue === "custom") {
                        ShortcutSettings.setApp(slot.modelData.name, "", "");
                        return;
                    }
                    const entry = DesktopEntries.byId(newValue);
                    if (!entry) return;
                    ShortcutSettings.setApp(slot.modelData.name, page.commandOf(entry), entry.id);
                    if (slot.modelData.mime.length > 0)
                        ShortcutSettings.setSystemDefault(entry.id, slot.modelData.mime);
                }
                options: [
                    { displayName: Translation.tr("Automatic"), icon: "auto_awesome", value: "" },
                    ...slot.apps.map(entry => ({ displayName: entry.name, icon: "", value: entry.id }))
                ]
            }
        }
    }
}
