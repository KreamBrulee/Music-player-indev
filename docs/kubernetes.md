# Kubernetes & deployment strategies

Manifests live in [`k8s/`](../k8s). Tested target: minikube or kind (single node).

```bash
docker build -t music-player:dev .
minikube image load music-player:dev            # or: kind load docker-image music-player:dev
k8s/deploy.sh music-player:dev                  # namespace, config, PVC, service, deployment + rollout wait
kubectl -n music-player cp ./songs/. $(kubectl -n music-player get pod -l app=music-player -o name | head -1 | cut -d/ -f2):/app/songs/
kubectl -n music-player rollout restart deployment/music-player   # library is scanned at startup
kubectl -n music-player port-forward svc/music-player 3000:80
```

## Architecture
- **Deployment** (2 replicas): non-root uid 1000, read-only root filesystem, all capabilities dropped, CPU/memory requests+limits.
- **Probes:** `startupProbe` + `livenessProbe` → `/healthz`; `readinessProbe` → `/readyz` (503 while the library is empty).
- **ConfigMap** mounts `config.json` (JSON logging on). **PVC** holds `songs/`. **Service** (ClusterIP :80 → :3000).
- Pod annotations enable Prometheus scraping.

## Strategy 1 — Rolling update (default)
`maxSurge: 1, maxUnavailable: 0`: a new pod must pass `/readyz` before an old one is removed.
```bash
k8s/deploy.sh music-player:v2     # auto-rolls back if the rollout doesn't become ready in 120 s
kubectl -n music-player rollout history deployment/music-player
kubectl -n music-player rollout undo deployment/music-player      # manual rollback
```
+ zero downtime, cheap · − old and new run together briefly (must be compatible), rollback = another rollout.

## Strategy 2 — Blue/green (`k8s/blue-green/`)
Two full Deployments (`blue` = live, `green` = candidate) and a `music-player-live` Service whose selector picks the colour.
```bash
kubectl apply -f k8s/namespace.yaml -f k8s/configmap.yaml -f k8s/pvc.yaml -f k8s/blue-green/
kubectl -n music-player set image deployment/music-player-green music-player=music-player:v2
kubectl -n music-player port-forward svc/music-player-green-preview 3001:80   # test the candidate
k8s/blue-green/switch.sh green      # instant cut-over
k8s/blue-green/switch.sh blue       # instant rollback
```
+ instant cut-over and rollback, test on production-like infra first · − double the resources while both run.

## Other strategies (theory)
**Canary** (send 5–10 % of traffic to the new version, watch the SLO dashboard, then widen — needs an ingress/service mesh for weighted routing); **Recreate** (stop all, start new — downtime, only for incompatible changes); **A/B** (route by user attribute).
