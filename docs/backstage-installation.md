# Backstage Installation and Configuration Guide

Complete guide to installing, configuring, and deploying Backstage in various
environments.

## Table of Contents

- [Backstage Installation and Configuration Guide](#backstage-installation-and-configuration-guide)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
    - [Required Software](#required-software)
    - [System Requirements](#system-requirements)
    - [Verify Prerequisites](#verify-prerequisites)
  - [Quick Start Installation](#quick-start-installation)
    - [Create a New Backstage App](#create-a-new-backstage-app)
    - [Start Development Server](#start-development-server)
    - [Initial Access](#initial-access)
  - [Project Structure](#project-structure)
    - [Key Directories Explained](#key-directories-explained)
  - [Configuration Deep Dive](#configuration-deep-dive)
    - [Configuration Files Hierarchy](#configuration-files-hierarchy)
    - [Core Configuration (app-config.yaml)](#core-configuration-app-configyaml)
    - [Environment-Specific Configuration](#environment-specific-configuration)
    - [Environment Variables](#environment-variables)
  - [Database Setup](#database-setup)
    - [SQLite (Development Only)](#sqlite-development-only)
    - [PostgreSQL (Production)](#postgresql-production)
    - [Database Migrations](#database-migrations)
  - [Docker Deployment](#docker-deployment)
    - [Building the Docker Image](#building-the-docker-image)
    - [Build Commands](#build-commands)
    - [Docker Compose Setup](#docker-compose-setup)
    - [Running with Docker Compose](#running-with-docker-compose)
  - [Kubernetes Deployment](#kubernetes-deployment)
    - [Basic Kubernetes Manifests](#basic-kubernetes-manifests)
    - [Apply Manifests](#apply-manifests)
  - [Helm Chart Deployment](#helm-chart-deployment)
    - [Using the Official Backstage Helm Chart](#using-the-official-backstage-helm-chart)
    - [Custom values.yaml](#custom-valuesyaml)
  - [Production Considerations](#production-considerations)
    - [High Availability](#high-availability)
    - [Resource Recommendations](#resource-recommendations)
    - [Security Hardening](#security-hardening)
    - [Monitoring](#monitoring)
    - [Backup Strategy](#backup-strategy)
  - [Upgrading Backstage](#upgrading-backstage)
    - [Version Upgrade Process](#version-upgrade-process)
    - [Breaking Changes](#breaking-changes)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Useful Commands](#useful-commands)
    - [Log Levels](#log-levels)
  - [Next Steps](#next-steps)
  - [References](#references)

## Prerequisites

### Required Software

| Software   | Minimum Version  | Recommended |
| ---------- | ---------------- | ----------- |
| Node.js    | 18.x             | 20.x LTS    |
| Yarn       | 1.22.x (Classic) | 1.22.x      |
| Git        | 2.x              | Latest      |
| Docker     | 20.x             | Latest      |
| PostgreSQL | 12.x             | 15.x        |

### System Requirements

**Development:**

- 4 GB RAM minimum
- 2 CPU cores
- 10 GB disk space

**Production:**

- 8 GB RAM minimum (16 GB recommended)
- 4 CPU cores minimum
- 50 GB disk space
- PostgreSQL database (managed recommended)

### Verify Prerequisites

```bash
# Check Node.js version
node --version
# Should output: v18.x.x or v20.x.x

# Check Yarn version
yarn --version
# Should output: 1.22.x

# Check Git
git --version

# Check Docker
docker --version
```

## Quick Start Installation

### Create a New Backstage App

```bash
# Create new Backstage app using the CLI
npx @backstage/create-app@latest

# You will be prompted for:
# ? Enter a name for the app (e.g., my-backstage)
# The CLI will create the app and install dependencies
```

### Start Development Server

```bash
cd my-backstage

# Start the development server
yarn dev
```

This starts both frontend (port 3000) and backend (port 7007).

### Initial Access

Open `http://localhost:3000` in your browser. You should see the Backstage
homepage with the software catalog.

## Project Structure

After creation, your Backstage app has this structure:

```text
my-backstage/
├── app-config.yaml              # Main configuration file
├── app-config.local.yaml        # Local overrides (gitignored)
├── app-config.production.yaml   # Production configuration
├── catalog-info.yaml            # This app's catalog entry
├── package.json                 # Root package.json
├── packages/
│   ├── app/                     # Frontend application
│   │   ├── package.json
│   │   ├── src/
│   │   │   ├── App.tsx          # Main app component
│   │   │   ├── components/      # Custom components
│   │   │   └── apis.ts          # API factories
│   │   └── public/
│   └── backend/                 # Backend application
│       ├── package.json
│       ├── src/
│       │   ├── index.ts         # Backend entry point
│       │   └── plugins/         # Backend plugin setup
│       └── Dockerfile
├── plugins/                     # Custom plugins directory
├── examples/                    # Example catalog entities
│   ├── entities.yaml
│   ├── template/
│   └── org.yaml
└── yarn.lock
```

### Key Directories Explained

| Directory          | Purpose                    |
| ------------------ | -------------------------- |
| `packages/app`     | Frontend React application |
| `packages/backend` | Backend Node.js server     |
| `plugins/`         | Custom plugins you develop |
| `examples/`        | Sample catalog entities    |

## Configuration Deep Dive

### Configuration Files Hierarchy

Backstage merges configuration files in order:

```text
1. app-config.yaml (base)
2. app-config.local.yaml (local overrides, gitignored)
3. app-config.production.yaml (when NODE_ENV=production)
4. Environment variables (APP_CONFIG_* prefix)
```

### Core Configuration (app-config.yaml)

```yaml
app:
  title: My Company Developer Portal
  baseUrl: http://localhost:3000
  support:
    url: https://github.com/my-org/backstage/issues
    items:
      - title: Issues
        icon: github
        links:
          - url: https://github.com/my-org/backstage/issues
            title: GitHub Issues

organization:
  name: My Company

backend:
  baseUrl: http://localhost:7007
  listen:
    port: 7007
  csp:
    connect-src: ["'self'", 'http:', 'https:']
  cors:
    origin: http://localhost:3000
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  database:
    client: better-sqlite3
    connection: ':memory:'
  cache:
    store: memory
  reading:
    allow:
      - host: example.com
      - host: '*.mozilla.org'

integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

proxy:
  '/circleci/api':
    target: https://circleci.com/api/v1.1
    headers:
      Circle-Token: ${CIRCLECI_AUTH_TOKEN}

techdocs:
  builder: 'local'
  generator:
    runIn: 'local'
  publisher:
    type: 'local'

auth:
  environment: development
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}

scaffolder:
  defaultAuthor:
    name: Scaffolder
    email: scaffolder@example.com
  defaultCommitMessage: 'Initial commit from Backstage scaffolder'

catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location, Template]
  locations:
    - type: file
      target: ../../examples/entities.yaml
    - type: file
      target: ../../examples/template/template.yaml
      rules:
        - allow: [Template]
    - type: file
      target: ../../examples/org.yaml
      rules:
        - allow: [User, Group]
```

### Environment-Specific Configuration

**app-config.production.yaml:**

```yaml
app:
  baseUrl: https://backstage.mycompany.com

backend:
  baseUrl: https://backstage.mycompany.com
  listen:
    port: 7007
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      database: backstage
      ssl:
        rejectUnauthorized: false

techdocs:
  builder: 'external'
  publisher:
    type: 'awsS3'
    awsS3:
      bucketName: ${TECHDOCS_S3_BUCKET}
      region: ${AWS_REGION}

auth:
  environment: production
```

### Environment Variables

Set sensitive values via environment variables:

```bash
# GitHub Integration
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# GitHub OAuth
export AUTH_GITHUB_CLIENT_ID=your-client-id
export AUTH_GITHUB_CLIENT_SECRET=your-client-secret

# PostgreSQL
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=backstage
export POSTGRES_PASSWORD=secret

# TechDocs S3
export TECHDOCS_S3_BUCKET=my-techdocs-bucket
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
```

## Database Setup

### SQLite (Development Only)

Default configuration, suitable for development:

```yaml
backend:
  database:
    client: better-sqlite3
    connection: ':memory:'
```

### PostgreSQL (Production)

**1. Create Database:**

```sql
CREATE DATABASE backstage;
CREATE USER backstage WITH ENCRYPTED PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE backstage TO backstage;
```

**2. Configure Connection:**

```yaml
backend:
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      database: backstage
    # Connection pool settings
    pool:
      min: 2
      max: 10
```

### Database Migrations

Backstage handles migrations automatically on startup. For production, run
migrations separately:

```bash
# Run migrations only
yarn backstage-cli migrations:run
```

## Docker Deployment

### Building the Docker Image

The default Dockerfile is in `packages/backend/Dockerfile`:

```dockerfile
FROM node:20-bookworm-slim

# Install dependencies for native modules
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 g++ build-essential && \
    rm -rf /var/lib/apt/lists/*

# Install isolate-vm dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends libsecret-1-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy repo skeleton first for better caching
COPY yarn.lock package.json packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

# Install production dependencies
RUN yarn install --frozen-lockfile --production --network-timeout 300000

# Copy built application
COPY packages/backend/dist/bundle.tar.gz app-config*.yaml ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

# Configure runtime
ENV NODE_ENV=production
EXPOSE 7007

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
```

### Build Commands

```bash
# Build the frontend and backend
yarn build:backend --config app-config.yaml --config app-config.production.yaml

# Build Docker image
yarn build-image

# Or manually with Docker
docker build -t backstage:latest -f packages/backend/Dockerfile .
```

### Docker Compose Setup

```yaml
# docker-compose.yml
version: '3.8'

services:
  backstage:
    build:
      context: .
      dockerfile: packages/backend/Dockerfile
    ports:
      - '7007:7007'
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_USER=backstage
      - POSTGRES_PASSWORD=backstage
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - AUTH_GITHUB_CLIENT_ID=${AUTH_GITHUB_CLIENT_ID}
      - AUTH_GITHUB_CLIENT_SECRET=${AUTH_GITHUB_CLIENT_SECRET}
    depends_on:
      - postgres

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=backstage
      - POSTGRES_PASSWORD=backstage
      - POSTGRES_DB=backstage
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - '5432:5432'

volumes:
  postgres_data:
```

### Running with Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f backstage

# Stop services
docker-compose down
```

## Kubernetes Deployment

### Basic Kubernetes Manifests

**Namespace:**

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: backstage
```

**ConfigMap:**

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backstage-config
  namespace: backstage
data:
  app-config.yaml: |
    app:
      title: Developer Portal
      baseUrl: https://backstage.example.com

    backend:
      baseUrl: https://backstage.example.com
      listen:
        port: 7007
      database:
        client: pg
        connection:
          host: ${POSTGRES_HOST}
          port: ${POSTGRES_PORT}
          user: ${POSTGRES_USER}
          password: ${POSTGRES_PASSWORD}
          database: backstage
```

**Secret:**

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: backstage-secrets
  namespace: backstage
type: Opaque
stringData:
  GITHUB_TOKEN: 'ghp_xxxxxxxxxxxx'
  POSTGRES_PASSWORD: 'your-password'
  AUTH_GITHUB_CLIENT_ID: 'your-client-id'
  AUTH_GITHUB_CLIENT_SECRET: 'your-client-secret'
```

**Deployment:**

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: backstage
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      serviceAccountName: backstage
      containers:
        - name: backstage
          image: backstage:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 7007
          envFrom:
            - secretRef:
                name: backstage-secrets
          env:
            - name: POSTGRES_HOST
              value: backstage-postgres
            - name: POSTGRES_PORT
              value: '5432'
            - name: POSTGRES_USER
              value: backstage
          volumeMounts:
            - name: config
              mountPath: /app/app-config.yaml
              subPath: app-config.yaml
          resources:
            requests:
              memory: '512Mi'
              cpu: '250m'
            limits:
              memory: '2Gi'
              cpu: '1000m'
          readinessProbe:
            httpGet:
              path: /healthcheck
              port: 7007
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /healthcheck
              port: 7007
            initialDelaySeconds: 60
            periodSeconds: 30
      volumes:
        - name: config
          configMap:
            name: backstage-config
```

**Service:**

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: backstage
spec:
  selector:
    app: backstage
  ports:
    - port: 80
      targetPort: 7007
  type: ClusterIP
```

**Ingress:**

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage
  namespace: backstage
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - backstage.example.com
      secretName: backstage-tls
  rules:
    - host: backstage.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backstage
                port:
                  number: 80
```

### Apply Manifests

```bash
# Apply all manifests
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Check status
kubectl get pods -n backstage
kubectl logs -f deployment/backstage -n backstage
```

## Helm Chart Deployment

### Using the Official Backstage Helm Chart

```bash
# Add the Backstage Helm repository
helm repo add backstage https://backstage.github.io/charts
helm repo update

# Install with default values
helm install backstage backstage/backstage -n backstage --create-namespace

# Install with custom values
helm install backstage backstage/backstage \
  -n backstage \
  --create-namespace \
  -f values.yaml
```

### Custom values.yaml

```yaml
# values.yaml
backstage:
  image:
    registry: docker.io
    repository: your-org/backstage
    tag: latest

  appConfig:
    app:
      title: My Company Portal
      baseUrl: https://backstage.example.com
    backend:
      baseUrl: https://backstage.example.com
      database:
        client: pg
        connection:
          host: backstage-postgresql
          port: 5432
          user: backstage
          password: ${POSTGRES_PASSWORD}

  extraEnvVars:
    - name: GITHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: github-token

  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 2Gi
      cpu: 1000m

postgresql:
  enabled: true
  auth:
    username: backstage
    password: backstage
    database: backstage

ingress:
  enabled: true
  className: nginx
  host: backstage.example.com
  tls:
    enabled: true
    secretName: backstage-tls
```

## Production Considerations

### High Availability

```yaml
# deployment.yaml for HA
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: backstage
                topologyKey: kubernetes.io/hostname
```

### Resource Recommendations

| Environment | Memory | CPU   | Replicas |
| ----------- | ------ | ----- | -------- |
| Development | 512Mi  | 250m  | 1        |
| Staging     | 1Gi    | 500m  | 2        |
| Production  | 2Gi    | 1000m | 3+       |

### Security Hardening

```yaml
# Pod Security Context
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: backstage
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
```

### Monitoring

Add Prometheus annotations:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: 'true'
    prometheus.io/port: '7007'
    prometheus.io/path: '/metrics'
```

### Backup Strategy

1. **Database Backups**: Regular PostgreSQL backups
2. **Configuration**: Store in Git
3. **TechDocs**: If using S3, enable bucket versioning

## Upgrading Backstage

### Version Upgrade Process

```bash
# Check current version
yarn backstage-cli info

# Update to latest
yarn backstage-cli versions:bump

# Review changes in package.json files
git diff

# Install updated dependencies
yarn install

# Run any migrations
yarn backstage-cli migrations:run

# Test locally
yarn dev

# Build and deploy
yarn build:backend
```

### Breaking Changes

Always check the changelog for breaking changes:

- [Backstage Releases](https://github.com/backstage/backstage/releases)
- [Migration Guides](https://backstage.io/docs/getting-started/keeping-backstage-updated)

## Troubleshooting

### Common Issues

#### 1. Database Connection Errors

```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Test connection
psql -h localhost -U backstage -d backstage

# Check logs
kubectl logs deployment/backstage -n backstage | grep -i postgres
```

#### 2. Plugin Loading Errors

```bash
# Clear cache and reinstall
rm -rf node_modules
yarn cache clean
yarn install
```

#### 3. Memory Issues

```bash
# Increase Node.js memory
export NODE_OPTIONS="--max-old-space-size=4096"
```

#### 4. CORS Errors

Check `app-config.yaml`:

```yaml
backend:
  cors:
    origin: https://your-frontend-url.com
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
```

### Useful Commands

```bash
# Check Backstage health
curl http://localhost:7007/healthcheck

# View backend logs
yarn start-backend --verbose

# Validate configuration
yarn backstage-cli config:check

# List installed plugins
yarn backstage-cli info
```

### Log Levels

Configure logging in `app-config.yaml`:

```yaml
backend:
  logging:
    level: debug # error, warn, info, debug
```

## Next Steps

- [Software Catalog Deep Dive](./backstage-software-catalog.md)
- [Authentication Setup](./backstage-authentication.md)
- [Plugin Development](./backstage-plugins.md)

## References

- [Official Installation Guide](https://backstage.io/docs/getting-started/)
- [Configuration Reference](https://backstage.io/docs/conf/)
- [Deployment Guide](https://backstage.io/docs/deployment/)
- [Backstage Helm Chart](https://github.com/backstage/charts)
