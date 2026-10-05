# Postmortem 001 — Empty music library after deploy (game-day drill)

> **Status: DRILL (simulated incident).** The failure was reproduced on purpose with
> [`incident-drill.sh`](incident-drill.sh); the observations below are real output from that run.
> Replace the bracketed `[...]` fields with your own times/names when you run it for your report.
> Use this file as the template for real incidents. Format: blameless — we ask *what* failed, not *who*.

| | |
|---|---|
| **Date** | [YYYY-MM-DD] |
| **Authors** | [name] |
| **Severity** | SEV-3 (degraded: UI up, no music) |
| **Duration** | [mm] minutes (detection → fix) |
| **SLO impact** | Readiness SLO (#3): [mm] min of the ~43 min monthly budget |

## Summary
A release was started with the music directory mounted wrongly, so the server came up with **zero songs**.
The process was healthy and every HTTP request returned 200, so users just saw an empty player and the availability SLI stayed green.

## Impact
All users saw an empty library for [mm] minutes. No data loss. No 5xx responses.

## Timeline (UTC)
| Time | Event |
|---|---|
| [T+0] | Deploy with wrong `music_directory` / empty volume |
| [T+0] | `/healthz` = 200, **`/readyz` = 503**, `songs_library_size 0`, log: `"library_size":0` *(observed in drill)* |
| [T+2m] | `MusicPlayerEmptyLibrary` fires (rule `for: 2m`) |
| [T+Xm] | On-call follows [runbook → Empty library](runbook.md#empty-library); finds missing mount |
| [T+Ym] | Mount fixed, pods restarted (library is scanned at startup only) |
| [T+Zm] | `songs_library_size` > 0, alert resolves |

## Root cause
Configuration error: the volume/`music_directory` did not point at the library. Contributing factors:
1. The server treats an empty directory as valid (only a warning-level concern), so it started "successfully".
2. The original liveness check hit `/api/songs`, which returns 200 with `{"songs":[]}` — it could not tell "empty" from "fine".
3. No metric or alert existed for library size.

## What went well
- Pods stayed alive and the rest of the API kept working.
- With the new `/readyz`, Kubernetes keeps unready pods out of the Service during a rolling update, so a bad rollout stalls instead of replacing healthy pods (`maxUnavailable: 0`).

## What went badly / where we got lucky
- Availability SLI (HTTP status based) was blind to this failure — detection relied on a purpose-built alert.

## Action items
| # | Action | Type | Owner | Status |
|---|---|---|---|---|
| 1 | Add `/readyz` (503 when library empty) and use it as the K8s readiness probe | prevent | [name] | done |
| 2 | Export `songs_library_size`; alert `MusicPlayerEmptyLibrary` | detect | [name] | done |
| 3 | Log `library_size` at startup (JSON) | detect | [name] | done |
| 4 | Add a CI smoke test that starts the container with a library and asserts `/readyz` = 200 | prevent | [name] | done (`tests/smoke.sh`) |
| 5 | Optional: periodic re-scan or `/api/rescan` so a fixed mount needs no restart | mitigate | [name] | open |
| 6 | Add an external black-box probe for end-to-end availability | detect | [name] | open |

## Lessons
Status-code SLIs miss "successful but wrong" responses. Pair them with a readiness signal and a domain metric.
