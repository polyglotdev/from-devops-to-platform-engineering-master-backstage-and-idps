# Observability

Comprehensive guide to monitoring, metrics, and logging for the FastAPI Platform Demo.

## Overview

The application implements the three pillars of observability:

| Pillar | Implementation |
|--------|----------------|
| **Metrics** | Prometheus metrics via `/metrics` endpoint |
| **Logging** | Structured JSON logs with request tracing |
| **Tracing** | Request ID propagation via `X-Request-ID` header |

## Prometheus Metrics

### Available Metrics

#### HTTP Request Counter

Tracks total HTTP requests by method, endpoint, and status code.

```text
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/v1/hello",status="200"} 42.0
```

**Labels:**

- `method`: HTTP method (GET, POST, etc.)
- `endpoint`: Request path
- `status`: HTTP response status code

#### HTTP Request Latency Histogram

Measures request duration in seconds with predefined buckets.

```text
# HELP http_request_duration_seconds HTTP request latency in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.005"} 38.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.01"} 41.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.025"} 42.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.05"} 42.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.1"} 42.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.25"} 42.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.5"} 42.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="1.0"} 42.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="2.5"} 42.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="5.0"} 42.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="+Inf"} 42.0
http_request_duration_seconds_sum{method="GET",endpoint="/api/v1/hello"} 0.156
http_request_duration_seconds_count{method="GET",endpoint="/api/v1/hello"} 42.0
```

**Bucket boundaries (seconds):** 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0

#### In-Progress Requests Gauge

Shows currently active requests per endpoint.

```text
# HELP http_requests_in_progress HTTP requests currently in progress
# TYPE http_requests_in_progress gauge
http_requests_in_progress{method="GET",endpoint="/api/v1/details"} 1.0
```

### Prometheus Scrape Configuration

Configure Prometheus to scrape the application:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'fastapi-app'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - platform-demo
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
```

The Helm chart includes the necessary annotations:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: /metrics
  prometheus.io/port: "8000"
```

### Useful PromQL Queries

**Request Rate (per second)**

```promql
rate(http_requests_total[5m])
```

**95th Percentile Latency**

```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Error Rate**

```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```

**Request Count by Endpoint**

```promql
sum by (endpoint) (increase(http_requests_total[1h]))
```

---

## Structured Logging

### Log Format

All logs are emitted as JSON for easy parsing:

```json
{
  "time": "2025-12-29T11:00:00+0000",
  "level": "INFO",
  "message": "method=GET path=/api/v1/hello status=200 duration=0.0012s request_id=550e8400-e29b-41d4-a716-446655440000",
  "logger": "__main__"
}
```

### Log Fields

| Field | Description |
|-------|-------------|
| `time` | ISO 8601 timestamp |
| `level` | Log level (INFO, WARNING, ERROR) |
| `message` | Structured message with request details |
| `logger` | Python logger name |

### Request Logging

Every HTTP request generates a log entry with:

- HTTP method
- Request path
- Response status code
- Request duration (seconds)
- Unique request ID

### Application Lifecycle Logs

```json
{"time":"2025-12-29T10:00:00+0000","level":"INFO","message":"Application starting up","logger":"__main__"}
{"time":"2025-12-29T18:00:00+0000","level":"INFO","message":"Application shutting down","logger":"__main__"}
```

### Viewing Logs in Kubernetes

```bash
# Stream logs from all pods
kubectl logs -f -l app.kubernetes.io/name=fastapi-app -n platform-demo

# View logs with timestamps
kubectl logs -l app.kubernetes.io/name=fastapi-app -n platform-demo --timestamps

# Parse JSON logs with jq
kubectl logs -l app.kubernetes.io/name=fastapi-app -n platform-demo | jq '.'

# Filter by log level
kubectl logs -l app.kubernetes.io/name=fastapi-app -n platform-demo | jq 'select(.level == "ERROR")'
```

---

## Request Tracing

### X-Request-ID Header

Every request is assigned a unique identifier for distributed tracing.

**Behavior:**

1. If the client sends `X-Request-ID` header, it's preserved
2. Otherwise, a new UUID is generated
3. The ID is included in the response headers
4. The ID is logged with every request

**Example:**

```bash
# Client-provided ID
curl -H "X-Request-ID: my-trace-123" http://localhost:8000/api/v1/hello -v
< x-request-id: my-trace-123

# Auto-generated ID
curl http://localhost:8000/api/v1/hello -v
< x-request-id: 550e8400-e29b-41d4-a716-446655440000
```

### Response Time Header

Every response includes the processing duration:

```text
x-response-time: 0.0012s
```

---

## Health Monitoring

### Kubernetes Health Probes

The application implements standard Kubernetes health checks:

#### Liveness Probe

**Endpoint:** `GET /api/v1/healthz`

Indicates if the process is alive. Failure triggers container restart.

```yaml
livenessProbe:
  httpGet:
    path: /api/v1/healthz
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
```

#### Readiness Probe

**Endpoint:** `GET /api/v1/ready`

Indicates if the pod can receive traffic. Failure removes pod from service endpoints.

```yaml
readinessProbe:
  httpGet:
    path: /api/v1/ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### Readiness State Management

The readiness state can be toggled for demonstrations:

```bash
# Set to not ready (pod stops receiving traffic)
curl -X POST "http://localhost:8000/api/v1/ready/toggle?ready=false&reason=maintenance"

# Set back to ready
curl -X POST "http://localhost:8000/api/v1/ready/toggle?ready=true&reason=maintenance%20complete"
```

**Use cases:**

- Graceful shutdown demonstrations
- Rolling update testing
- Circuit breaker simulations

---

## Grafana Dashboard

Example Grafana dashboard JSON for the FastAPI application:

```json
{
  "title": "FastAPI Platform Demo",
  "panels": [
    {
      "title": "Request Rate",
      "type": "timeseries",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total[5m]))",
          "legendFormat": "Requests/sec"
        }
      ]
    },
    {
      "title": "Latency (p95)",
      "type": "timeseries",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
          "legendFormat": "p95 Latency"
        }
      ]
    },
    {
      "title": "Error Rate",
      "type": "stat",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100",
          "legendFormat": "Error %"
        }
      ]
    },
    {
      "title": "Active Requests",
      "type": "gauge",
      "targets": [
        {
          "expr": "sum(http_requests_in_progress)",
          "legendFormat": "In Progress"
        }
      ]
    }
  ]
}
```

---

## Alerting Rules

Example Prometheus alerting rules:

```yaml
groups:
  - name: fastapi-alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) 
          / sum(rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 5% for the last 5 minutes"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "95th percentile latency is above 1 second"

      - alert: PodNotReady
        expr: |
          kube_pod_status_ready{namespace="platform-demo", pod=~"fastapi-app.*"} == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "FastAPI pod not ready"
          description: "Pod {{ $labels.pod }} has been not ready for 5 minutes"
```
