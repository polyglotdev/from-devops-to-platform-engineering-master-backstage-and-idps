import logging
import os
import platform
import socket
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone

import psutil
from fastapi import FastAPI, Request, Response
from prometheus_client import (
  CONTENT_TYPE_LATEST,
  Counter,
  Gauge,
  Histogram,
  generate_latest,
)
from user_agents import parse

# Configure structured logging
logging.basicConfig(
  level=logging.INFO,
  format='{"time":"%(asctime)s","level":"%(levelname)s","message":"%(message)s","logger":"%(name)s"}',
  datefmt='%Y-%m-%dT%H:%M:%S%z',
)
logger = logging.getLogger(__name__)

# Track startup time
STARTUP_TIME = time.time()

# Readiness state (can be toggled via endpoint)
app_ready = {'ready': True, 'reason': 'ok'}

# Prometheus metrics
REQUEST_COUNT = Counter(
  'http_requests_total',
  'Total HTTP requests',
  ['method', 'endpoint', 'status'],
)
REQUEST_LATENCY = Histogram(
  'http_request_duration_seconds',
  'HTTP request latency in seconds',
  ['method', 'endpoint'],
  buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)
REQUESTS_IN_PROGRESS = Gauge(
  'http_requests_in_progress',
  'HTTP requests currently in progress',
  ['method', 'endpoint'],
)


@asynccontextmanager
async def lifespan(app: FastAPI):
  logger.info('Application starting up')
  yield
  logger.info('Application shutting down')


app = FastAPI(lifespan=lifespan)


@app.middleware('http')
async def request_middleware(request: Request, call_next):
  # Generate request ID
  request_id = request.headers.get('X-Request-ID', str(uuid.uuid4()))
  request.state.request_id = request_id

  # Track metrics
  method = request.method
  path = request.url.path

  REQUESTS_IN_PROGRESS.labels(method=method, endpoint=path).inc()
  start_time = time.time()

  try:
    response = await call_next(request)
    duration = time.time() - start_time

    # Record metrics
    REQUEST_COUNT.labels(
      method=method, endpoint=path, status=response.status_code
    ).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=path).observe(duration)

    # Add response headers
    response.headers['X-Request-ID'] = request_id
    response.headers['X-Response-Time'] = f'{duration:.4f}s'

    # Structured log
    logger.info(
      f'method={method} path={path} status={response.status_code} '
      f'duration={duration:.4f}s request_id={request_id}'
    )

    return response
  finally:
    REQUESTS_IN_PROGRESS.labels(method=method, endpoint=path).dec()


@app.get('/api/v1/hello')
def read_root():
  return {'message': 'Hello, World!'}


@app.get('/api/v1/healthz')
def healthz():
  """Liveness probe - is the process alive?"""
  return {'status': 'ok'}


@app.get('/api/v1/ready')
def readiness():
  """Readiness probe - is the app ready to receive traffic?"""
  if app_ready['ready']:
    return {'status': 'ready', 'reason': app_ready['reason']}
  return Response(
    content=f'{{"status": "not_ready", "reason": "{app_ready["reason"]}"}}',
    status_code=503,
    media_type='application/json',
  )


@app.post('/api/v1/ready/toggle')
def toggle_readiness(ready: bool = True, reason: str = 'toggled via API'):
  """Toggle readiness state - useful for demos and testing."""
  app_ready['ready'] = ready
  app_ready['reason'] = reason
  logger.info(f'Readiness toggled: ready={ready} reason={reason}')
  return {'ready': ready, 'reason': reason}


@app.get('/api/v1/details')
def details(request: Request):
  user_agent_string = request.headers.get('User-Agent', '')
  user_agent = parse(user_agent_string)

  # Client IP: check forwarded headers first, fall back to direct connection
  client_ip = (
    request.headers.get('X-Forwarded-For', '').split(',')[0].strip()
    or request.headers.get('X-Real-IP')
    or (request.client.host if request.client else None)
  )

  # Process info
  process = psutil.Process()
  memory_info = process.memory_info()

  # Uptime calculation
  uptime_seconds = time.time() - STARTUP_TIME
  uptime_formatted = format_uptime(uptime_seconds)

  return {
    # Server info
    'server': {
      'hostname': socket.gethostname(),
      'ip': socket.gethostbyname(socket.gethostname()),
      'platform': platform.system(),
      'platform_version': platform.version(),
      'architecture': platform.machine(),
      'python_version': platform.python_version(),
      'pid': os.getpid(),
    },
    # Kubernetes metadata (from downward API env vars)
    'kubernetes': {
      'pod_name': os.environ.get('POD_NAME', os.environ.get('HOSTNAME')),
      'pod_namespace': os.environ.get('POD_NAMESPACE'),
      'pod_ip': os.environ.get('POD_IP'),
      'node_name': os.environ.get('NODE_NAME'),
      'service_account': os.environ.get('SERVICE_ACCOUNT'),
    },
    # Resource usage
    'resources': {
      'memory_rss_mb': round(memory_info.rss / 1024 / 1024, 2),
      'memory_vms_mb': round(memory_info.vms / 1024 / 1024, 2),
      'memory_percent': round(process.memory_percent(), 2),
      'cpu_percent': process.cpu_percent(),
      'threads': process.num_threads(),
      'open_files': len(process.open_files()),
    },
    # Uptime
    'uptime': {
      'seconds': round(uptime_seconds, 2),
      'formatted': uptime_formatted,
      'started_at': datetime.fromtimestamp(STARTUP_TIME, tz=timezone.utc).isoformat(),
    },
    # Client/browser info (parsed from User-Agent)
    'client': {
      'ip': client_ip,
      'browser': {
        'family': user_agent.browser.family,
        'version': user_agent.browser.version_string,
      },
      'os': {
        'family': user_agent.os.family,
        'version': user_agent.os.version_string,
      },
      'device': {
        'family': user_agent.device.family,
        'brand': user_agent.device.brand,
        'model': user_agent.device.model,
        'is_mobile': user_agent.is_mobile,
        'is_tablet': user_agent.is_tablet,
        'is_pc': user_agent.is_pc,
        'is_bot': user_agent.is_bot,
      },
      'user_agent_raw': user_agent_string,
    },
    # Request info
    'request': {
      'id': getattr(request.state, 'request_id', None),
      'method': request.method,
      'url': str(request.url),
      'path': request.url.path,
      'query_params': dict(request.query_params),
      'forwarded_host': request.headers.get('X-Forwarded-Host'),
      'forwarded_proto': request.headers.get('X-Forwarded-Proto'),
      'forwarded_port': request.headers.get('X-Forwarded-Port'),
      'referer': request.headers.get('Referer'),
      'accept_language': request.headers.get('Accept-Language'),
    },
    # Timestamp
    'timestamp': datetime.now(timezone.utc).isoformat(),
  }


@app.get('/api/v1/stats')
def stats():
  """Human-readable stats endpoint (JSON alternative to /metrics)."""
  process = psutil.Process()
  memory_info = process.memory_info()
  uptime_seconds = time.time() - STARTUP_TIME

  return {
    'uptime': {
      'seconds': round(uptime_seconds, 2),
      'formatted': format_uptime(uptime_seconds),
    },
    'memory': {
      'rss_mb': round(memory_info.rss / 1024 / 1024, 2),
      'vms_mb': round(memory_info.vms / 1024 / 1024, 2),
      'percent': round(process.memory_percent(), 2),
    },
    'cpu': {
      'percent': process.cpu_percent(),
      'threads': process.num_threads(),
    },
    'system': {
      'cpu_count': psutil.cpu_count(),
      'total_memory_gb': round(psutil.virtual_memory().total / 1024 / 1024 / 1024, 2),
      'available_memory_gb': round(
        psutil.virtual_memory().available / 1024 / 1024 / 1024, 2
      ),
      'disk_usage_percent': psutil.disk_usage('/').percent,
    },
    'process': {
      'pid': os.getpid(),
      'open_files': len(process.open_files()),
      'connections': len(process.net_connections()),
    },
  }


@app.get('/api/v1/getdate')
def getdate():
  return {'date': datetime.now().strftime('%d-%m-%Y')}


@app.get('/metrics')
def metrics():
  """Prometheus metrics endpoint."""
  return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


def format_uptime(seconds: float) -> str:
  """Format seconds into human-readable uptime string."""
  days, remainder = divmod(int(seconds), 86400)
  hours, remainder = divmod(remainder, 3600)
  minutes, secs = divmod(remainder, 60)

  parts = []
  if days:
    parts.append(f'{days}d')
  if hours:
    parts.append(f'{hours}h')
  if minutes:
    parts.append(f'{minutes}m')
  parts.append(f'{secs}s')

  return ' '.join(parts)
