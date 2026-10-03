import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    forceWidth: true

    Process {
        id: randomWallProc
        property string status: ""
        property string scriptPath: `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`
        command: ["bash", "-c", FileUtils.trimFileProtocol(randomWallProc.scriptPath)]
        stdout: SplitParser {
            onRead: data => {
                randomWallProc.status = data.trim();
            }
        }
    }

    component SmallLightDarkPreferenceButton: RippleButton {
        id: smallLightDarkPreferenceButton
        required property bool dark
        property color colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        padding: 5
        Layout.fillWidth: true
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: Appearance.colors.colLayer2
        onClicked: {
            Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`]);
        }
        contentItem: Item {
            anchors.centerIn: parent
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: 30
                    text: dark ? "dark_mode" : "light_mode"
                    color: smallLightDarkPreferenceButton.colText
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: dark ? Translation.tr("Dark") : Translation.tr("Light")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: smallLightDarkPreferenceButton.colText
                }
            }
        }
    }

    // Wallpaper selection
    ContentSection {
        icon: "format_paint"
        title: Translation.tr("Wallpaper & Colors")
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true

            Item {
                implicitWidth: 340
                implicitHeight: 200
                
                StyledImage {
                    id: wallpaperPreview
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: Config.options.background.wallpaperPath
                    cache: false
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 360
                            height: 200
                            radius: Appearance.rounding.normal
                        }
                    }
                }
            }

            ColumnLayout {
                RippleButtonWithIcon {
                    enabled: !randomWallProc.running
                    visible: Config.options.policies.weeb === 1
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "ifl"
                    mainText: randomWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: Konachan")
                    onClicked: {
                        randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`;
                        randomWallProc.running = true;
                    }
                    StyledToolTip {
                        text: Translation.tr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/Wallpapers")
                    }
                }
                RippleButtonWithIcon {
                    enabled: !randomWallProc.running
                    visible: Config.options.policies.weeb === 1
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "ifl"
                    mainText: randomWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: osu! seasonal")
                    onClicked: {
                        randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_osu_wall.sh`;
                        randomWallProc.running = true;
                    }
                    StyledToolTip {
                        text: Translation.tr("Random osu! seasonal background\nImage is saved to ~/Pictures/Wallpapers")
                    }
                }
                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    materialIcon: "wallpaper"
                    StyledToolTip {
                        text: Translation.tr("Pick wallpaper image on your system")
                    }
                    onClicked: {
                        Quickshell.execDetached(`${Directories.wallpaperSwitchScriptPath}`);
                    }
                    mainContentComponent: Component {
                        RowLayout {
                            spacing: 10
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: Translation.tr("Choose file")
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            RowLayout {
                                spacing: 3
                                KeyboardKey {
                                    key: "Ctrl"
                                }
                                KeyboardKey {
                                    key: Config.options.cheatsheet.superKey ?? "󰖳"
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "+"
                                }
                                KeyboardKey {
                                    key: "T"
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    uniformCellSizes: true

                    SmallLightDarkPreferenceButton {
                        Layout.fillHeight: true
                        dark: false
                    }
                    SmallLightDarkPreferenceButton {
                        Layout.fillHeight: true
                        dark: true
                    }
                }
            }
        }

        ConfigSelectionArray {
            currentValue: Config.options.appearance.palette.type
            onSelected: newValue => {
                Config.options.appearance.palette.type = newValue;
                Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
            }
            options: [
                {
                    "value": "auto",
                    "displayName": Translation.tr("Auto")
                },
                {
                    "value": "scheme-content",
                    "displayName": Translation.tr("Content")
                },
                {
                    "value": "scheme-expressive",
                    "displayName": Translation.tr("Expressive")
                },
                {
                    "value": "scheme-fidelity",
                    "displayName": Translation.tr("Fidelity")
                },
                {
                    "value": "scheme-fruit-salad",
                    "displayName": Translation.tr("Fruit Salad")
                },
                {
                    "value": "scheme-monochrome",
                    "displayName": Translation.tr("Monochrome")
                },
                {
                    "value": "scheme-neutral",
                    "displayName": Translation.tr("Neutral")
                },
                {
                    "value": "scheme-rainbow",
                    "displayName": Translation.tr("Rainbow")
                },
                {
                    "value": "scheme-tonal-spot",
                    "displayName": Translation.tr("Tonal Spot")
                }
            ]
        }

        ConfigSwitch {
            buttonIcon: "ev_shadow"
            text: Translation.tr("Transparency")
            checked: Config.options.appearance.transparency.enable
            onCheckedChanged: {
                Config.options.appearance.transparency.enable = checked;
            }
        }
    }

    ContentSection {
        icon: "water_drop"
        title: Translation.tr("Liquid glass")

        ConfigSwitch {
            buttonIcon: "blur_on"
            text: Translation.tr("Liquid glass")
            checked: Config.options.appearance.liquidGlass.enable
            onCheckedChanged: {
                Config.options.appearance.liquidGlass.enable = checked;
            }
            StyledToolTip {
                text: Translation.tr("Glass windows, bar, dock and panels, drawn by the compositor")
            }
        }

        ContentSubsection {
            visible: Config.options.appearance.liquidGlass.enable
            title: Translation.tr("Look")

            ConfigSelectionArray {
                currentValue: Config.options.appearance.liquidGlass.mode
                onSelected: newValue => {
                    Config.options.appearance.liquidGlass.mode = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Clear"),
                        icon: "lens_blur",
                        value: "clear"
                    },
                    {
                        displayName: Translation.tr("Tinted"),
                        icon: "contrast",
                        value: "tinted"
                    }
                ]
            }
        }

        ConfigSlider {
            visible: Config.options.appearance.liquidGlass.enable && Config.options.appearance.liquidGlass.mode === "tinted"
            text: Translation.tr("Tint")
            buttonIcon: "opacity"
            from: 0.1
            to: 1
            value: Config.options.appearance.liquidGlass.tintAmount
            onValueChanged: {
                Config.options.appearance.liquidGlass.tintAmount = value;
            }
        }

        ConfigSlider {
            visible: Config.options.appearance.liquidGlass.enable
            text: Translation.tr("Edge highlights")
            buttonIcon: "highlight"
            from: 0
            to: 2
            stopIndicatorValues: [1]
            value: Config.options.appearance.liquidGlass.edgeHighlight
            onValueChanged: {
                Config.options.appearance.liquidGlass.edgeHighlight = value;
            }
        }

        ConfigSlider {
            visible: Config.options.appearance.liquidGlass.enable
            text: Translation.tr("Refraction")
            buttonIcon: "lens"
            from: 0
            to: 2
            stopIndicatorValues: [1]
            value: Config.options.appearance.liquidGlass.refraction
            onValueChanged: {
                Config.options.appearance.liquidGlass.refraction = value;
            }
        }

        ConfigRow {
            visible: Config.options.appearance.liquidGlass.enable
            uniform: true
            ConfigSwitch {
                buttonIcon: "toolbar"
                text: Translation.tr("Capsule bar")
                checked: Config.options.appearance.liquidGlass.capsuleBar
                onCheckedChanged: {
                    Config.options.appearance.liquidGlass.capsuleBar = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Each bar group is its own glass capsule. Off: one glass bar with a single border")
                }
            }
            ConfigSwitch {
                buttonIcon: "view_agenda"
                text: Translation.tr("Modular sidebar")
                checked: Config.options.appearance.liquidGlass.modularSidebar
                onCheckedChanged: {
                    Config.options.appearance.liquidGlass.modularSidebar = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Each card of the right sidebar is its own glass, like Control Center")
                }
            }
        }

        ContentSubsection {
            id: accentPicker
            title: Translation.tr("Accent colour")
            tooltip: Translation.tr("The active workspace and the bar's glyph. None: the theme's own colours")
            readonly property string current: Config.options.appearance.liquidGlass.accentColor
            readonly property var swatches: [
                { name: Translation.tr("Nothing red"), color: "#D71921" },
                { name: Translation.tr("Orange"), color: "#FF6A13" },
                { name: Translation.tr("Yellow"), color: "#F5C400" },
                { name: Translation.tr("Green"), color: "#2DBE6C" },
                { name: Translation.tr("Teal"), color: "#13B5B1" },
                { name: Translation.tr("Blue"), color: "#2F7CF6" },
                { name: Translation.tr("Purple"), color: "#9B5CF6" },
                { name: Translation.tr("Pink"), color: "#F0508C" },
                { name: Translation.tr("White"), color: "#F2F2F2" }
            ]

            RowLayout {
                spacing: 8
                Repeater {
                    model: accentPicker.swatches
                    delegate: RippleButton {
                        id: swatch
                        required property var modelData
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: 16
                        readonly property bool chosen: accentPicker.current.toLowerCase() === modelData.color.toLowerCase()
                        colBackground: modelData.color
                        colBackgroundHover: modelData.color
                        colRipple: ColorUtils.mix(modelData.color, "#ffffff", 0.7)
                        onClicked: Config.options.appearance.liquidGlass.accentColor = modelData.color
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: swatch.chosen ? "check" : ""
                            iconSize: 18
                            color: ColorUtils.mix(swatch.modelData.color, "#000000", 0.75)
                        }
                        StyledToolTip {
                            text: swatch.modelData.name
                        }
                    }
                }
                RippleButton {
                    id: noAccent
                    implicitHeight: 32
                    buttonRadius: 16
                    toggled: accentPicker.current === ""
                    colBackground: Appearance.colors.colLayer2
                    onClicked: Config.options.appearance.liquidGlass.accentColor = ""
                    contentItem: StyledText {
                        horizontalAlignment: Text.AlignHCenter
                        leftPadding: 10
                        rightPadding: 10
                        text: Translation.tr("None")
                        color: noAccent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                    }
                }
            }

            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Custom colour, e.g. #D71921")
                text: accentPicker.current
                onEditingFinished: {
                    const t = text.trim();
                    if (t === "")
                        Config.options.appearance.liquidGlass.accentColor = "";
                    else if (/^#?[0-9a-fA-F]{6}$/.test(t))
                        Config.options.appearance.liquidGlass.accentColor = t.startsWith("#") ? t.toUpperCase() : "#" + t.toUpperCase();
                }
            }
        }
    }

    ContentSection {
        icon: "screenshot_monitor"
        title: Translation.tr("Bar & screen")

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Bar position")
                ConfigSelectionArray {
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Top"),
                            icon: "arrow_upward",
                            value: 0 // bottom: false, vertical: false
                        },
                        {
                            displayName: Translation.tr("Left"),
                            icon: "arrow_back",
                            value: 2 // bottom: false, vertical: true
                        },
                        {
                            displayName: Translation.tr("Bottom"),
                            icon: "arrow_downward",
                            value: 1 // bottom: true, vertical: false
                        },
                        {
                            displayName: Translation.tr("Right"),
                            icon: "arrow_forward",
                            value: 3 // bottom: true, vertical: true
                        }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Bar style")

                ConfigSelectionArray {
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: newValue => {
                        Config.options.bar.cornerStyle = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("Hug"),
                            icon: "line_curve",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Float"),
                            icon: "page_header",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "toolbar",
                            value: 2
                        }
                    ]
                }
            }
        }

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Screen round corner")

                ConfigSelectionArray {
                    currentValue: Config.options.appearance.fakeScreenRounding
                    onSelected: newValue => {
                        Config.options.appearance.fakeScreenRounding = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("When not fullscreen"),
                            icon: "fullscreen_exit",
                            value: 2
                        }
                    ]
                }
            }
            
        }
    }

    NoticeBox {
        Layout.fillWidth: true
        text: Translation.tr('Not all options are available in this app. You should also check the config file by hitting the "Config file" button on the topleft corner or opening %1 manually.').arg(Directories.shellConfigPath)

        Item {
            Layout.fillWidth: true
        }
        RippleButtonWithIcon {
            id: copyPathButton
            property bool justCopied: false
            Layout.fillWidth: false
            buttonRadius: Appearance.rounding.small
            materialIcon: justCopied ? "check" : "content_copy"
            mainText: justCopied ? Translation.tr("Path copied") : Translation.tr("Copy path")
            onClicked: {
                copyPathButton.justCopied = true
                Quickshell.clipboardText = FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                revertTextTimer.restart();
            }
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
            colRipple: Appearance.colors.colPrimaryContainerActive

            Timer {
                id: revertTextTimer
                interval: 1500
                onTriggered: {
                    copyPathButton.justCopied = false
                }
            }
        }
    }
}
