import QtQuick

/**
 * One item in the Hermes sidebar's transcript: a message, a tool call, one of
 * Hermes' questions (approval, clarify, password), the agent's todo list, a
 * command's output, or a note from the sidebar itself.
 */
QtObject {
    property string kind // "user" | "assistant" | "tool" | "permission" | "clarify" | "secret" | "plan" | "output" | "notice"
    property bool done: false

    // user, assistant, notice, output
    property string text
    property string thought
    property string label // assistant: what it answers when it isn't the main turn (/btw, /bg); output: the command
    property bool queued: false // user: sent while Hermes was busy, waiting its turn
    property bool steered: false // user: folded into the running turn instead
    // What MessageTextBlock and friends render: the reasoning as a think block, then the reply
    readonly property string content: {
        const reply = text.replace(/^\s+/, "");
        if (thought.length === 0)
            return reply;
        const closed = reply.length > 0 || done;
        return `<think>\n${thought}${closed ? "\n</think>\n\n" : ""}${reply}`;
    }
    readonly property bool thinking: false // read by MessageTextBlock

    // tool calls and questions
    property string toolCallId
    property string name // the tool
    property string title
    property string toolKind
    property string status // in_progress | completed | failed
    property string input
    property string output

    // questions: the request to answer, and how it went
    property var requestId
    property var options: [] // permission: [{ optionId, name, kind }]
    property var questions: [] // clarify: [{ qid, question, choices, multi_select }]
    property var answers: ({}) // clarify: qid -> answer, as sent
    property string envVar // secret: the variable it is for (empty for sudo)
    property string answer // what was picked ("" while waiting), or "cancelled"

    // plan
    property var planEntries: [] // [{ content, status }]
}
