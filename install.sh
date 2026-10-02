#!/usr/bin/env bash
# install.sh — deploy the hermes-stack personas + orchestration to a Hermes runtime.
# Default is DRY RUN; pass --apply to write. --force overwrites existing files.
# Never touches memories/, auth.json, state db, sessions or logs.
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APPLY=0; FORCE=0
for a in "$@"; do
    case "$a" in
        --apply) APPLY=1 ;;
        --force) FORCE=1 ;;
        -h|--help) sed -n '1,8p' "$0"; exit 0 ;;
        *) echo "unknown flag: $a" >&2; exit 1 ;;
    esac
done
command -v hermes >/dev/null || echo "warning: hermes CLI not on PATH; profiles will still be written" >&2

PROFILES=(director science genio runner audit review)
BIN="${HOME}/.local/bin"

run() {
    if [[ $APPLY -eq 1 ]]; then
        eval "$@"
    else
        echo "DRY: $*"
    fi
}

copy_if() {  # src dst
    if [[ -e "$2" && $FORCE -eq 0 ]]; then
        echo "skip (exists, use --force): $2"
    else
        run "install -Dm600 '$1' '$2'"
    fi
}

for p in "${PROFILES[@]}"; do
    base="${HOME}/.hermes/profiles/${p}"
    copy_if "$DIR/profiles/$p/SOUL.md" "$base/SOUL.md"
    if [[ ! -f "$base/config.yaml" ]]; then
        run "install -Dm600 '$DIR/profiles/$p/config.example.yaml' '$base/config.yaml'"
        echo "  → remember: fill real values (ntfy topic placeholder: HERMES_NTFY_TOPIC) in $base/config.yaml"
    else
        echo "skip config (exists): $base/config.yaml"
    fi
done

for s in hermes-science-dag hermes-science-swarm; do
    copy_if "$DIR/orchestration/$s.sh" "$BIN/$s"
    [[ $APPLY -eq 1 ]] && chmod +x "$BIN/$s" 2>/dev/null || true
done

if [[ $APPLY -eq 0 ]]; then
    echo
    echo "Nothing written. Re-run with --apply to deploy."
else
    echo
    echo "Deployed. Add to your shell rc if you want the mode aliases:"
    echo "  alias hermes-dag=\"\$HOME/.local/bin/hermes-science-dag\""
    echo "  alias hermes-swarm=\"\$HOME/.local/bin/hermes-science-swarm\""
fi
