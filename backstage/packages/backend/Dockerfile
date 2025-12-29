# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 g++ build-essential \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHON=/usr/bin/python3

# Copy package files first for better caching
COPY .yarn ./.yarn
COPY .yarnrc.yml yarn.lock package.json backstage.json ./
COPY packages/backend/package.json packages/backend/
COPY packages/app/package.json packages/app/

# Install all dependencies
RUN --mount=type=cache,target=/root/.yarn/berry/cache \
    yarn install --immutable

# Copy source code
COPY . .

# Build the backend
RUN yarn tsc && yarn build:backend


FROM node:22-bookworm-slim

# OCI Image Labels for supply chain metadata
LABEL org.opencontainers.image.title="Backstage Platform Portal"
LABEL org.opencontainers.image.description="Internal developer portal for platform engineering"
LABEL org.opencontainers.image.vendor="polyglotdev"
LABEL org.opencontainers.image.source="https://github.com/polyglotdev/from-devops-to-platform-engineering-master-backstage-and-idps"
LABEL org.opencontainers.image.licenses="Apache-2.0"

RUN apt-get update && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy files needed by Yarn
COPY --from=builder /app/.yarn ./.yarn
COPY --from=builder /app/.yarnrc.yml ./
COPY --from=builder /app/backstage.json ./

ENV NODE_ENV=production
ENV NODE_OPTIONS="--no-node-snapshot"

# Copy the skeleton and install production deps only
COPY --from=builder /app/yarn.lock /app/package.json ./
COPY --from=builder /app/packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

RUN --mount=type=cache,target=/root/.yarn/berry/cache \
    yarn workspaces focus --all --production

# Copy examples and bundle
COPY --from=builder /app/examples ./examples
COPY --from=builder /app/packages/backend/dist/bundle.tar.gz ./
COPY --from=builder /app/app-config*.yaml ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

RUN chown -R node:node /app

EXPOSE 7007

USER node

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
