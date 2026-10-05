# Service Level Objectives

Service: **Potassium Music Player** (`/api/*`, streaming, web UI).
Window: rolling **30 days**. Metrics come from `/metrics` (see [observability](../observability.md)).

| # | SLI (what we measure) | SLO (target) | Error budget |
|---|---|---|---|
| 1 | **Availability** — share of requests that do *not* return 5xx: `1 - sum(rate(http_requests_total{status=~"5.."}[w])) / sum(rate(http_requests_total[w]))` | **99.5 %** | 0.5 % of requests (~3 h 36 min of total failure per 30 days) |
| 2 | **Latency** — p95 of `GET /api/songs` (`job:api_songs_latency_p95_seconds:5m`) | **< 500 ms** | alert after 10 min above target |
| 3 | **Readiness** — time with a non-empty library (`songs_library_size > 0`) | **99.9 %** | ~43 min / 30 days |

Notes
- SLI/SLO/SLA: these are internal **SLOs**. There is no external **SLA** for a self-hosted project; if one were offered it would be set looser than the SLO (e.g. 99 %) so the team is warned before breaching it.
- 4xx responses (unknown song, malformed body) are the *client's* fault and count as good events.
- Streaming (`/api/songs/{id}/play`) is excluded from the latency SLI: its duration is the length of the download, not the server's responsiveness.
- Known limitation: an availability SLI computed from server-side counters cannot see a **total outage** (no requests → no 5xx). The `MusicPlayerDown` alert (`up == 0`) covers that; an external black-box probe would be the proper long-term fix.
- SLO #3 exists because an empty library is a real failure that returns HTTP 200 everywhere (see [postmortem-001](postmortem-001.md)).

## Alerting (multi-window, multi-burn-rate)

Defined in [`monitoring/rules.yml`](../../monitoring/rules.yml). Burn rate 1 = spending the budget exactly over 30 days.

| Alert | Condition | Meaning | Action |
|---|---|---|---|
| `ErrorBudgetFastBurn` | burn > 14.4× over 1 h **and** 5 min | 2 % of the monthly budget gone in 1 h | **page** |
| `ErrorBudgetSlowBurn` | burn > 6× over 6 h **and** 30 min | 5 % gone in 6 h | ticket |
| `ApiSongsLatencySLOViolation` | p95 > 0.5 s for 10 min | latency SLO breached | ticket |
| `MusicPlayerDown` | `up == 0` for 1 min | no scrape | **page** |
| `MusicPlayerEmptyLibrary` | `songs_library_size == 0` for 2 min | serving nothing | **page** |

## Error-budget policy

- Budget > 50 % left: ship normally.
- Budget < 50 %: every change needs a rollback plan; no risky releases on Fridays.
- Budget exhausted: freeze feature work, fix reliability (postmortem action items first) until the budget recovers.
