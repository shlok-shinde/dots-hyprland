import QtQuick

/**
 * OpenClaw's gateway (its OpenAI-style chat endpoint). OpenClaw is the agent:
 * its own persona, model, tools and memory, so the sidebar's system prompt,
 * tools and temperature stay out of the request. The gateway's token is read
 * from OpenClaw's config when each request runs.
 */
OpenAiApiStrategy {
    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        return {
            "model": model.model,
            "messages": messages.map(message => ({
                "role": message.role,
                "content": message.rawContent,
            })),
            "stream": true,
        };
    }

    // OPENCLAW_GATEWAY_TOKEN if it's set (as the gateway itself accepts), else
    // gateway.auth.token from the config (OpenClaw writes it as plain JSON; its
    // own CLI reads it if the file was hand-edited into JSON5)
    function finalizeScriptContent(scriptContent: string): string {
        const tokenSetup = `
config="\${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
token="\${OPENCLAW_GATEWAY_TOKEN:-}"
[ -n "$token" ] || token="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["gateway"]["auth"]["token"])' "$config" 2>/dev/null)"
[ -n "$token" ] || token="$(PATH="$HOME/.openclaw/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH" openclaw config get gateway.auth.token 2>/dev/null)"
export API_KEY="$token"
`;
        const lines = scriptContent.split("\n");
        return [lines[0], tokenSetup, ...lines.slice(1)].join("\n");
    }

    // A request that got no answer at all: the gateway isn't running, or its
    // chat endpoint is off
    function onRequestFinished(message) {
        if (message.rawContent.trim().length === 0) {
            const hint = "**OpenClaw didn't answer.** Is its gateway running? In a terminal: `openclaw gateway status`, and `openclaw gateway start` to start it.";
            message.rawContent = hint;
            message.content = hint;
        } else if (message.rawContent.includes("Not Found")) {
            const hint = "\n\nThe gateway's chat endpoint looks off. Turn it on:\n```\nopenclaw config set gateway.http.endpoints.chatCompletions.enabled true\nopenclaw gateway restart\n```";
            message.rawContent += hint;
            message.content += hint;
        }
        return {};
    }
}
