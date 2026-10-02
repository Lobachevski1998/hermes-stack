#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: hermes-science-swarm \"Goal\""
    exit 1
fi

GOAL="$*"

hermes kanban swarm \
    "$GOAL" \
    --worker "science:Scientific analysis" \
    --worker "genio:Independent first-principles analysis" \
    --verifier audit \
    --synthesizer review \
    --created-by director \
    --json
