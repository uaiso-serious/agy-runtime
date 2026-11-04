#!/bin/bash
# CMD padrão: inicia o Antigravity CLI (agy).
# O contexto gerado pelo scm-runtime (repo, CLI, issue, comments) é injetado em ~/.gemini/config/rules/runtime-*.md
#   ISSUE_PROMPT    prompt inicial (padrão: resolver a issue, só no AUTONOMOUS_MODE com ISSUE_ID; no interativo abre com -i se definido)
#   ISSUE_COMMENTS  true = inclui /tmp/issue/comments.md no contexto
#   MODEL           modelo do agy (--model), quando definido
#   AUTONOMOUS_MODE true = roda sem interação (agy -p)
set -euo pipefail

if [ "${DIND:-0}" = "1" ]; then
  if command -v start-dockerd.sh >/dev/null 2>&1 && SOCK="$(start-dockerd.sh)"; then
    export DOCKER_HOST="unix://$SOCK"
  else
    echo "DIND=1 mas o dockerd falhou; mantendo DOCKER_HOST=${DOCKER_HOST:-padrão}" >&2
  fi
fi

# Garante settings/onboarding e o plugin langfuse-observability mesmo quando ~/.gemini é montado por volume externo
mkdir -p "$HOME/.gemini/antigravity-cli/cache" "$HOME/.gemini/config/plugins"
if [[ ! -f "$HOME/.gemini/antigravity-cli/settings.json" ]]; then
  cat > "$HOME/.gemini/antigravity-cli/settings.json" <<'EOF'
{
  "colorScheme": "colorblind-friendly dark",
  "trustedWorkspaces": [
    "/workspace"
  ]
}
EOF
fi
if [[ ! -f "$HOME/.gemini/antigravity-cli/cache/onboarding.json" ]]; then
  cat > "$HOME/.gemini/antigravity-cli/cache/onboarding.json" <<'EOF'
{
  "consumerOnboardingComplete": true,
  "enterpriseOnboardingComplete": false,
  "onboardingComplete": true
}
EOF
fi
if [[ ! -d "$HOME/.gemini/config/plugins/langfuse-observability" ]]; then
  agy plugin install https://github.com/uaiso-serious/agy-langfuse-plugin
fi

RULES_DIR="$HOME/.gemini/config/rules"
mkdir -p "$RULES_DIR"
rm -f "$RULES_DIR"/runtime-*.md

install_rule() { # $1=origem $2=nome-destino
  local src="$1" dst="$RULES_DIR/$2"
  [[ -s "$src" ]] || return 0
  {
    echo "---"
    echo "trigger: always_on"
    echo "---"
    echo
    cat "$src"
  } > "$dst"
}

install_rule /tmp/repo/repo.md  runtime-01-repo.md
install_rule /tmp/repo/cli.md   runtime-02-cli.md
if [[ -n "${ISSUE_ID:-}" ]]; then
  install_rule /tmp/issue/issue.md runtime-03-issue.md
  if [[ "${ISSUE_COMMENTS:-false}" == "true" ]]; then
    install_rule /tmp/issue/comments.md runtime-04-comments.md
  fi
fi

# tags e user_id do trace no Langfuse (plugin langfuse-observability)
co_author="${GIT_CO_AUTHOR:-}"
co_author="${co_author##*<}"
co_author="${co_author%%>*}"
mode=interactive
[[ "${AUTONOMOUS_MODE:-false}" == "true" ]] && mode=autonomous
export AGY_LANGFUSE_TRACE_TAGS="${AGY_LANGFUSE_TRACE_TAGS:-mode:${mode}}"
export CC_LANGFUSE_TRACE_TAGS="${CC_LANGFUSE_TRACE_TAGS:-mode:${mode}}"
# user_id do trace: LANGFUSE_USER_ID já definido > e-mail do co-autor > GIT_USER_EMAIL
export LANGFUSE_USER_ID="${LANGFUSE_USER_ID:-${co_author:-${GIT_USER_EMAIL:-}}}"

ISSUE_PROMPT="${ISSUE_PROMPT:-}"
if [[ -z "$ISSUE_PROMPT" && -n "${ISSUE_ID:-}" && "${AUTONOMOUS_MODE:-false}" == "true" ]]; then
  ISSUE_PROMPT="Resolva a issue #${ISSUE_ID}."
fi

args=(--dangerously-skip-permissions)
[[ -n "${MODEL:-}" ]] && args+=(--model "$MODEL")

if [[ "${AUTONOMOUS_MODE:-false}" == "true" ]]; then
  [[ -n "$ISSUE_PROMPT" ]] || { echo "AUTONOMOUS_MODE=true exige ISSUE_ID ou ISSUE_PROMPT" >&2; exit 1; }
  exec agy "${args[@]}" -p "$ISSUE_PROMPT" "$@"
fi

if [[ -n "$ISSUE_PROMPT" ]]; then
  exec agy "${args[@]}" -i "$ISSUE_PROMPT" "$@"
fi

exec agy "${args[@]}" "$@"
