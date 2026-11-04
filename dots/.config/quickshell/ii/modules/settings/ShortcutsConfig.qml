import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    // The default shortcuts with a description, by category ("App: Browser" -> App)
    readonly property var categories: {
        const groups = [];
        const seen = {};
        for (const bind of ShortcutSettings.defaults) {
            if (!bind.description) continue;
            const split = bind.description.indexOf(":");
            const category = split > 0 ? bind.description.slice(0, split).trim() : Translation.tr("Other");
            const name = split > 0 ? bind.description.slice(split + 1).trim() : bind.description;
            if (!(category in seen)) {
                seen[category] = groups.length;
                groups.push({ name: category, binds: [] });
            }
            groups[seen[category]].binds.push({ keys: bind.keys, name: name, description: bind.description });
        }
        return groups;
    }
    readonly property var categoryIcons: ({ App: "apps", Shell: "dashboard", Window: "select_window", Workspace: "workspaces", Media: "music_note", Screen: "monitor", Session: "power_settings_new", Utilities: "build" })

    property string capturing: "" // the default keys of the shortcut waiting for new ones

    ContentSection {
        icon: "keyboard"
        title: Translation.tr("Shortcuts")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("Click a shortcut, then press the keys you want for it. Esc cancels, Backspace turns it off. Changes apply right away.")
        }
        StyledText {
            Layout.fillWidth: true
            visible: ShortcutSettings.defaults.length === 0
            wrapMode: Text.Wrap
            text: Translation.tr("The list comes from Hyprland when it loads its config. Reload it (or log in again) to see it here.")
        }
    }

    Repeater {
        model: page.categories
        delegate: ContentSection {
            id: section
            required property var modelData
            icon: page.categoryIcons[modelData.name] ?? "keyboard_command_key"
            title: modelData.name

            Repeater {
                model: section.modelData.binds
                delegate: ColumnLayout {
                    id: row
                    required property var modelData
                    readonly property string current: ShortcutSettings.effectiveKeys(modelData.keys)
                    readonly property bool changed: ShortcutSettings.chosenKeys(modelData.keys) !== undefined
                    readonly property var clashes: ShortcutSettings.conflicts(current, modelData.keys)
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            elide: Text.ElideRight
                            text: row.modelData.name
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        RippleButton {
                            id: keyButton
                            readonly property bool waiting: page.capturing === row.modelData.keys
                            implicitHeight: 34
                            implicitWidth: Math.max(keyText.implicitWidth + 28, 90)
                            buttonRadius: Appearance.rounding.full
                            focusPolicy: Qt.NoFocus // the page keeps the keys; a click on it again cancels
                            toggled: waiting
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                            onClicked: waiting ? page.cancelCapture() : page.beginCapture(row.modelData.keys)
                            contentItem: StyledText {
                                id: keyText
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: keyButton.waiting ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                                text: keyButton.waiting ? Translation.tr("Press keys…") : (row.current === "" ? Translation.tr("Off") : ShortcutSettings.label(row.current))
                            }
                        }
                        RippleButton {
                            visible: row.changed
                            implicitWidth: 34
                            implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            onClicked: ShortcutSettings.resetKeys(row.modelData.keys)
                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                text: "restart_alt"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledToolTip {
                                text: Translation.tr("Back to %1").arg(ShortcutSettings.label(row.modelData.keys))
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        visible: row.clashes.length > 0
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colError
                        text: Translation.tr("Also used by: %1").arg(row.clashes.join(", "))
                    }
                }
            }
        }
    }

    // ── capturing keys ─────────────────────────────────────────────────────
    property bool sawKey: false // a non-modifier key went down during this capture
    property var held: []       // modifiers whose keys are down (some sources don't set event.modifiers)

    // The page takes the keys meanwhile
    function beginCapture(defaultKeys) {
        page.capturing = defaultKeys;
        page.sawKey = false;
        page.held = [];
        ShortcutSettings.startCapture();
        captureTimeout.restart();
        page.forceActiveFocus();
    }
    Keys.onPressed: event => page.keyPressed(event)
    Keys.onReleased: event => page.keyReleased(event)
    onActiveFocusChanged: if (!activeFocus) page.cancelCapture()
    function cancelCapture() {
        if (page.capturing === "") return;
        page.capturing = "";
        captureTimeout.stop();
        ShortcutSettings.endCapture();
    }
    function finishCapture(combo) {
        const target = page.capturing;
        page.cancelCapture();
        ShortcutSettings.setKeys(target, combo);
    }
    Timer {
        id: captureTimeout
        interval: 12000
        onTriggered: page.cancelCapture()
    }
    Component.onDestruction: page.cancelCapture()

    readonly property var modifierKeys: ({
        [Qt.Key_Meta]: "SUPER", [Qt.Key_Super_L]: "SUPER", [Qt.Key_Super_R]: "SUPER", [Qt.Key_Hyper_L]: "SUPER", [Qt.Key_Hyper_R]: "SUPER",
        [Qt.Key_Control]: "CTRL", [Qt.Key_Shift]: "SHIFT", [Qt.Key_Alt]: "ALT", [Qt.Key_AltGr]: "ALT",
    })
    function modifierPrefix(modifiers) {
        const on = {
            SUPER: (modifiers & Qt.MetaModifier) !== 0, CTRL: (modifiers & Qt.ControlModifier) !== 0,
            SHIFT: (modifiers & Qt.ShiftModifier) !== 0, ALT: (modifiers & Qt.AltModifier) !== 0,
        };
        return ["SUPER", "CTRL", "SHIFT", "ALT"].filter(m => on[m] || page.held.includes(m));
    }
    // Qt key -> the key name Hyprland takes (xkb's)
    readonly property var keyNames: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Escape]: "Escape", [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab",
        [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
        [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down", [Qt.Key_Space]: "Space", [Qt.Key_Print]: "Print",
        [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
        [Qt.Key_Period]: "Period", [Qt.Key_Comma]: "Comma", [Qt.Key_Slash]: "Slash", [Qt.Key_Backslash]: "Backslash",
        [Qt.Key_Minus]: "Minus", [Qt.Key_Equal]: "Equal", [Qt.Key_BracketLeft]: "BracketLeft", [Qt.Key_BracketRight]: "BracketRight",
        [Qt.Key_Semicolon]: "Semicolon", [Qt.Key_Apostrophe]: "Apostrophe", [Qt.Key_QuoteLeft]: "Grave",
    })
    function keyName(event) {
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) return String.fromCharCode(event.key);
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) return String.fromCharCode(event.key);
        if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) return `F${event.key - Qt.Key_F1 + 1}`;
        if (event.key in page.keyNames) return page.keyNames[event.key];
        return `code:${event.nativeScanCode}`; // shifted symbols and the rest: the physical key
    }

    function keyPressed(event) {
        if (page.capturing === "") return;
        event.accepted = true;
        const modifier = page.modifierKeys[event.key];
        if (modifier) { // wait for the key, or the release
            if (!page.held.includes(modifier)) page.held = [...page.held, modifier];
            return;
        }
        const mods = page.modifierPrefix(event.modifiers);
        if (mods.length === 0 && event.key === Qt.Key_Escape) {
            page.cancelCapture();
            return;
        }
        if (mods.length === 0 && event.key === Qt.Key_Backspace) {
            page.finishCapture("");
            return;
        }
        page.sawKey = true;
        page.finishCapture([...mods, page.keyName(event)].join(" + "));
    }
    // SUPER pressed and let go on its own
    function keyReleased(event) {
        if (page.capturing === "") return;
        const modifier = page.modifierKeys[event.key];
        if (modifier) page.held = page.held.filter(m => m !== modifier);
        if (page.sawKey) return;
        event.accepted = true;
        if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R)
            // Qt often names both Meta: the right one is evdev key 126 (+8 under xkb)
            page.finishCapture(event.key === Qt.Key_Super_R || event.nativeScanCode === 134 ? "SUPER + SUPER_R" : "SUPER + SUPER_L");
    }
}
