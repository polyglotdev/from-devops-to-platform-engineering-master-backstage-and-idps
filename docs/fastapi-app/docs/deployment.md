# Deployment Guide

This guide covers deploying the FastAPI Platform Demo to Kubernetes using Helm and ArgoCD.

## Prerequisites

- Kubernetes cluster (local: OrbStack, minikube, kind, or cloud provider)
- kubectl configured
- Helm 3.x installed
- ArgoCD installed (for GitOps deployment)

## Deployment Methods

### Method 1: Direct Helm Installation

The simplest way to deploy the application.

```bash
# Clone the repository
git clone https://github.com/polyglotdev/from-devops-to-platform-engineering-master-backstage-and-idps.git
cd from-devops-to-platform-engineering-master-backstage-and-idps

# Install the Helm chart
helm install fastapi-app ./helm/fastapi-app \
  --namespace platform-demo \
  --create-namespace

# Verify the deployment
kubectl get pods -n platform-demo
kubectl get svc -n platform-demo
kubectl get ingress -n platform-demo
```

#### Customizing Values

Create a custom values file:

```yaml
# custom-values.yaml
replicaCount: 3

image:
  repository: domniniquehallan/python-fastapi-app
  tag: "latest"

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi

ingress:
  enabled: true
  host: my-fastapi.example.com
```

Apply with:

```bash
helm install fastapi-app ./helm/fastapi-app \
  --namespace platform-demo \
  --create-namespace \
  -f custom-values.yaml
```

---

### Method 2: GitOps with ArgoCD

ArgoCD provides declarative GitOps-based deployment with automatic sync.

#### Step 1: Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

#### Step 2: Deploy the Application

```bash
# Apply the ArgoCD Application manifest
kubectl apply -f argocd/applications/fastapi-app.yaml
```

The ArgoCD Application is configured with:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fastapi-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/polyglotdev/from-devops-to-platform-engineering-master-backstage-and-idps.git
    targetRevision: main
    path: helm/fastapi-app
  destination:
    server: https://kubernetes.default.svc
    namespace: platform-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### Step 3: Access ArgoCD UI

```bash
# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 and login with username `admin`.

---

### Method 3: Raw Kubernetes Manifests

For environments without Helm:

```bash
# Apply all manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

---

## Helm Chart Configuration

### Available Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of pod replicas | `2` |
| `image.repository` | Docker image repository | `domniniquehallan/python-fastapi-app` |
| `image.tag` | Docker image tag | `1.1.0` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `8000` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class | `nginx` |
| `ingress.host` | Ingress hostname | `fastapi-app.k8s.orb.local` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `256Mi` |

### Health Probes Configuration

```yaml
probes:
  liveness:
    path: /api/v1/healthz
    initialDelaySeconds: 10
    periodSeconds: 30
    timeoutSeconds: 10
    failureThreshold: 3
  readiness:
    path: /api/v1/ready
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
```

### Security Context

The chart enforces security best practices:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

---

## ArgoCD Image Updater

The application is configured for automatic image updates when new versions are pushed.

### How It Works

1. Docker Build workflow pushes new tagged images
2. ArgoCD Image Updater detects new semver tags
3. Image Updater commits updated tag to values.yaml
4. ArgoCD syncs the change to the cluster

### Configuration

The ArgoCD Application includes these annotations:

```yaml
annotations:
  argocd-image-updater.argoproj.io/image-list: app=domniniquehallan/python-fastapi-app
  argocd-image-updater.argoproj.io/app.update-strategy: semver
  argocd-image-updater.argoproj.io/app.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
  argocd-image-updater.argoproj.io/write-back-method: git
  argocd-image-updater.argoproj.io/git-branch: main
```

---

## Accessing the Application

### Local Kubernetes (OrbStack)

With OrbStack, the ingress is automatically accessible:

```bash
curl http://fastapi-app.k8s.orb.local/api/v1/hello
```

### Port Forwarding

Without ingress, use port-forward:

```bash
kubectl port-forward svc/fastapi-app 8000:80 -n platform-demo
curl http://localhost:8000/api/v1/hello
```

### Node Port

Modify the service type:

```bash
helm upgrade fastapi-app ./helm/fastapi-app \
  --set service.type=NodePort \
  -n platform-demo
```

---

## Scaling

### Manual Scaling

```bash
# Scale to 5 replicas
kubectl scale deployment fastapi-app --replicas=5 -n platform-demo

# Or via Helm
helm upgrade fastapi-app ./helm/fastapi-app \
  --set replicaCount=5 \
  -n platform-demo
```

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fastapi-app
  namespace: platform-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fastapi-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

---

## Troubleshooting

### Common Issues

**Pods not starting**

```bash
# Check pod status
kubectl describe pod -l app.kubernetes.io/name=fastapi-app -n platform-demo

# Check logs
kubectl logs -l app.kubernetes.io/name=fastapi-app -n platform-demo
```

**Readiness probe failing**

```bash
# Check the readiness state
kubectl exec -it deploy/fastapi-app -n platform-demo -- curl localhost:8000/api/v1/ready

# Reset readiness if toggled off
kubectl exec -it deploy/fastapi-app -n platform-demo -- \
  curl -X POST "localhost:8000/api/v1/ready/toggle?ready=true"
```

**Image pull errors**

```bash
# Check if imagePullSecrets are configured
kubectl get pods -n platform-demo -o yaml | grep -A 5 imagePullSecrets

# Create Docker Hub secret if needed
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=docker.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_TOKEN \
  -n platform-demo
```

**ArgoCD not syncing**

```bash
# Check application status
argocd app get fastapi-app

# Force sync
argocd app sync fastapi-app --force
```
