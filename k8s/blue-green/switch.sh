#!/usr/bin/env bash
# Cut live traffic over to a colour:  ./switch.sh green   (or: blue to roll back)
set -euo pipefail
COLOUR="${1:?usage: switch.sh blue|green}"
case "$COLOUR" in blue|green) ;; *) echo "colour must be blue or green" >&2; exit 2;; esac

kubectl -n music-player rollout status "deployment/music-player-$COLOUR" --timeout=120s
kubectl -n music-player patch service music-player-live \
  -p "{\"spec\":{\"selector\":{\"app\":\"music-player-bg\",\"version\":\"$COLOUR\"}}}"
echo "Live traffic now served by: $COLOUR"
