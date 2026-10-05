#!/usr/bin/env bash
# End-to-end smoke test for the music player API.
#
#   tests/smoke.sh                 # builds nothing; runs ./build/music_player
#   tests/smoke.sh <image-tag>     # runs that Docker image instead
#
# Starts the server against a throw-away music library (fake audio files —
# the server never decodes them), exercises the API, then cleans up. Used by
# the Jenkins / GitLab / GitHub Actions pipelines and runnable locally.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${SMOKE_PORT:-3999}"
BASE="http://127.0.0.1:${PORT}"
IMAGE="${1:-}"
WORK="$(mktemp -d)"
PID=""
CID=""

cleanup() {
    [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
    [ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

pass=0; fail=0
check() { # check "<description>" <condition-exit-code>
    if [ "$2" -eq 0 ]; then echo "  ok   $1"; pass=$((pass+1));
    else echo "  FAIL $1"; fail=$((fail+1)); fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

mkdir -p "$WORK/songs"
head -c 4096 /dev/urandom > "$WORK/songs/Smoke_Test_One.mp3"
head -c 2048 /dev/urandom > "$WORK/songs/Smoke_Test_Two.ogg"
chmod -R a+rX "$WORK"   # container runs as a non-root uid

if [ -n "$IMAGE" ]; then
    echo "Starting image $IMAGE on :$PORT"
    CID="$(docker run -d -p "${PORT}:3000" -v "$WORK/songs:/app/songs:ro" "$IMAGE")"
else
    BIN="$ROOT/build/music_player"
    [ -x "$BIN" ] || { echo "missing $BIN — build first"; exit 2; }
    echo "Starting $BIN on :$PORT"
    ln -s "$ROOT/public" "$WORK/public"
    cat > "$WORK/config.json" <<JSON
{"host":"127.0.0.1","port":$PORT,"music_directory":"$WORK/songs","log_format":"json"}
JSON
    (cd "$WORK" && exec "$BIN" > "$WORK/server.log" 2>&1) &
    PID=$!
fi

for _ in $(seq 1 40); do
    [ "$(code "$BASE/healthz" || true)" = "200" ] && break
    sleep 0.25
done

echo "Running checks"
check "GET /healthz -> 200"            $([ "$(code "$BASE/healthz")" = 200 ] && echo 0 || echo 1)
check "GET /readyz -> 200"             $([ "$(code "$BASE/readyz")" = 200 ] && echo 0 || echo 1)
check "GET / serves the frontend"      $([ "$(code "$BASE/")" = 200 ] && echo 0 || echo 1)

SONGS="$(curl -s "$BASE/api/songs")"
check "GET /api/songs lists 2 songs"   $([ "$(echo "$SONGS" | grep -o '"id"' | wc -l)" -eq 2 ] && echo 0 || echo 1)

ID="$(echo "$SONGS" | grep -o '"id":"[0-9]*"' | head -1 | grep -o '[0-9]*')"
check "GET play -> 200"                $([ "$(code "$BASE/api/songs/$ID/play")" = 200 ] && echo 0 || echo 1)
RANGE_CODE="$(code -H 'Range: bytes=0-99' "$BASE/api/songs/$ID/play")"
check "range request -> 206"           $([ "$RANGE_CODE" = 206 ] && echo 0 || echo 1)
RANGE_LEN="$(curl -s -H 'Range: bytes=0-99' "$BASE/api/songs/$ID/play" | wc -c | tr -d ' ')"
check "range request returns 100 bytes" $([ "$RANGE_LEN" = 100 ] && echo 0 || echo 1)
check "unknown song -> 404"            $([ "$(code "$BASE/api/songs/99999/play")" = 404 ] && echo 0 || echo 1)

check "add to playlist -> 200"         $([ "$(code -X POST -d "{\"id\":\"$ID\"}" "$BASE/api/playlist/add")" = 200 ] && echo 0 || echo 1)
check "add unknown id -> 404"          $([ "$(code -X POST -d '{"id":"99999"}' "$BASE/api/playlist/add")" = 404 ] && echo 0 || echo 1)
check "malformed JSON -> 400 (not crash)" $([ "$(code -X POST -d 'not json' "$BASE/api/playlist/add")" = 400 ] && echo 0 || echo 1)
check "server still alive after bad input" $([ "$(code "$BASE/healthz")" = 200 ] && echo 0 || echo 1)
check "queue serves queued song first" $(curl -s "$BASE/api/songs/next" | grep -q "\"id\":\"$ID\"" && echo 0 || echo 1)

check "X-Request-ID header present"    $(curl -sI "$BASE/healthz" | grep -qi '^x-request-id:' && echo 0 || echo 1)

METRICS="$(curl -s "$BASE/metrics")"
check "/metrics has request counter"   $(echo "$METRICS" | grep -q '^http_requests_total{' && echo 0 || echo 1)
check "/metrics has latency histogram" $(echo "$METRICS" | grep -q '^http_request_duration_seconds_bucket{' && echo 0 || echo 1)
check "/metrics counts streams"        $(echo "$METRICS" | grep -Eq '^songs_streamed_total [1-9]' && echo 0 || echo 1)
check "/metrics library size = 2"      $(echo "$METRICS" | grep -q '^songs_library_size 2$' && echo 0 || echo 1)

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
