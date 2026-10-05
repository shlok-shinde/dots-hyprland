pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Hermes asking you something before it goes on (its clarify tool): one to
 * five questions, each with choices to pick (one, or several), or your own
 * answer. A single question with choices answers on the first click.
 */
Rectangle {
    id: root
    property var entry
    readonly property var questions: entry?.questions ?? []
    readonly property string answer: entry?.answer ?? ""
    readonly property bool answered: answer.length > 0
    readonly property bool oneClick: questions.length === 1 && !(questions[0].multi_select ?? false) && (questions[0].choices ?? []).length > 0

    // qid -> the picked choice (single), [choices] (multi); and qid -> typed answer
    property var picks: ({})
    property var typed: ({})

    function answerFor(question) {
        const own = (root.typed[question.qid] ?? "").trim();
        if (question.multi_select ?? false) {
            const chosen = [...(root.picks[question.qid] ?? [])];
            if (own.length > 0)
                chosen.push(own);
            return chosen.length > 0 ? chosen : null;
        }
        if (own.length > 0)
            return own;
        return root.picks[question.qid] ?? null;
    }
    readonly property bool anyAnswer: {
        root.picks;
        root.typed;
        return root.questions.some(question => root.answerFor(question) !== null);
    }

    function pick(question, choice) {
        const picks = Object.assign({}, root.picks);
        if (question.multi_select ?? false) {
            const chosen = picks[question.qid] ?? [];
            picks[question.qid] = chosen.includes(choice) ? chosen.filter(c => c !== choice) : [...chosen, choice];
        } else {
            picks[question.qid] = choice;
            const typed = Object.assign({}, root.typed);
            delete typed[question.qid];
            root.typed = typed;
        }
        root.picks = picks;
        if (root.oneClick)
            root.submit();
    }

    function submit() {
        const answers = {};
        for (const question of root.questions) {
            const value = root.answerFor(question);
            if (value !== null)
                answers[question.qid] = value;
        }
        Hermes.answerClarify(root.entry, answers);
    }

    function shownAnswer(question) {
        const value = (root.entry?.answers ?? {})[question.qid];
        if (value === undefined || value === null)
            return Translation.tr("(skipped)");
        return (Array.isArray(value) ? value.join(", ") : `${value}`).replace(/\s*\(Recommended\)$/, "");
    }

    implicitHeight: columnLayout.implicitHeight + 10 * 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: root.answered ? 0 : 1
    border.color: Appearance.colors.colPrimary

    ColumnLayout {
        id: columnLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 10
        }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: "contact_support"
                iconSize: Appearance.font.pixelSize.larger
                color: root.answered ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: root.questions.length > 1 ? Translation.tr("Hermes has %1 questions").arg(root.questions.length) : Translation.tr("Hermes asks")
            }
        }

        Repeater {
            model: root.questions
            delegate: ColumnLayout {
                id: questionItem
                required property var modelData
                readonly property var choices: modelData.choices ?? []
                readonly property bool multi: modelData.multi_select ?? false
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    text: questionItem.modelData.question
                }

                StyledText { // how it was answered
                    Layout.fillWidth: true
                    visible: root.answered
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    text: root.answer === "cancelled" ? Translation.tr("No answer") : `→ ${root.shownAnswer(questionItem.modelData)}`
                }

                StyledText {
                    visible: !root.answered && questionItem.multi
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: Translation.tr("Pick any")
                }

                Flow {
                    Layout.fillWidth: true
                    visible: !root.answered && questionItem.choices.length > 0
                    spacing: 5
                    Repeater {
                        model: questionItem.choices
                        delegate: RippleButton {
                            id: choiceButton
                            required property string modelData
                            readonly property bool recommended: modelData.endsWith("(Recommended)")
                            readonly property string label: modelData.replace(/\s*\(Recommended\)$/, "")
                            toggled: {
                                const pick = root.picks[questionItem.modelData.qid];
                                return questionItem.multi ? (pick ?? []).includes(modelData) : pick === modelData;
                            }
                            implicitHeight: 34
                            implicitWidth: Math.min(choiceText.implicitWidth + 14 * 2, columnLayout.width)
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer2
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            onClicked: root.pick(questionItem.modelData, modelData)

                            contentItem: StyledText {
                                id: choiceText
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, choiceButton.width - 14 * 2)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: choiceButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                                text: (questionItem.multi && choiceButton.toggled ? "✓ " : "") + choiceButton.label + (choiceButton.recommended ? " ★" : "")
                            }
                            StyledToolTip {
                                text: choiceButton.recommended ? Translation.tr("%1\n(Hermes recommends this one)").arg(choiceButton.label) : choiceButton.label
                            }
                        }
                    }
                }

                MaterialTextField { // your own answer ("Other"), or the only way to answer an open question
                    id: ownAnswer
                    Layout.fillWidth: true
                    visible: !root.answered
                    placeholderText: questionItem.choices.length > 0 ? Translation.tr("Or your own answer") : Translation.tr("Your answer")
                    onTextChanged: {
                        const typed = Object.assign({}, root.typed);
                        typed[questionItem.modelData.qid] = text;
                        root.typed = typed;
                        if (text.trim().length > 0 && !questionItem.multi && root.picks[questionItem.modelData.qid] !== undefined) {
                            const picks = Object.assign({}, root.picks);
                            delete picks[questionItem.modelData.qid];
                            root.picks = picks;
                        }
                    }
                    onAccepted: {
                        if (root.anyAnswer)
                            root.submit();
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.answered
            spacing: 5
            Item {
                Layout.fillWidth: true
            }
            DialogButton {
                buttonText: Translation.tr("Skip")
                colEnabled: Appearance.colors.colSubtext
                onClicked: Hermes.answerClarify(root.entry, null)
            }
            DialogButton {
                buttonText: Translation.tr("Send")
                enabled: root.anyAnswer
                onClicked: root.submit()
            }
        }
    }
}
