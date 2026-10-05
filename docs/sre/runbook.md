# Runbook

Quick triage: `curl localhost:3000/healthz`, `curl localhost:3000/readyz`, `curl localhost:3000/metrics | head`, then logs.
Logs: `docker logs music-player` / `kubectl -n music-player logs deploy/music-player` / Kibana (`music-player-*`).

## Service down
**Alert:** `MusicPlayerDown` · **Symptom:** UI unreachable, Prometheus target DOWN.
1. Is the process/container running? `docker ps`, `kubectl -n music-player get pods`.
2. Crash loop? `docker logs --tail 50 music-player`, `kubectl describe pod`, `kubectl logs --previous`.
3. Port in use? Another process on 3000 (`lsof -i :3000`) — change `port` in `config.json`.
4. Bad release? **Roll back:** `kubectl -n music-player rollout undo deployment/music-player` (or switch blue/green back: `k8s/blue-green/switch.sh blue`).

## Empty library
**Alert:** `MusicPlayerEmptyLibrary` · **Symptom:** UI loads but shows no songs; `/readyz` returns 503; everything else is 200.
1. `curl localhost:3000/metrics | grep songs_library_size` → 0 confirms it.
2. Check the mount: `docker exec music-player ls /app/songs` / `kubectl exec ... -- ls /app/songs`.
3. Wrong `music_directory` in `config.json`? Wrong volume path in compose / PVC empty?
4. Permissions: container runs as uid 1000 — `chmod -R a+rX` the music folder.
5. The library is scanned **at startup only**: after fixing the mount, restart (`docker compose restart`, `kubectl rollout restart deployment/music-player`).

## High error rate
**Alerts:** `ErrorBudgetFastBurn` / `ErrorBudgetSlowBurn`.
1. Grafana → "Requests by status": which route returns 5xx? (`http_requests_total{status=~"5.."}` by `route`).
2. Kibana: `status >= 500` — use the `request_id` to follow one request.
3. Correlate with the last deploy (`kubectl rollout history`). If it started with a release → roll back first, investigate after.

## High latency
**Alert:** `ApiSongsLatencySLOViolation`.
1. Grafana latency panel: is it all routes or `/api/songs` only?
2. Large library? The scan is startup-only, but `/api/songs` returns the whole list — check `songs_library_size`.
3. CPU throttling: `kubectl top pod`; raise limits in `k8s/deployment.yaml` or add replicas.

## After every incident
Open a postmortem from [`postmortem-template`](postmortem-001.md) within 2 working days — blameless, with action items that have owners.
