# API Reference

Complete documentation for the FastAPI Platform Demo REST API.

## Base URL

| Environment | URL |
|-------------|-----|
| Local Development | `http://localhost:8000` |
| Kubernetes (OrbStack) | `http://fastapi-app.k8s.orb.local` |

## Interactive Documentation

FastAPI automatically generates interactive API documentation:

- **Swagger UI**: `/docs`
- **ReDoc**: `/redoc`
- **OpenAPI JSON**: `/openapi.json`

## Endpoints

### Greeting Endpoints

#### GET /api/v1/hello

Returns a simple greeting message.

**Request**

```bash
curl http://localhost:8000/api/v1/hello
```

**Response**

```json
{
  "message": "Hello, World!"
}
```

---

#### GET /api/v1/getdate

Returns the current date in DD-MM-YYYY format.

**Request**

```bash
curl http://localhost:8000/api/v1/getdate
```

**Response**

```json
{
  "date": "29-12-2025"
}
```

---

### Health Endpoints

#### GET /api/v1/healthz

Kubernetes liveness probe endpoint. Returns OK if the process is alive.

**Request**

```bash
curl http://localhost:8000/api/v1/healthz
```

**Response (200 OK)**

```json
{
  "status": "ok"
}
```

!!! info "Kubernetes Usage"
    Configure your liveness probe in the deployment:
    ```yaml
    livenessProbe:
      httpGet:
        path: /api/v1/healthz
        port: 8000
      initialDelaySeconds: 10
      periodSeconds: 30
    ```

---

#### GET /api/v1/ready

Kubernetes readiness probe endpoint. Returns the current readiness state.

**Request**

```bash
curl http://localhost:8000/api/v1/ready
```

**Response (200 OK - Ready)**

```json
{
  "status": "ready",
  "reason": "ok"
}
```

**Response (503 Service Unavailable - Not Ready)**

```json
{
  "status": "not_ready",
  "reason": "maintenance mode"
}
```

---

#### POST /api/v1/ready/toggle

Toggle the readiness state. Useful for demos and testing rolling updates.

**Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `ready` | boolean | `true` | Set readiness state |
| `reason` | string | `"toggled via API"` | Reason for the state change |

**Request - Set Not Ready**

```bash
curl -X POST "http://localhost:8000/api/v1/ready/toggle?ready=false&reason=maintenance%20mode"
```

**Response**

```json
{
  "ready": false,
  "reason": "maintenance mode"
}
```

**Request - Set Ready**

```bash
curl -X POST "http://localhost:8000/api/v1/ready/toggle?ready=true&reason=maintenance%20complete"
```

!!! tip "Demo Scenario"
    Use this endpoint to demonstrate Kubernetes rolling updates:
    
    1. Toggle readiness to `false`
    2. Watch the pod become unready: `kubectl get pods -w`
    3. Traffic stops routing to the pod
    4. Toggle back to `true` to restore traffic

---

### Diagnostics Endpoints

#### GET /api/v1/details

Returns comprehensive system and request details.

**Request**

```bash
curl http://localhost:8000/api/v1/details
```

**Response**

```json
{
  "server": {
    "hostname": "fastapi-app-7d8f9c6b5d-x2k4m",
    "ip": "10.244.0.15",
    "platform": "Linux",
    "platform_version": "5.15.0-91-generic",
    "architecture": "x86_64",
    "python_version": "3.13.0",
    "pid": 1
  },
  "kubernetes": {
    "pod_name": "fastapi-app-7d8f9c6b5d-x2k4m",
    "pod_namespace": "platform-demo",
    "pod_ip": "10.244.0.15",
    "node_name": "orbstack",
    "service_account": null
  },
  "resources": {
    "memory_rss_mb": 45.23,
    "memory_vms_mb": 128.45,
    "memory_percent": 0.56,
    "cpu_percent": 0.5,
    "threads": 4,
    "open_files": 12
  },
  "uptime": {
    "seconds": 3600.45,
    "formatted": "1h 0m 0s",
    "started_at": "2025-12-29T10:00:00+00:00"
  },
  "client": {
    "ip": "192.168.1.100",
    "browser": {
      "family": "Chrome",
      "version": "120.0.0"
    },
    "os": {
      "family": "Mac OS X",
      "version": "14.2"
    },
    "device": {
      "family": "Mac",
      "brand": "Apple",
      "model": "Mac",
      "is_mobile": false,
      "is_tablet": false,
      "is_pc": true,
      "is_bot": false
    },
    "user_agent_raw": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)..."
  },
  "request": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "method": "GET",
    "url": "http://localhost:8000/api/v1/details",
    "path": "/api/v1/details",
    "query_params": {},
    "forwarded_host": null,
    "forwarded_proto": null,
    "forwarded_port": null,
    "referer": null,
    "accept_language": "en-US,en;q=0.9"
  },
  "timestamp": "2025-12-29T11:00:00.123456+00:00"
}
```

!!! note "Kubernetes Metadata"
    The `kubernetes` section is populated from environment variables set via the
    Kubernetes Downward API. These are configured in the Helm chart deployment.

---

#### GET /api/v1/stats

Returns human-readable system statistics.

**Request**

```bash
curl http://localhost:8000/api/v1/stats
```

**Response**

```json
{
  "uptime": {
    "seconds": 3600.45,
    "formatted": "1h 0m 0s"
  },
  "memory": {
    "rss_mb": 45.23,
    "vms_mb": 128.45,
    "percent": 0.56
  },
  "cpu": {
    "percent": 0.5,
    "threads": 4
  },
  "system": {
    "cpu_count": 8,
    "total_memory_gb": 16.0,
    "available_memory_gb": 8.5,
    "disk_usage_percent": 45.2
  },
  "process": {
    "pid": 1,
    "open_files": 12,
    "connections": 3
  }
}
```

---

### Observability Endpoints

#### GET /metrics

Prometheus metrics endpoint in text exposition format.

**Request**

```bash
curl http://localhost:8000/metrics
```

**Response**

```text
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/v1/hello",status="200"} 42.0
http_requests_total{method="GET",endpoint="/api/v1/healthz",status="200"} 120.0

# HELP http_request_duration_seconds HTTP request latency in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.005"} 38.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="0.01"} 41.0
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/hello",le="+Inf"} 42.0
http_request_duration_seconds_sum{method="GET",endpoint="/api/v1/hello"} 0.156
http_request_duration_seconds_count{method="GET",endpoint="/api/v1/hello"} 42.0

# HELP http_requests_in_progress HTTP requests currently in progress
# TYPE http_requests_in_progress gauge
http_requests_in_progress{method="GET",endpoint="/metrics"} 1.0
```

See [Observability](observability.md) for detailed metrics documentation.

---

## Response Headers

All responses include custom headers for traceability:

| Header | Description |
|--------|-------------|
| `X-Request-ID` | Unique request identifier (UUID) for tracing |
| `X-Response-Time` | Request processing duration (e.g., `0.0023s`) |

**Example**

```bash
curl -v http://localhost:8000/api/v1/hello
```

```text
< HTTP/1.1 200 OK
< x-request-id: 550e8400-e29b-41d4-a716-446655440000
< x-response-time: 0.0012s
< content-type: application/json
```

## Error Handling

The API uses standard HTTP status codes:

| Code | Meaning |
|------|---------|
| 200 | Success |
| 422 | Validation Error (invalid parameters) |
| 500 | Internal Server Error |
| 503 | Service Unavailable (not ready) |

**Validation Error Response**

```json
{
  "detail": [
    {
      "type": "bool_parsing",
      "loc": ["query", "ready"],
      "msg": "Input should be a valid boolean",
      "input": "invalid"
    }
  ]
}
```
