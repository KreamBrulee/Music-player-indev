#!/usr/bin/env bash
# Game-day drill: reproduce the "empty library" incident locally and capture
# what the signals look like. Use the output to fill in docs/sre/postmortem-001.md.
#
#   docs/sre/incident-drill.sh        (needs ./build/music_player)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
W="$(mktemp -d)"; PORT=3997
trap 'kill $PID 2>/dev/null; rm -rf "$W"' EXIT
ln -s "$ROOT/public" "$W/public"
mkdir "$W/songs-missing-mount"        # simulates a bad volume mount: dir exists, no songs
echo "{\"host\":\"127.0.0.1\",\"port\":$PORT,\"music_directory\":\"$W/songs-missing-mount\",\"log_format\":\"json\"}" > "$W/config.json"

ts() { date -u +%H:%M:%S; }
(cd "$W" && exec "$ROOT/build/music_player" > "$W/server.log" 2>&1) & PID=$!
for _ in $(seq 1 40); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 0.25; done

echo "[$(ts)] INCIDENT START: server deployed with an empty music directory"
echo "[$(ts)] /healthz  -> $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT/healthz)   (liveness: process is fine, K8s would NOT restart it)"
echo "[$(ts)] /readyz   -> $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT/readyz)   (readiness: K8s removes the pod from the Service)"
echo "[$(ts)] /api/songs -> $(curl -s http://127.0.0.1:$PORT/api/songs)   (users see an empty player, no error)"
echo "[$(ts)] metric: $(curl -s http://127.0.0.1:$PORT/metrics | grep '^songs_library_size')   <- MusicPlayerEmptyLibrary alert fires after 2m"
echo "[$(ts)] log line: $(grep 'Server starting' "$W/server.log")"
echo
echo "Takeaway: this failure is invisible to an availability SLI built on HTTP status"
echo "codes (everything returned 200) — which is why it has its own readiness probe and alert."
