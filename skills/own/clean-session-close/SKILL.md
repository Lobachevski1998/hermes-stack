---
name: clean-session-close
description: Use when ending a work session cleanly — "termina la sesión con limpieza", "cerramos por hoy", "cierre limpio y resume mañana", "pausa segura", "retomamos mañana". Lets healthy workers finish, parks the dispatchable frontier with native Kanban semantics, proves zero workers, and leaves the exact resume action.
---

# Clean session close and morning resume

DRAFT — staged for operator review; not installed. Behaviour identical to the procedure executed and
verified on 2026-09-27/28 (pause + resume of a 12-card campaign).

Class of task: the operator is stopping for the day. The session must end in a state that is **safe**
(nothing runs unattended), **honest** (nothing half-stopped, nothing silently respawned) and
**resumable** (tomorrow starts from a recorded action, not reconstructed context).

## 0. Classify before touching anything

Ask, per running worker, exactly one question first: **did the human ask to interrupt it, or only to
stop starting new work?**

| Worker state | Action |
|---|---|
| healthy and doing legitimate work; human did not ask to interrupt | **LET IT FINISH.** Do not signal it. Do not park it mid-turn as a "pause" if the session can simply wait for the terminal event. Subscribe/settle, state the reason, end the turn. |
| human explicitly asked to interrupt ("pausa segura now", "stop it") | Graceful path in §2 — park first, then SIGTERM the verified PID. |
| worker crashed / stopped heartbeating beyond its cadence | do not improvise: capture evidence, report the defect, leave the card for the operator |

Never confuse "close the session" with "kill the work". A worker that is finishing is the *cheapest*
place to stop: its artifact, verdict and run row arrive complete and need no salvage.

## 1. Card classes (what must be frozen, what must be left alone)

| Class | Dispatchable? | Freeze needed? |
|---|---|---|
| `running` | no (already running) | only if it is to be interrupted (§0) |
| `ready` | **yes — immediate** | **yes** — must be parked, or it spawns on the next sweep |
| `todo`, all parents `done` | **yes, via auto-promotion** | **yes** — the card that promotes when a running card completes is the one that is usually missed |
| `todo`, ≥1 parent open | no | no — record it as gated |
| `scheduled` | no — **inert in this build** | already parked; see §3 |
| `blocked` | no | no |
| `done` / `archived` | no | no |

The frontier to drain is therefore: everything `ready`, **plus every direct child of a card that can
still reach `done` today**. Walk the parent→child edges, not your memory of the plan.

## 2. Interruption path (only when explicitly requested) — this exact order

1. **Identify narrowly:** `ps -o pid,ppid,pgid,sid,lstart,etime,stat,args -p <pid>`; a worker runs as its
   own process group **and** session (`PID == PGID == SID`) with no children ⇒ `kill -TERM <pid>` is
   already the narrowest target. Never `pkill`/`killall`, never SIGKILL, never touch the gateway.
2. **Capture its identity before parking** — parking clears `worker_pid`. Keep `/proc/<pid>/environ`'s
   `HERMES_KANBAN_TASK`, `HERMES_KANBAN_RUN_ID`, `HERMES_KANBAN_WORKSPACE`.
3. **Checkpoint:** copy `~/.hermes/kanban/logs/<task>.log` (it is truncated at spawn when >2 MiB — copy
   **before** any possible respawn) and hash the workspace `~/.hermes/kanban/workspaces/<task>`.
   There is **no** native task-level checkpoint/suspend/resume verb in this build.
4. **Park** every card in the freeze set: `hermes kanban schedule <id> "<reason>"` — put the resume
   target in the reason, since no time is stored. Verify `status='scheduled'`, `claim_lock IS NULL`,
   `worker_pid IS NULL`.
5. **Stop**: `kill -TERM <verified pid>`; wait (a mid-stream worker can need well over 5 s); confirm exit.
   Never `reclaim` as the pause mechanism — `reclaim` sets `ready` and the next sweep respawns the card.
6. **Label partial output** `PARTIAL / NOT A RESULT` (provenance only) and say plainly which in-flight
   turn was discarded.

## 3. `scheduled` is inert — never promise an automatic wall-clock resume

Verified against the installed build: `PRAGMA table_info(tasks)` has **no** scheduling column;
`hermes kanban schedule --help` has **no** `--at`; `hermes kanban create --help` has **no**
`--scheduled-at`; `kanban_db_dispatch.py` has **0** matches for `scheduled` (nothing promotes it).
The docs describe `scheduled_at` — that is a newer, unreleased feature. `unblock` is the **only** resume
action, and it is a human/CLI act. If the operator asks for "pause now, resume automatically at 08:00",
say what is missing instead of parking with a promise the build cannot keep.

## 4. Zero-worker verification (the gate that must be *proven*, not assumed)

```
# definitive worker predicate — scan per-pid env, never process names
for p in $(ps -eo pid --no-headers); do
  [ -r /proc/$p/environ ] && tr '\0' '\n' < /proc/$p/environ | grep -q '^HERMES_KANBAN_TASK=' && echo "worker $p"
done
```
- `ps | grep <agent-binary>` **lies**: the gateway, the desktop `serve` hosts (`HERMES_DESKTOP=1`) and
  the operator's own shell all match it.
- Also require: `task_runs` rows with `status='running'` = 0; `tasks` with `status='ready'` = 0; **one**
  dispatcher owner (`… python3 -m hermes_cli.main … gateway run$`); gateway active with a plausible
  `NRestarts`; Hindsight + api_server `HTTP 200`; the Kanban DB readable.
- **Wait through at least one dispatcher sweep** (≈60 s; the tick phase is anchored at gateway start,
  not at your command) and re-check: same board counts, no new `running` row.
- Expect parks to write their **own** run row (`status`/`outcome='scheduled'`) for every parked card — a
  run-count increase is not evidence of a respawn; judge by `running` rows.
- Claim Ledger and its annotations must hash **unchanged** unless the completed task's own authorised
  workflow says otherwise.

## 5. Durable resume state (what must exist before you stop)

Write one close record containing: what completed today (card · run · verdict · artifact hash); what
remains open (with the reason: gated / parked / awaiting human decision); the exact board counts; the
artifacts and their hashes; the **next dependency**; and the **exact resume action**. Preserve partial
work by hash, not by description.

## 6. Morning resume

```
hermes kanban unblock <ids...>          # the only native resume action
```
Then verify the spawn **from the gateway's own sweep** (do not dispatch by hand when the point is to
prove the path works): same task id (not a recreation), new run id, correct assignee, the repaired
venv interpreter (`<install-env>/venv/bin/python3 -m hermes_cli.main -p <profile> --cli`), a valid PID,
a registered heartbeat, **exactly one** `running` row for the task, dispatcher count still 1. Gated
cards resume only when their parents reach `done` — never force or re-prioritise them.

## 7. Reporting shape (this operator)

Before/after table for `status`, `claim_lock`, `worker_pid`, run outcome, heartbeat, failure counters;
quoted command/SQL output, never paraphrase; exactly one verdict line (`SESSION CLOSED CLEAN = PASS` /
the negative form on unproven safety); name the discarded in-flight turn; state what was **not** done
(no ledger/Hindsight/recall_sync/model/source change) as explicitly as what was.

## Pitfalls

- **`reclaim` is a retry, not a pause** — it hands the card back to the dispatcher; the sweep re-spawns it.
- **Parking only the *running* card leaks**: a card that *completes* promotes its children — drain the
  whole auto-promotable frontier before stopping anything.
- **A park on a running card clears `worker_pid`** — capture the PID beforehand or the SIGTERM target
  must be recovered elsewhere.
- **No native wall-clock resume** (§3) — "auto-resume tomorrow" cannot be delivered by `schedule`.
- **Do not restart the gateway or Hindsight, and do not create a second dispatcher/daemon/loop** to
  achieve a pause; the gateway sweep and the native verbs are sufficient.
- **A wake/terminal event beats polling** — settle the session and act on the event; do not leave an
  agent loop spinning overnight.
- A worker session can be mid-generation with `last_activity_at` newer than every persisted message:
  check before promising "nothing is lost".