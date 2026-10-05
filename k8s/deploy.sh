#!/usr/bin/env bash
# Roll out an image to the cluster kubectl currently points at, and roll back
# automatically if the new version never becomes Ready.
#
#   k8s/deploy.sh music-player:42-abc1234
#
# For a local minikube/kind cluster, load the image first:
#   minikube image load music-player:<tag>      # or: kind load docker-image music-player:<tag>
set -euo pipefail

IMAGE="${1:?usage: k8s/deploy.sh <image:tag>}"
NS=music-player
DIR="$(cd "$(dirname "$0")" && pwd)"

kubectl apply -f "$DIR/namespace.yaml"
kubectl apply -f "$DIR/configmap.yaml" -f "$DIR/pvc.yaml" -f "$DIR/service.yaml" -f "$DIR/deployment.yaml"

kubectl -n "$NS" set image deployment/music-player music-player="$IMAGE"

if ! kubectl -n "$NS" rollout status deployment/music-player --timeout=120s; then
    echo "Rollout of $IMAGE failed — rolling back" >&2
    kubectl -n "$NS" rollout undo deployment/music-player
    kubectl -n "$NS" rollout status deployment/music-player --timeout=120s
    exit 1
fi
echo "Deployed $IMAGE"
