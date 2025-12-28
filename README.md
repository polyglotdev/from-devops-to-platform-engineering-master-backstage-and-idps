# Python FastAPI App

A FastAPI application with Docker Scout compliance.

## Building the Image

### With Supply Chain Attestations (requires registry push)

```bash
docker buildx build \
  --tag <registry>/python-fastapi-app:latest \
  --attest type=sbom \
  --attest type=provenance,mode=max \
  --push \
  .
```

### Local Build (no attestations)

```bash
docker buildx build \
  --tag python-fastapi-app:latest \
  --load \
  .
```

## Running

```bash
docker run -p 8000:8000 python-fastapi-app:latest
```

## API Endpoints

- `GET /api/v1/hello` - Hello World
- `GET /api/v1/healthz` - Health check
- `GET /api/v1/details` - System details
- `GET /api/v1/getdate` - Current date
