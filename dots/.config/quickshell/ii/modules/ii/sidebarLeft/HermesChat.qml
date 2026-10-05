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
 * Hermes (services/Hermes.qml), its tool calls and questions inline. "/" opens
 * every command Hermes has (its TUI's and app's, and your skills), with
 * pickers for /resume and /model and Hermes' own completions for arguments.
 */
Item {
    id: root
    property real padding: 4
    property var inputField: messageInputField
    property string commandPrefix: "/"

    // [{ name: what goes in the box, displayName, description, category, run: send on pick, sessionId }]
    property var suggestionList: []
    property string pickerMode: "" // "", "commands", "sessions", "models", "arguments"

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

    Connections {
        target: Hermes
        function onPrefillRequested(text) {
            messageInputField.text = text;
            messageInputField.cursorPosition = text.length;
            messageInputField.forceActiveFocus();
        }
        function onSessionsChanged() {
            if (root.pickerMode === "sessions")
                root.updateSuggestions();
        }
        function onModelChoicesChanged() {
            if (root.pickerMode === "models")
                root.updateSuggestions();
        }
        function onCommandsChanged() {
            if (root.pickerMode === "commands")
                root.updateSuggestions();
        }
    }

    function handleInput(inputText) {
        if (inputText.trim().length === 0)
            return;
        Hermes.submit(inputText);
        messageListView.followOutput = true;
        messageListView.positionViewAtEnd();
    }

    function relativeTime(seconds) {
        const minutes = Math.round((Date.now() / 1000 - seconds) / 60);
        if (minutes < 1)
            return Translation.tr("just now");
        if (minutes < 60)
            return Translation.tr("%1 min ago").arg(minutes);
        if (minutes < 60 * 24)
            return Translation.tr("%1 h ago").arg(Math.round(minutes / 60));
        return Translation.tr("%1 days ago").arg(Math.round(minutes / 60 / 24));
    }

    // Best first: names that start with it, then names that contain it, then descriptions
    function rank(items, query, nameOf, descriptionOf) {
        const q = query.toLowerCase();
        if (q.length === 0)
            return items;
        const starts = [], contains = [], described = [];
        for (const item of items) {
            const name = nameOf(item).toLowerCase();
            if (name.startsWith(q))
                starts.push(item);
            else if (name.includes(q))
                contains.push(item);
            else if (descriptionOf(item).toLowerCase().includes(q))
                described.push(item);
        }
        return [...starts, ...contains, ...described];
    }

    property int completionRequest: 0
    Timer {
        id: completionTimer
        interval: 120
        onTriggered: {
            const text = messageInputField.text;
            const request = ++root.completionRequest;
            Hermes.complete(text, (items, replaceFrom) => {
                if (request !== root.completionRequest || messageInputField.text !== text)
                    return;
                root.suggestionList = items.map(item => ({
                            name: text.slice(0, replaceFrom) + item.text,
                            displayName: item.display ?? item.text,
                            description: item.meta ?? "",
                            run: false
                        }));
            });
        }
    }

    function updateSuggestions() {
        const text = messageInputField.text;
        if (!text.startsWith(root.commandPrefix) || !Hermes.isCommand(text) && text !== root.commandPrefix) {
            root.pickerMode = "";
            root.suggestionList = [];
            return;
        }
        const space = text.search(/\s/);
        if (space < 0) { // the command itself
            root.pickerMode = "commands";
            const typed = text.slice(1);
            root.suggestionList = root.rank(Hermes.commands, typed, c => c.name.slice(1), c => c.description).map(command => ({
                        name: command.name,
                        displayName: command.name,
                        description: command.description,
                        category: command.category,
                        run: !command.needsArgs
                    }));
            return;
        }
        const command = Hermes.resolveCommand(text.slice(1, space));
        const arg = text.slice(space + 1);
        if (command === "/resume" || command === "/sessions") {
            if (root.pickerMode !== "sessions")
                Hermes.refreshSessions();
            root.pickerMode = "sessions";
            root.suggestionList = root.rank(Hermes.sessions, arg.trim(), s => s.title ?? s.preview ?? "", s => `${s.preview ?? ""} ${s.id}`).map(session => ({
                        name: `/resume ${session.id}`,
                        displayName: (session.title ?? "").length > 0 ? session.title : (session.preview ?? "").length > 0 ? session.preview : session.id.slice(0, 8),
                        description: `${root.relativeTime(session.started_at ?? 0)} · ${Translation.tr("%1 messages").arg(session.message_count ?? 0)}${session.id === Hermes.storedSessionId ? " · " + Translation.tr("this chat") : ""}`,
                        sessionId: session.id,
                        run: true
                    }));
        } else if (command === "/model") {
            if (root.pickerMode !== "models")
                Hermes.refreshModels();
            root.pickerMode = "models";
            root.suggestionList = root.rank(Hermes.modelChoices, arg.trim(), m => m.model.split("/").pop(), m => `${m.model} ${m.providerName}`).map(model => ({
                        name: `/model ${model.value}`,
                        displayName: model.model,
                        description: model.providerName + (model.current ? ` · ${Translation.tr("current")}` : ""),
                        run: true
                    }));
        } else {
            root.pickerMode = "arguments";
            completionTimer.restart();
        }
    }

    // run: send it now (a picked chat, a model, a command without arguments); else fill the box
    function acceptSuggestion(item, run) {
        if (!item)
            return;
        if (run && item.run) {
            messageInputField.clear();
            root.handleInput(item.name);
            return;
        }
        messageInputField.text = item.name + " ";
        messageInputField.cursorPosition = messageInputField.text.length;
        messageInputField.forceActiveFocus();
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
    Component {
        id: clarifyComponent
        HermesClarify {}
    }
    Component {
        id: secretComponent
        HermesSecret {}
    }
    Component {
        id: outputComponent
        HermesOutput {}
    }
    Component {
        id: noticeComponent
        HermesNotice {}
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
                        case "clarify":
                            return clarifyComponent;
                        case "secret":
                            return secretComponent;
                        case "output":
                            return outputComponent;
                        case "notice":
                            return noticeComponent;
                        default:
                            return messageComponent;
                        }
                    }
                    onLoaded: {
                        item.entry = entryLoader.entry;
                        if (entryLoader.entry?.kind === "assistant") {
                            // A reply that goes on after a tool call or plan belongs to the same turn
                            const previous = entryLoader.index > 0 ? Hermes.entryById[Hermes.entryIds[entryLoader.index - 1]] : null;
                            item.showHeader = !previous || previous.kind === "user" || previous.kind === "notice" || previous.kind === "output" || (entryLoader.entry.label ?? "").length > 0;
                        }
                    }
                }
            }

            PagePlaceholder {
                z: 2
                shown: Hermes.entryIds.length === 0
                icon: "neurology"
                title: "Hermes"
                description: Hermes.starting ? Translation.tr("Starting Hermes…") : Translation.tr("Your agent, with its tools,\nmemory and skills\n%1 for all its commands\nCtrl+O to expand the sidebar\nCtrl+P to pin it, Ctrl+D to detach it").arg(root.commandPrefix)
                shape: MaterialShape.Shape.PixelCircle
            }

            ScrollToBottomButton {
                z: 3
                target: messageListView
            }
        }

        RowLayout { // What Hermes is doing
            Layout.fillWidth: true
            Layout.leftMargin: 6
            visible: Hermes.busy && Hermes.activity.length > 0 && !suggestionsBox.visible
            spacing: 6
            MaterialSymbol {
                text: "progress_activity"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
                RotationAnimation on rotation {
                    running: Hermes.busy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: Hermes.activity
            }
        }

        Rectangle { // Suggestions: commands, chats, models, a command's arguments
            id: suggestionsBox
            readonly property int rowHeight: 44
            Layout.fillWidth: true
            visible: root.suggestionList.length > 0 && messageInputField.text.length > 0
            implicitHeight: Math.min(root.suggestionList.length, 6) * rowHeight + 8
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2

            StyledListView {
                id: suggestionsView
                property bool keyboardPicked: false // moved with the arrow keys: Enter takes it
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                popin: false
                animateAppearance: false
                currentIndex: 0
                highlightMoveDuration: 0
                model: ScriptModel {
                    values: root.suggestionList
                    onValuesChanged: {
                        suggestionsView.currentIndex = 0;
                        suggestionsView.keyboardPicked = false;
                    }
                }
                delegate: RippleButton {
                    id: suggestionRow
                    required property var modelData
                    required property int index
                    readonly property bool selected: suggestionsView.currentIndex === index
                    width: suggestionsView.width
                    implicitHeight: suggestionsBox.rowHeight
                    buttonRadius: Appearance.rounding.small
                    colBackground: selected ? Appearance.colors.colSecondaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    onHoveredChanged: {
                        if (hovered)
                            suggestionsView.currentIndex = index;
                    }
                    onClicked: root.acceptSuggestion(modelData, true)

                    contentItem: RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 6
                        }
                        spacing: 6
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: root.pickerMode === "sessions" ? Appearance.font.family.main : Appearance.font.family.monospace
                                    color: suggestionRow.selected ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer2
                                    text: suggestionRow.modelData.displayName ?? suggestionRow.modelData.name
                                }
                                StyledText {
                                    visible: (suggestionRow.modelData.category ?? "").length > 0
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    text: suggestionRow.modelData.category ?? ""
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                elide: Text.ElideRight
                                font.family: Appearance.font.family.reading
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                text: (suggestionRow.modelData.description ?? "").split("\n")[0]
                            }
                        }
                        RippleButton { // forget a chat
                            visible: (suggestionRow.modelData.sessionId ?? "").length > 0 && suggestionRow.modelData.sessionId !== Hermes.storedSessionId
                            implicitWidth: 30
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.full
                            onClicked: Hermes.deleteConversation(suggestionRow.modelData.sessionId)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "delete"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colSubtext
                            }
                            StyledToolTip {
                                text: Translation.tr("Delete this chat")
                            }
                        }
                    }
                    StyledToolTip {
                        text: suggestionRow.modelData.description ?? ""
                        extraVisibleCondition: (suggestionRow.modelData.description ?? "").length > 48
                    }
                }
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
                        placeholderText: Hermes.busy ? Translation.tr("Message Hermes (Esc stops it)") : Translation.tr('Message Hermes... "%1" for commands').arg(root.commandPrefix)
                        background: null

                        onTextChanged: root.updateSuggestions()

                        function moveSuggestion(step) {
                            suggestionsView.currentIndex = Math.max(0, Math.min(root.suggestionList.length - 1, suggestionsView.currentIndex + step));
                            suggestionsView.positionViewAtIndex(suggestionsView.currentIndex, ListView.Contain);
                            suggestionsView.keyboardPicked = true;
                        }

                        // Enter takes the highlighted suggestion when you picked it, when a picker
                        // is open, or when what you typed isn't a whole command yet ("/us")
                        function enterTakesSuggestion() {
                            if (!suggestionsBox.visible)
                                return false;
                            if (suggestionsView.keyboardPicked || root.pickerMode === "sessions" || root.pickerMode === "models")
                                return true;
                            if (root.pickerMode === "commands") {
                                const typed = messageInputField.text.trim().toLowerCase();
                                return !Hermes.commands.some(command => command.name === typed) && Hermes.canon[typed] === undefined;
                            }
                            return false;
                        }

                        Keys.onPressed: event => handleKey(event)
                        function handleKey(event) {
                            if (event.key === Qt.Key_Tab && suggestionsBox.visible) {
                                root.acceptSuggestion(root.suggestionList[suggestionsView.currentIndex], false);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up && suggestionsBox.visible) {
                                moveSuggestion(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down && suggestionsBox.visible) {
                                moveSuggestion(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    messageInputField.insert(messageInputField.cursorPosition, "\n");
                                } else if (enterTakesSuggestion()) {
                                    root.acceptSuggestion(root.suggestionList[suggestionsView.currentIndex], true);
                                } else {
                                    const inputText = messageInputField.text;
                                    messageInputField.clear();
                                    root.handleInput(inputText);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape && suggestionsBox.visible) {
                                root.suggestionList = [];
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
