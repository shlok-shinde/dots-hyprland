import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * The sidebar's AI page before it has an agent: pick Hermes Agent, OpenClaw
 * or nothing. An agent is installed and set up in a terminal
 * (Assistant.setup); this page follows it and gives way to the chat.
 */
Item {
    id: root
    property Item inputField: null // (the sidebar focuses a page's input; this one has none)

    readonly property string agentName: Assistant.names[Assistant.settingUp] ?? ""

    component OptionButton: RippleButton {
        id: option
        required property string symbol
        required property string heading
        required property string blurb
        Layout.fillWidth: true
        implicitHeight: optionRow.implicitHeight + 24
        buttonRadius: Appearance.rounding.normal
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active

        contentItem: RowLayout {
            id: optionRow
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 12
            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: option.symbol
                iconSize: Appearance.font.pixelSize.hugeass
                color: Appearance.colors.colOnLayer2
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: option.heading
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }
                StyledText {
                    Layout.fillWidth: true
                    text: option.blurb
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    ColumnLayout { // Pick one
        visible: Assistant.settingUp === ""
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: 16
        }
        spacing: 10

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "neurology"
            shape: MaterialShape.Shape.PixelCircle
            padding: 12
            iconSize: 48
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Pick your assistant")
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.larger
                variableAxes: Appearance.font.variableAxes.title
            }
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
            text: Assistant.choice !== "" && Assistant.choice !== "none"
                ? Translation.tr("%1 isn't installed on this computer.").arg(Assistant.names[Assistant.choice])
                : Translation.tr("An AI agent that lives in this sidebar.\nYou can change this later in Settings.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.Wrap
        }

        OptionButton {
            symbol: "neurology"
            heading: "Hermes Agent"
            blurb: Translation.tr("Nous Research's agent: tools, memory and skills, and it learns as you use it. Uses the AI provider you pick.")
            onClicked: Assistant.choose("hermes")
        }
        OptionButton {
            symbol: "pets"
            heading: "OpenClaw"
            blurb: Translation.tr("A personal agent with its own tools, memory and skills, running on this computer. Uses the AI provider you pick.")
            onClicked: Assistant.choose("openclaw")
        }
        OptionButton {
            symbol: "block"
            heading: Translation.tr("Nothing")
            blurb: Translation.tr("No assistant. The sidebar keeps its other pages.")
            onClicked: Assistant.choose("none")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 6
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("An agent installs in a terminal window and asks for your AI provider and its API key. A few minutes, online.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.Wrap
        }
    }

    ColumnLayout { // Its setup, in the terminal
        visible: Assistant.settingUp !== ""
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: 16
        }
        spacing: 10

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: Assistant.setupFailed ? "error" : "terminal"
            shape: MaterialShape.Shape.PixelCircle
            padding: 12
            iconSize: 48
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Assistant.setupFailed ? Translation.tr("%1 didn't finish setting up").arg(root.agentName)
                : Translation.tr("Setting up %1").arg(root.agentName)
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.larger
                variableAxes: Appearance.font.variableAxes.title
            }
            color: Appearance.colors.colOnLayer1
            wrapMode: Text.Wrap
        }
        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
            text: Assistant.setupFailed ? Translation.tr("The terminal window says what went wrong.")
                : Translation.tr("Answer its questions in the terminal window.\nThis page turns into the chat when it's done.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            DialogButton {
                buttonText: Assistant.setupFailed ? Translation.tr("Try again") : Translation.tr("Open the terminal again")
                onClicked: Assistant.setup(Assistant.settingUp)
            }
            DialogButton {
                buttonText: Translation.tr("Pick another")
                onClicked: Assistant.cancelSetup()
            }
        }
    }
}
