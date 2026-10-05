# Monitoring & Observability

The server exposes the **three pillars** (traces are lightweight — see below).

| Pillar | How | Where to look |
|---|---|---|
| **Metrics** | `GET /metrics` (Prometheus text format) | Prometheus :9090, Grafana :3001 |
| **Logs** | one JSON object per line on stdout (`"log_format": "json"` in `config.json`) | `docker logs`, Kibana :5601 |
| **Traces** | every response carries `X-Request-ID` (an incoming one is reused); the same id is in the access log, so one request can be followed across hops. Full distributed tracing (OpenTelemetry/Jaeger) is not implemented. | Kibana: `request_id : "<id>"` |

Health: `/healthz` = liveness (process is serving), `/readyz` = readiness (503 if the library is empty).

## Metrics exposed
| Metric | Type | Labels |
|---|---|---|
| `http_requests_total` | counter | `method`, `route`, `status` |
| `http_request_duration_seconds` | histogram | `route` |
| `songs_streamed_total` | counter | — |
| `songs_library_size` | gauge | — |
| `playlist_queue_length` | gauge | — |

`route` is normalized (`/api/songs/{id}/play`, `static`, ...) so label cardinality stays bounded.

## Run the stack
```bash
docker compose -f docker-compose.observability.yml up -d --build        # app + Prometheus + Alertmanager + Grafana
docker compose -f docker-compose.observability.yml --profile elk up -d  # add Filebeat/Logstash/Elasticsearch/Kibana (~2 GB RAM)
monitoring/loadgen.sh http://localhost:3000 120                         # generate traffic
```
- Grafana → **Music Player — Service Overview** (provisioned automatically; anonymous admin is enabled for local demo only).
- Prometheus → *Alerts* shows the rules from `monitoring/rules.yml`.
- Kibana (elk profile): *Stack Management → Data Views → create `music-player-*`, time field `@timestamp`*, then *Discover*. Useful queries: `status >= 500`, `route : "/api/songs/{id}/play"`, `level : "error"`.
- Linux note: Filebeat reads `/var/lib/docker/containers`; on Docker Desktop (macOS/Windows) that path lives inside the VM and the ELK profile may need adjusting.

## Log fields
`ts_ms, level, service, msg` on every line; request lines add `request_id, method, path, route, status, duration_ms`.

## Kubernetes
Pods are annotated `prometheus.io/scrape: "true"`, `port: 3000`, `path: /metrics` for annotation-based discovery (e.g. kube-prometheus-stack / a pod-annotation scrape job).

See [SRE docs](sre/): [SLOs & alerting](sre/slo.md) · [runbook](sre/runbook.md) · [postmortem](sre/postmortem-001.md).
