#!/usr/bin/env bash
# Generate demo traffic so dashboards have something to show.
#   monitoring/loadgen.sh [base-url] [seconds]     (default: http://localhost:3000, 60s)
# Mix: listing, streaming (incl. range requests), queueing, plus a few
# client errors (404/400) that must NOT count against the availability SLO.
BASE="${1:-http://localhost:3000}"
END=$(( $(date +%s) + ${2:-60} ))
while [ "$(date +%s)" -lt "$END" ]; do
    curl -s -o /dev/null "$BASE/api/songs"
    curl -s -o /dev/null -H 'Range: bytes=0-65535' "$BASE/api/songs/1/play"
    curl -s -o /dev/null -X POST -d '{"id":"1"}' "$BASE/api/playlist/add"
    curl -s -o /dev/null "$BASE/api/songs/next"
    curl -s -o /dev/null "$BASE/api/songs/99999/play"      # 404
    curl -s -o /dev/null -X POST -d 'oops' "$BASE/api/playlist/add"  # 400
    sleep 0.3
done
echo "load generation finished"
