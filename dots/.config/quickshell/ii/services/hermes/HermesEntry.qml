import QtQuick

/**
 * One item in the Hermes sidebar's transcript: a message, a tool call, a
 * permission request, the agent's plan, or a note from the sidebar itself.
 */
QtObject {
    property string kind // "user" | "assistant" | "tool" | "permission" | "plan" | "notice"
    property bool done: false

    // user, assistant, notice
    property string messageId
    property string text
    property string thought
    property bool queued: false // user: sent while Hermes was busy, waiting its turn
    // What MessageTextBlock and friends render: the reasoning as a think block, then the reply
    readonly property string content: {
        const reply = text.replace(/^\s+/, "");
        if (thought.length === 0)
            return reply;
        const closed = reply.length > 0 || done;
        return `<think>\n${thought}${closed ? "\n</think>\n\n" : ""}${reply}`;
    }
    readonly property bool thinking: false // read by MessageTextBlock

    // tool calls and permission requests
    property string toolCallId
    property string title
    property string toolKind
    property string status // pending | in_progress | completed | failed
    property string input
    property string output

    // permission requests
    property var requestId
    property var options: [] // [{ optionId, name, kind }]
    property string answer // the optionId picked, or "cancelled"

    // plan
    property var planEntries: [] // [{ content, status, priority }]
}
