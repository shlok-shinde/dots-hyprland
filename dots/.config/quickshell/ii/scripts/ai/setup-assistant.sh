#!/usr/bin/env bash
# Nothing Liquid: install and set up the left sidebar's agent. The sidebar runs
# this in a terminal when you pick one there, and follows it through $STATUS
# ("<agent> running", then "ok" or "failed").
#
#   setup-assistant.sh hermes     Hermes Agent (Nous Research): its installer, which
#                                 runs its own setup (provider, model, API key)
#   setup-assistant.sh openclaw   OpenClaw: installed into ~/.openclaw (its own Node.js,
#                                 no root), then its onboarding (provider, model, and the
#                                 gateway as a user service), with the gateway's chat
#                                 endpoint on: that's what the sidebar talks to
set -uo pipefail

agent="${1:-}"
STATUS="${XDG_RUNTIME_DIR:-/tmp}/nothing-liquid-assistant-setup"

say() { printf '\n\033[1;31m●\033[0m \033[1m%s\033[0m\n' "$*"; }
finish() { # ok | failed
  echo "$agent $1" > "$STATUS"
  trap - INT
  if [[ "$1" == ok ]]; then
    say "Done: $name is in the sidebar now."
  else
    say "That didn't finish. Pick $name in the sidebar again to retry."
  fi
  read -rp "Press Enter to close this window. " _
  exit 0
}

case "$agent" in
  hermes) name="Hermes Agent" ;;
  openclaw) name="OpenClaw" ;;
  *) echo "usage: $0 hermes|openclaw" >&2; exit 2 ;;
esac
trap 'finish failed' INT
echo "$agent running" > "$STATUS"

if [[ "$agent" == hermes ]]; then
  say "Installing Hermes Agent (Nous Research) from hermes-agent.nousresearch.com"
  say "It asks which AI provider and model to use, and for that provider's API key."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash || finish failed
  export PATH="$HOME/.local/bin:$PATH"
  command -v hermes >/dev/null || finish failed
else
  say "Installing OpenClaw from openclaw.ai, into ~/.openclaw (with its own Node.js)"
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install-cli.sh | bash -s -- --no-onboard || finish failed
  export PATH="$HOME/.openclaw/bin:$PATH"
  command -v openclaw >/dev/null || finish failed
  # `openclaw` in your terminals too (~/.local/bin is on PATH here)
  [[ -e "$HOME/.local/bin/openclaw" ]] || { mkdir -p "$HOME/.local/bin" && ln -s "$HOME/.openclaw/bin/openclaw" "$HOME/.local/bin/openclaw"; }

  # The sidebar talks to the gateway's OpenAI-style endpoint, which is off by
  # default (set now, while no gateway runs: config changes need it stopped)
  openclaw config set gateway.http.endpoints.chatCompletions.enabled true >/dev/null 2>&1 || true
  say "Setting it up: the AI provider, model and API key, and its gateway (which the sidebar talks to)"
  openclaw onboard --install-daemon || finish failed
  if [[ "$(openclaw config get gateway.http.endpoints.chatCompletions.enabled 2>/dev/null)" != true ]]; then
    say "Turning on the gateway's chat endpoint, for the sidebar"
    openclaw gateway stop
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      systemctl --user is-active --quiet openclaw-gateway.service || break
      sleep 1
    done
    openclaw config set gateway.http.endpoints.chatCompletions.enabled true || finish failed
    openclaw gateway start || finish failed
  fi
fi
finish ok
