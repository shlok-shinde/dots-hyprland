import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarLeft.hermesChat
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell

/**
 * The sidebar's AI page when Hermes Agent is installed: a chat with your own
 * Hermes (services/Hermes.qml), its tool calls and questions inline.
 */
Item {
    id: root
    property real padding: 4
    property var inputField: messageInputField
    property string commandPrefix: "/"

    property var suggestionList: []

    onActiveFocusChanged: {
        if (activeFocus)
            messageInputField.forceActiveFocus();
    }

    // Hermes starts the first time the sidebar opens, not at login
    Component.onCompleted: {
        if (GlobalStates.sidebarLeftOpen)
            Hermes.start();
    }
    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (GlobalStates.sidebarLeftOpen)
                Hermes.start();
        }
    }

    Keys.onPressed: event => {
        messageInputField.forceActiveFocus();
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                messageListView.contentY = Math.max(0, messageListView.contentY - messageListView.height / 2);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                messageListView.contentY = Math.min(messageListView.contentHeight - messageListView.height / 2, messageListView.contentY + messageListView.height / 2);
                event.accepted = true;
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O) {
            Hermes.newConversation();
        }
    }

    // Handled here; any other /command goes to Hermes, which has its own (/help lists them)
    property var localCommands: [
        {
            name: "new",
            description: Translation.tr("Start a new chat (the current one stays in Hermes' history)"),
            execute: args => Hermes.newConversation()
        },
        {
            name: "clear",
            description: Translation.tr("Start a new chat"),
            execute: args => Hermes.newConversation()
        },
        {
            name: "resume",
            description: Translation.tr("Go back to an earlier chat"),
            execute: args => {
                if (args.length === 0) {
                    Hermes.addNotice(Translation.tr("Usage: %1resume CHAT (pick one from the list)").arg(root.commandPrefix));
                    return;
                }
                Hermes.resumeConversation(args[0]);
            }
        },
        {
            name: "model",
            description: Translation.tr("Choose the model for this chat"),
            execute: args => {
                if (args.length === 0) {
                    Hermes.addNotice(Translation.tr("Model: %1\nChange it with %2model MODEL").arg(Hermes.currentModelId).arg(root.commandPrefix));
                    return;
                }
                Hermes.setModel(args[0]);
            }
        },
        {
            name: "stop",
            description: Translation.tr("Stop what Hermes is doing"),
            execute: args => Hermes.cancel()
        },
    ]

    function handleInput(inputText) {
        const text = inputText.trim();
        if (text.length === 0)
            return;
        if (text.startsWith(root.commandPrefix)) {
            const words = text.split(/\s+/);
            const command = root.localCommands.find(cmd => cmd.name === words[0].substring(1));
            if (command) {
                command.execute(words.slice(1));
                messageListView.positionViewAtEnd();
                return;
            }
        }
        Hermes.sendPrompt(text);
        messageListView.followOutput = true;
        messageListView.positionViewAtEnd();
    }

    function updateSuggestions() {
        const text = messageInputField.text;
        const words = text.trim().split(/\s+/);
        const typingArgument = words.length > 1 || text.endsWith(" ");
        const query = typingArgument ? (words[1] ?? "") : "";
        const fuzzy = (items, key) => Fuzzy.go(query, items.map(item => ({
                        name: Fuzzy.prepare(item[key]),
                        obj: item
                    })), {
                all: true,
                key: "name"
            }).map(result => result.obj);

        if (text.length === 0 || !text.startsWith(root.commandPrefix)) {
            root.suggestionList = [];
        } else if (text.startsWith(`${root.commandPrefix}model`) && typingArgument) {
            root.suggestionList = fuzzy(Hermes.models, "modelId").map(model => ({
                        name: `${root.commandPrefix}model ${model.modelId}`,
                        displayName: Hermes.shortModelName(model.modelId),
                        description: `${model.name}\n${model.description ?? ""}`
                    }));
        } else if (text.startsWith(`${root.commandPrefix}resume`) && typingArgument) {
            root.suggestionList = fuzzy(Hermes.sessions.map(session => Object.assign({
                            label: session.title ?? ""
                        }, session)), "label").map(session => ({
                        name: `${root.commandPrefix}resume ${session.sessionId}`,
                        displayName: session.label.length === 0 ? session.sessionId.slice(0, 8) : session.label.length > 32 ? `${session.label.slice(0, 31)}…` : session.label,
                        description: `${session.title ?? ""}\n${session.updatedAt ?? ""}`
                    }));
        } else if (!typingArgument) {
            const prefix = words[0].substring(1);
            const ours = root.localCommands.map(cmd => ({
                        name: cmd.name,
                        description: cmd.description
                    }));
            const hermesOwn = Hermes.commands.filter(cmd => !ours.some(own => own.name === cmd.name)).map(cmd => ({
                        name: cmd.name,
                        description: cmd.description + (cmd.hint ? `\n${root.commandPrefix}${cmd.name} ${cmd.hint}` : "")
                    }));
            root.suggestionList = [...ours, ...hermesOwn].filter(cmd => cmd.name.startsWith(prefix)).map(cmd => ({
                        name: `${root.commandPrefix}${cmd.name}`,
                        description: cmd.description
                    }));
        } else {
            root.suggestionList = [];
        }
    }

    component StatusItem: MouseArea {
        id: statusItem
        property string icon
        property string statusText
        property string description
        property real maximumTextWidth: 160
        hoverEnabled: true
        implicitHeight: statusItemRowLayout.implicitHeight
        implicitWidth: statusItemRowLayout.implicitWidth

        RowLayout {
            id: statusItemRowLayout
            spacing: 2
            MaterialSymbol {
                text: statusItem.icon
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.maximumWidth: statusItem.maximumTextWidth
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                text: statusItem.statusText
                color: Appearance.colors.colSubtext
                animateChange: true
            }
        }

        StyledToolTip {
            text: statusItem.description
            extraVisibleCondition: false
            alternativeVisibleCondition: statusItem.containsMouse
        }
    }

    component StatusSeparator: Rectangle {
        implicitWidth: 4
        implicitHeight: 4
        radius: implicitWidth / 2
        color: Appearance.colors.colOutlineVariant
    }

    Component {
        id: messageComponent
        HermesMessage {}
    }
    Component {
        id: toolCallComponent
        HermesToolCall {}
    }
    Component {
        id: permissionComponent
        HermesPermission {}
    }
    Component {
        id: planComponent
        HermesPlan {}
    }

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        Item {
            // Messages
            Layout.fillWidth: true
            Layout.fillHeight: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: messageListView.width
                    height: messageListView.height
                    radius: Appearance.rounding.small
                }
            }

            StyledRectangularShadow {
                z: 1
                target: statusBg
                opacity: messageListView.atYBeginning ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
            Rectangle {
                id: statusBg
                z: 2
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 4
                }
                implicitWidth: Math.min(statusRowLayout.implicitWidth + 10 * 2, parent.width - 8)
                implicitHeight: Math.max(statusRowLayout.implicitHeight, 38)
                radius: Appearance.rounding.normal - root.padding
                color: messageListView.atYBeginning ? Appearance.colors.colLayer2 : Appearance.colors.colLayer2Base
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                RowLayout {
                    id: statusRowLayout
                    anchors.centerIn: parent
                    spacing: 10

                    StatusItem {
                        icon: Hermes.busy ? "progress_activity" : Hermes.ready ? "neurology" : "hourglass_empty"
                        statusText: Hermes.ready ? Hermes.currentModelName : Hermes.starting ? Translation.tr("Starting…") : Translation.tr("Not running")
                        maximumTextWidth: 130
                        description: Hermes.ready ? Translation.tr("Model: %1\nChange it with %2model MODEL").arg(Hermes.currentModelId).arg(root.commandPrefix) : Translation.tr("Hermes starts when the sidebar opens")
                    }
                    StatusSeparator {
                        visible: Hermes.contextSize > 0
                    }
                    StatusItem {
                        visible: Hermes.contextSize > 0
                        icon: "data_usage"
                        statusText: Hermes.contextUsed >= 1000 ? `${Math.round(Hermes.contextUsed / 1000)}k` : `${Hermes.contextUsed}`
                        description: Translation.tr("Context in use: %1 of %2 tokens").arg(Hermes.contextUsed).arg(Hermes.contextSize)
                    }
                    StatusSeparator {
                        visible: Hermes.sessionTitle.length > 0
                    }
                    StatusItem {
                        visible: Hermes.sessionTitle.length > 0
                        icon: "forum"
                        statusText: Hermes.sessionTitle
                        maximumTextWidth: 110
                        description: Translation.tr("%1\nPast chats: %2resume").arg(Hermes.sessionTitle).arg(root.commandPrefix)
                    }
                }
            }

            ScrollEdgeFade {
                z: 1
                target: messageListView
                vertical: true
            }

            StyledListView { // Message list
                id: messageListView
                z: 0
                anchors.fill: parent
                spacing: 8
                popin: false
                topMargin: statusBg.implicitHeight + statusBg.anchors.topMargin * 2

                touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor * 1.4
                mouseScrollFactor: Config.options.interactions.scrolling.mouseScrollFactor * 1.4

                // Keep up with Hermes as it writes, unless you scrolled up to read
                property bool followOutput: true
                onContentYChanged: followOutput = contentY + height >= originY + contentHeight + bottomMargin - 80
                onContentHeightChanged: {
                    if (followOutput)
                        Qt.callLater(positionViewAtEnd);
                }

                add: null

                model: ScriptModel {
                    values: Hermes.entryIds
                }
                delegate: Loader {
                    id: entryLoader
                    required property var modelData
                    required property int index
                    readonly property var entry: Hermes.entryById[modelData]
                    anchors.left: parent?.left
                    anchors.right: parent?.right
                    sourceComponent: {
                        switch (entryLoader.entry?.kind) {
                        case "tool":
                            return toolCallComponent;
                        case "permission":
                            return permissionComponent;
                        case "plan":
                            return planComponent;
                        default:
                            return messageComponent;
                        }
                    }
                    onLoaded: {
                        item.entry = entryLoader.entry;
                        if (entryLoader.entry?.kind === "assistant") {
                            // A reply that goes on after a tool call or plan belongs to the same turn
                            const previous = entryLoader.index > 0 ? Hermes.entryById[Hermes.entryIds[entryLoader.index - 1]] : null;
                            item.showHeader = !previous || previous.kind === "user" || previous.kind === "notice";
                        }
                    }
                }
            }

            PagePlaceholder {
                z: 2
                shown: Hermes.entryIds.length === 0
                icon: "neurology"
                title: "Hermes"
                description: Hermes.starting ? Translation.tr("Starting Hermes…") : Translation.tr("Your agent, with its tools,\nmemory and skills\n%1 for commands\nCtrl+O to expand the sidebar\nCtrl+P to pin it, Ctrl+D to detach it").arg(root.commandPrefix)
                shape: MaterialShape.Shape.PixelCircle
            }

            ScrollToBottomButton {
                z: 3
                target: messageListView
            }
        }

        DescriptionBox {
            text: root.suggestionList[suggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        FlowButtonGroup { // Suggestions
            id: suggestions
            visible: root.suggestionList.length > 0 && messageInputField.text.length > 0
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: suggestionRepeater
                model: {
                    suggestions.selectedIndex = 0;
                    return root.suggestionList.slice(0, 10);
                }
                delegate: ApiCommandButton {
                    id: commandButton
                    required property var modelData
                    required property int index
                    colBackground: suggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                    bounce: false
                    contentItem: StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                        text: commandButton.modelData.displayName ?? commandButton.modelData.name
                    }
                    onHoveredChanged: {
                        if (commandButton.hovered)
                            suggestions.selectedIndex = index;
                    }
                    onClicked: suggestions.acceptSuggestion(modelData.name)
                }
            }

            function acceptSuggestion(word) {
                // Suggestions carry the whole command line ("/model x"), so they replace it
                messageInputField.text = word + " ";
                messageInputField.cursorPosition = messageInputField.text.length;
                messageInputField.forceActiveFocus();
            }

            function acceptSelectedWord() {
                if (suggestions.selectedIndex >= 0 && suggestions.selectedIndex < suggestionRepeater.count)
                    suggestions.acceptSuggestion(root.suggestionList[suggestions.selectedIndex].name);
            }
        }

        Rectangle { // Input area
            id: inputWrapper
            Layout.fillWidth: true
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.bottomMargin + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + 5, 45)
            clip: true

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            RowLayout { // Input field and send button
                id: inputFieldRowLayout
                anchors {
                    bottom: commandButtonsRow.top
                    left: parent.left
                    right: parent.right
                    bottomMargin: 5
                }
                spacing: 0

                ScrollView {
                    id: inputScrollView
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.height * 3 / 5, messageInputField.height)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    StyledTextArea {
                        id: messageInputField
                        anchors.fill: parent
                        wrapMode: TextArea.Wrap
                        padding: 10
                        color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                        placeholderText: Hermes.busy ? Translation.tr("Message Hermes (it reads it when it can)") : Translation.tr('Message Hermes... "%1" for commands').arg(root.commandPrefix)
                        background: null

                        onTextChanged: {
                            if (text.startsWith(`${root.commandPrefix}resume`))
                                Hermes.refreshSessions();
                            root.updateSuggestions();
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                suggestions.acceptSelectedWord();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up && suggestions.visible) {
                                suggestions.selectedIndex = Math.max(0, suggestions.selectedIndex - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down && suggestions.visible) {
                                suggestions.selectedIndex = Math.min(root.suggestionList.length - 1, suggestions.selectedIndex + 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    messageInputField.insert(messageInputField.cursorPosition, "\n");
                                } else {
                                    const inputText = messageInputField.text;
                                    messageInputField.clear();
                                    root.handleInput(inputText);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape && Hermes.busy && messageInputField.text.length === 0) {
                                Hermes.cancel();
                                event.accepted = true;
                            }
                        }
                    }
                }

                RippleButton { // Send, or stop while Hermes works
                    id: sendButton
                    readonly property bool stopMode: Hermes.busy && messageInputField.text.length === 0
                    Layout.alignment: Qt.AlignBottom
                    Layout.rightMargin: 5
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.small
                    enabled: stopMode || messageInputField.text.length > 0
                    toggled: enabled

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (sendButton.stopMode) {
                                Hermes.cancel();
                                return;
                            }
                            const inputText = messageInputField.text;
                            messageInputField.clear();
                            root.handleInput(inputText);
                        }
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: 22
                        color: sendButton.enabled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2Disabled
                        text: sendButton.stopMode ? "stop" : "arrow_upward"
                    }

                    StyledToolTip {
                        text: sendButton.stopMode ? Translation.tr("Stop (Esc)") : Translation.tr("Send")
                    }
                }
            }

            RowLayout { // Controls
                id: commandButtonsRow
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 5
                    leftMargin: 10
                    rightMargin: 5
                }
                spacing: 4

                ApiInputBoxIndicator {
                    icon: "neurology"
                    text: "Hermes"
                    tooltipText: Translation.tr("Hermes Agent, with your own provider, tools, memory and skills\nIts settings: hermes setup / hermes config")
                }

                Item {
                    Layout.fillWidth: true
                }

                ButtonGroup {
                    padding: 0

                    Repeater {
                        model: [
                            {
                                name: "",
                                sendDirectly: false
                            },
                            {
                                name: "resume",
                                sendDirectly: false
                            },
                            {
                                name: "new",
                                sendDirectly: true
                            },
                        ]
                        delegate: ApiCommandButton {
                            required property var modelData
                            property string commandRepresentation: `${root.commandPrefix}${modelData.name}`
                            buttonText: commandRepresentation
                            downAction: () => {
                                if (modelData.sendDirectly) {
                                    root.handleInput(commandRepresentation);
                                    messageInputField.text = "";
                                    return;
                                }
                                messageInputField.text = commandRepresentation + (modelData.name.length > 0 ? " " : "");
                                messageInputField.cursorPosition = messageInputField.text.length;
                                messageInputField.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }
}
