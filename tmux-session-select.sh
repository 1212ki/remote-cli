#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  tmux-session-select.sh --prefix <name> --mode <create_or_attach|attach_only> [--workdir <dir>]

Environment:
  CODEX_HOME  (required) e.g. /mnt/c/Users/<you>/.codex
  NPM_CACHE   (required) e.g. /mnt/c/Users/<you>/.npm-cache
  CODEX_NO_ATTACH (optional) if set, will not attach (useful for non-interactive calls)
USAGE
}

prefix=""
mode=""
workdir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      prefix="${2:-}"; shift 2 ;;
    --mode)
      mode="${2:-}"; shift 2 ;;
    --workdir)
      workdir="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

if [[ -z "$prefix" || -z "$mode" ]]; then
  usage
  exit 2
fi

if [[ -z "${CODEX_HOME:-}" || -z "${NPM_CACHE:-}" ]]; then
  echo "CODEX_HOME and NPM_CACHE must be set." >&2
  exit 2
fi

if [[ "$mode" != "create_or_attach" && "$mode" != "attach_only" ]]; then
  echo "Invalid --mode: $mode" >&2
  exit 2
fi

no_attach="${CODEX_NO_ATTACH:-}"

tmux_setup() {
  tmux set -g mouse on
  tmux setw -g aggressive-resize on
  tmux set -g history-limit 200000
  tmux bind-key s copy-mode
  tmux bind-key R refresh-client -S
  tmux bind-key A resize-window -A

  # Keep Codex + MCP state under the Windows home mount (writable in restricted sandboxes)
  tmux setenv -g CODEX_HOME "$CODEX_HOME"
  tmux setenv -g NPM_CACHE "$NPM_CACHE"
  tmux setenv -g NPM_CONFIG_CACHE "$NPM_CACHE"
  tmux setenv -g npm_config_cache "$NPM_CACHE"
}

regex_escape() {
  # Escape regex metacharacters.
  sed -e 's/[].[^$*+?{}()|\\/]/\\&/g'
}

list_sessions() {
  local re
  re="$(printf '%s' "$prefix" | regex_escape)"
  tmux ls -F '#S' 2>/dev/null \
    | grep -E "^${re}([0-9]+)?$" \
    | sort -V || true
}

next_session_name() {
  if ! tmux has-session -t "$prefix" 2>/dev/null; then
    printf '%s\n' "$prefix"
    return 0
  fi
  local i=2
  while tmux has-session -t "${prefix}${i}" 2>/dev/null; do
    i=$((i + 1))
  done
  printf '%s\n' "${prefix}${i}"
}

start_session() {
  local name="$1"

  if [[ -n "$workdir" ]]; then
    # Keep the session alive even if codex exits.
    tmux new-session -d -s "$name" bash -lc 'export CODEX_HOME="$1"; export NPM_CACHE="$2"; export NPM_CONFIG_CACHE="$2"; export npm_config_cache="$2"; cd -- "$3"; codex; exec bash -l' bash "$CODEX_HOME" "$NPM_CACHE" "$workdir"
  else
    tmux new-session -d -s "$name" bash -lc 'export CODEX_HOME="$1"; export NPM_CACHE="$2"; export NPM_CONFIG_CACHE="$2"; export npm_config_cache="$2"; codex; exec bash -l' bash "$CODEX_HOME" "$NPM_CACHE"
  fi
}

sessions_raw="$(list_sessions)"

if [[ -z "$sessions_raw" ]]; then
  if [[ "$mode" == "attach_only" ]]; then
    echo "No tmux sessions found for prefix: $prefix" >&2
    exit 1
  fi

  target="$prefix"
  start_session "$target"
  tmux_setup

  if [[ -n "$no_attach" ]]; then
    printf '%s\n' "$target"
    exit 0
  fi

  exec tmux attach -t "$target"
fi

mapfile -t sessions < <(printf '%s\n' "$sessions_raw")

tmux_setup

if [[ -n "$no_attach" ]]; then
  printf '%s\n' "${sessions[@]}"
  exit 0
fi

if [[ "$mode" == "attach_only" ]]; then
  if [[ ${#sessions[@]} -eq 1 ]]; then
    exec tmux attach -t "${sessions[0]}"
  fi

  PS3="Select tmux session (${prefix}): "
  select opt in "${sessions[@]}"; do
    [[ -n "${opt:-}" ]] || { echo "Invalid selection" >&2; continue; }
    exec tmux attach -t "$opt"
  done
fi

# create_or_attach
PS3="Select tmux session (${prefix}): "
select opt in new "${sessions[@]}"; do
  [[ -n "${opt:-}" ]] || { echo "Invalid selection" >&2; continue; }
  if [[ "$opt" == "new" ]]; then
    target="$(next_session_name)"
    start_session "$target"
    exec tmux attach -t "$target"
  fi
  exec tmux attach -t "$opt"
done