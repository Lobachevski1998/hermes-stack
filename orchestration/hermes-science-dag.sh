#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'TXT'
Usage:
  hermes-science-dag [--mode analysis|compute] "Goal"

Modes:

  analysis
      Science + Genio
            |
          Audit
            |
          Review
            |
      Director final

      Use when the question is mathematical/conceptual and does not
      require new numerical implementation or experimental evidence.

  compute
      Science + Genio
            |
          Runner
            |
          Audit
            |
          Review
            |
      Director final

      Use when new Julia implementation, numerical experiments,
      robustness testing or computational evidence are required.

Default:
  compute

For independent parallel reasoning without Runner, the lighter alternative is:
  hermes-science-swarm "Goal"
TXT
}

MODE="compute"

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    --mode)
        if [ "$#" -lt 3 ]; then
            usage
            exit 1
        fi
        MODE="$2"
        shift 2
        ;;
esac

case "$MODE" in
    analysis)
        ;;
    compute|full)
        MODE="compute"
        ;;
    *)
        echo "Invalid mode: $MODE"
        echo
        usage
        exit 1
        ;;
esac

if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

GOAL="$*"
STAMP="$(date +%Y%m%d%H%M%S)"
FLOW="science-dag-$STAMP"

get_id() {
    python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])'
}

echo "Creating scientific DAG"
echo "Mode : $MODE"
echo "Goal : $GOAL"
echo

SCI_JSON="$(hermes kanban create \
    "Science analysis — $GOAL" \
    --assignee science \
    --body "Analyze only the scoped scientific/mathematical question. Preserve provenance and epistemic distinctions. Use the smallest sufficient analysis. Do not expand into tangential theory or experiments not needed for the requested conclusion. Return the compact Scientific Kanban Handoff." \
    --idempotency-key "$FLOW-science" \
    --max-runtime 45m \
    --max-retries 2 \
    --json)"

SCI="$(printf '%s' "$SCI_JSON" | get_id)"

GEN_JSON="$(hermes kanban create \
    "Independent reasoning — $GOAL" \
    --assignee genio \
    --body "Independently analyze the scoped problem from first principles. Seek hidden assumptions, counterexamples, alternate derivations and discriminating tests only where materially useful. Do not reproduce Science and do not expand beyond requested depth. Return the compact Scientific Kanban Handoff." \
    --idempotency-key "$FLOW-genio" \
    --max-runtime 45m \
    --max-retries 2 \
    --json)"

GEN="$(printf '%s' "$GEN_JSON" | get_id)"

RUN=""

if [ "$MODE" = "compute" ]; then

    RUN_JSON="$(hermes kanban create \
        "Numerical implementation — $GOAL" \
        --assignee runner \
        --parent "$SCI" \
        --parent "$GEN" \
        --body "Use the completed Science and Genio results as upstream evidence. Implement or execute only the computation required by the scoped task. Follow REUSE -> IMPLEMENT CORRECTLY -> ROBUSTIFY -> VALIDATE ROBUSTNESS -> OPTIMIZE -> REVALIDATE. Do not add unrelated experiments. Preserve parameters, failures and provenance." \
        --idempotency-key "$FLOW-runner" \
        --max-runtime 60m \
        --max-retries 2 \
        --json)"

    RUN="$(printf '%s' "$RUN_JSON" | get_id)"
fi

AUD_PARENTS=(
    --parent "$SCI"
    --parent "$GEN"
)

if [ -n "$RUN" ]; then
    AUD_PARENTS+=(--parent "$RUN")
fi

AUD_JSON="$(hermes kanban create \
    "Adversarial audit — $GOAL" \
    --assignee audit \
    "${AUD_PARENTS[@]}" \
    --body "Audit only the material claims needed to resolve the scoped task. Check provenance, signs, exponents, units, assumptions, numerical robustness and epistemic status. Do not manufacture objections or expand into unrelated review. Return explicit verdicts with concrete evidence." \
    --idempotency-key "$FLOW-audit" \
    --max-runtime 45m \
    --max-retries 2 \
    --json)"

AUD="$(printf '%s' "$AUD_JSON" | get_id)"

REV_PARENTS=(
    --parent "$SCI"
    --parent "$GEN"
)

if [ -n "$RUN" ]; then
    REV_PARENTS+=(--parent "$RUN")
fi

REV_PARENTS+=(--parent "$AUD")

REV_JSON="$(hermes kanban create \
    "Final scientific review — $GOAL" \
    --assignee review \
    "${REV_PARENTS[@]}" \
    --body "Integrate only the material evidence required by the original task. Classify claims as ACCEPTED_WITHIN_SCOPE, PROVISIONAL, CHANGES_REQUIRED, UNRESOLVED, REJECTED or SUPERSEDED. Do not add new speculative theory. State exactly what may and may not be promoted to canonical knowledge." \
    --idempotency-key "$FLOW-review" \
    --max-runtime 45m \
    --max-retries 2 \
    --json)"

REV="$(printf '%s' "$REV_JSON" | get_id)"

FINAL_JSON="$(hermes kanban create \
    "Director integration — $GOAL" \
    --assignee director \
    --parent "$REV" \
    --body "Produce the smallest sufficient final integration from Review. Preserve accepted, provisional, unresolved, rejected and superseded status exactly. Do not independently strengthen claims or add unnecessary analysis." \
    --idempotency-key "$FLOW-director" \
    --max-runtime 30m \
    --max-retries 2 \
    --json)"

FINAL="$(printf '%s' "$FINAL_JSON" | get_id)"

echo
echo "Created:"
echo "  science   $SCI"
echo "  genio     $GEN"

if [ -n "$RUN" ]; then
    echo "  runner    $RUN"
fi

echo "  audit     $AUD"
echo "  review    $REV"
echo "  director  $FINAL"

echo
echo "Expected initial state:"
echo "  Science + Genio : ready"

if [ "$MODE" = "compute" ]; then
    echo "  Runner          : todo"
fi

echo "  Audit           : todo"
echo "  Review          : todo"
echo "  Director final  : todo"

echo
echo "Gateway was NOT started."
echo
echo "Inspect:"
echo "  hermes kanban list"
