# hermes-stack — a six-persona scientific multi-agent stack for Hermes

My production agent-profile stack on [Hermes](https://github.com/hermes-agent)
(local runtime: `~/.hermes`): six coordinated personas plus the two
orchestration recipes I actually run. It grew out of real research workflows
(nonlinear dynamics / numerical evidence pipelines), so the discipline in the
personas is about **epistemic honesty, not prompt theater**: no consensus by
copy-paste, no numeric result promoted to theorem, conflicts surfaced instead
of silenced.

```
            ┌───────────┐          ┌─────────┐
 Goal ────▶ │  DIRECTOR │──route──▶│ SCIENCE │  mathematical / methodological reasoning
            │  (plan,   │          └─────────┘
            │  dispatch,│          ┌─────────┐
            │  integrate)│─hard──▶ │  GENIO  │  independent first-principles reasoning
            └───────────┘          └─────────┘
                  │                  ┌────────┐
                  ├──needs code──▶   │ RUNNER │  Julia/numeric implementation
                  │                  └────────┘
                  │                  ┌───────┐
                  └─verify claims──▶ │ AUDIT │  adversarial verification
                                     └───────┘
                                     ┌────────┐
                  ──final gate──────▶ │ REVIEW │  integration & acceptance
                                     └────────┘
```

## What's in the repo

```
hermes-stack/
├── profiles/<name>/
│   ├── SOUL.md               # the persona (CC BY-NC-SA 4.0)
│   └── config.example.yaml   # sanitized runtime config (copy → config.yaml)
├── orchestration/
│   ├── hermes-science-dag    # two-mode pipeline: analysis | compute
│   └── hermes-science-swarm  # Kanban swarm: science+genio workers, audit verifier, review synthesizer
├── skills/own/               # my self-written skills (clean-session-close)
├── skill.lock.json           # names of vendored skill packs — NOT redistributed here
├── install.sh                # deploys to ~/.hermes/profiles (default: --dry-run)
└── README.md / LICENSE-MIT / LICENSE-PERSONAS / SECURITY.md
```

Profiles included: `director`, `science`, `genio`, `runner`, `audit`, `review`.

## Install

Requirements: a working Hermes CLI (`hermes`) on the same machine; the Kanban
and ntfy plugins enabled in the runtime's config.

```sh
./install.sh              # dry-run: shows exactly what it would write
./install.sh --apply      # writes profiles, orchestration scripts, and shows the alias lines to add
```

`install.sh` refuses to clobber an existing `SOUL.md` or `config.yaml` unless
you pass `--force`, and **never touches** `memories/`, `auth.json`, `state.db`,
sessions or logs — those stay yours and are not part of this repo.

### Secrets and placeholders

The `config.example.yaml` files are sanitized: the notification topic appears
as `${HERMES_NTFY_TOPIC}` and the chat display name as a generic value. When
you copy a config to `config.yaml`, set your own values (and keep real
credentials in the runtime's env — never commit them). The local model aliases
point at `http://localhost:8080` (your own proxy/vision/OSS-GPT endpoints).

## How I run it

```sh
hermes-science-dag --mode analysis "Question about X's Lyapunov structure…"
hermes-science-dag --mode compute  "New Julia implementation needed for…"
hermes-science-swarm "Goal…"       # lighter: parallel reasoning, no Runner
```

DAG mode: science+genio → (runner in compute mode) → audit → review → director
final integration. The director's `SOUL.md` encodes the routing discipline
(smallest sufficient graph; capacity-aware dispatch; ntfy-only human gate for
material conclusions).

## Licensing (split on purpose)

- Code, orchestration, configs: **MIT** (see `LICENSE-MIT`).
- Personas (`SOUL.md`): **CC BY-NC-SA 4.0** (see `LICENSE-PERSONAS`) — reuse and
  remix in your own stacks, non-commercial, share-alike, attribution appreciated.
- Vendored skills referenced by name in `skill.lock.json` are not redistributed;
  obtain them from their own upstreams.

## Privacy posture

Everything here is my own creation with machine-specific and project-specific
values replaced. No memories, conversations, sessions, run IDs, credentials or
project names are included. See `SECURITY.md`.
