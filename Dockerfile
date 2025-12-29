# syntax=docker/dockerfile:1
FROM python:3.13-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

COPY pyproject.toml uv.lock ./

RUN uv sync --frozen --no-install-project --no-dev

COPY . .

RUN uv sync --frozen --no-dev


FROM python:3.13-slim

# OCI Image Labels for supply chain metadata
LABEL org.opencontainers.image.title="FastAPI Platform Demo"
LABEL org.opencontainers.image.description="FastAPI application with observability features for platform engineering demos"
LABEL org.opencontainers.image.version="2.0.0"
LABEL org.opencontainers.image.vendor="polyglotdev"
LABEL org.opencontainers.image.source="https://github.com/polyglotdev/from-devops-to-platform-engineering-master-backstage-and-idps"
LABEL org.opencontainers.image.licenses="MIT"

RUN apt-get update && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 appgroup \
    && useradd --uid 1000 --gid appgroup --shell /bin/false appuser

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/main.py /app/main.py

RUN chown -R appuser:appgroup /app

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

USER appuser

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
