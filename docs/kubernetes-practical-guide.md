# Kubernetes Practical Guide

A hands-on guide to understanding Kubernetes concepts through deploying a real application. This guide explains not just _what_ to do, but _why_ things work the way they do.

## Table of Contents

- [The Big Picture](#the-big-picture)
- [Deploying an Application](#deploying-an-application)
- [Understanding Pods and Containers](#understanding-pods-and-containers)
- [What Does "Listening on a Port" Mean?](#what-does-listening-on-a-port-mean)
- [Services: The Stable Endpoint](#services-the-stable-endpoint)
- [Ingress: External Access](#ingress-external-access)
- [Namespaces: Organizational Boundaries](#namespaces-organizational-boundaries)
- [Local Kubernetes Options](#local-kubernetes-options)
- [Common Commands Reference](#common-commands-reference)

---

## The Big Picture

When you deploy an application to Kubernetes, multiple components work together to make your app accessible. Here is the complete flow from your browser to your application:

```mermaid
flowchart TB
    subgraph External["External Access"]
        Browser["Browser Request
        fastapi-app.k8s.orb.local"]
    end

    subgraph Cluster["Kubernetes Cluster"]
        subgraph IngressNS["ingress-nginx namespace"]
            IC["Ingress Controller
            (NGINX pods)"]
        end

        subgraph AppNS["platform-demo namespace"]
            IR["Ingress Resource
            (routing rules)"]
            SVC["Service
            fastapi-app:80"]

            subgraph Pods["Pods"]
                P1["Pod 1
                :8000"]
                P2["Pod 2
                :8000"]
            end
        end
    end

    Browser --> IC
    IC -->|reads| IR
    IC -->|routes to| SVC
    SVC --> P1
    SVC --> P2

    style External fill:#e3f2fd,stroke:#1565c0,color:#000
    style IngressNS fill:#fff3e0,stroke:#e65100,color:#000
    style AppNS fill:#e8f5e9,stroke:#2e7d32,color:#000
    style IC fill:#ffcc80,stroke:#e65100,color:#000
    style IR fill:#ffe0b2,stroke:#e65100,color:#000
    style SVC fill:#a5d6a7,stroke:#2e7d32,color:#000
    style P1 fill:#c8e6c9,stroke:#2e7d32,color:#000
    style P2 fill:#c8e6c9,stroke:#2e7d32,color:#000
    style Browser fill:#90caf9,stroke:#1565c0,color:#000
```

Each layer serves a specific purpose:

| Layer              | What It Does                                         | Analogy                 |
| ------------------ | ---------------------------------------------------- | ----------------------- |
| Ingress Controller | Receives all external traffic, routes based on rules | Building receptionist   |
| Ingress Resource   | Defines routing rules (hostname to service mapping)  | Directory listing       |
| Service            | Stable endpoint, load balances across pods           | Department phone number |
| Pods               | Run your actual application containers               | Individual employees    |

---

## Deploying an Application

### The Deployment Process

When you run `kubectl apply -f k8s/`, Kubernetes processes your manifest files and creates resources in the cluster:

```mermaid
sequenceDiagram
    participant You
    participant API as API Server
    participant NS as Namespace
    participant Deploy as Deployment
    participant RS as ReplicaSet
    participant Pod as Pods

    You->>API: kubectl apply -f k8s/
    API->>NS: Create namespace platform-demo
    API->>Deploy: Create Deployment
    Deploy->>RS: Create ReplicaSet
    RS->>Pod: Create Pod 1
    RS->>Pod: Create Pod 2
    Note over RS,Pod: ReplicaSet ensures desired replica count
```

### What Each Manifest Does

Your `k8s/` directory contains four files that work together:

```mermaid
flowchart LR
    subgraph Manifests["Your Manifest Files"]
        NS["namespace.yaml
        Creates isolated space"]
        DEP["deployment.yaml
        Defines pod blueprint"]
        SVC["service.yaml
        Creates stable endpoint"]
        ING["ingress.yaml
        Configures external access"]
    end

    subgraph Created["Created Resources"]
        N["Namespace
        platform-demo"]
        D["Deployment"]
        R["ReplicaSet"]
        P["Pods (x2)"]
        S["Service"]
        I["Ingress"]
    end

    NS --> N
    DEP --> D
    D --> R
    R --> P
    SVC --> S
    ING --> I

    style Manifests fill:#e3f2fd,stroke:#1565c0,color:#000
    style Created fill:#e8f5e9,stroke:#2e7d32,color:#000
    style NS fill:#bbdefb,stroke:#1565c0,color:#000
    style DEP fill:#bbdefb,stroke:#1565c0,color:#000
    style SVC fill:#bbdefb,stroke:#1565c0,color:#000
    style ING fill:#bbdefb,stroke:#1565c0,color:#000
```

### Deployment Order Matters

When applying all manifests at once, the namespace must exist before other resources can be created in it. If you see errors like "namespace not found", simply run the command again:

```bash
# First run might show errors (race condition)
kubectl apply -f k8s/

# Second run succeeds (namespace now exists)
kubectl apply -f k8s/
```

---

## Understanding Pods and Containers

### The Deployment Hierarchy

A Deployment does not directly create Pods. Instead, it creates a ReplicaSet, which manages the Pods:

```mermaid
flowchart TB
    subgraph Deployment["Deployment: fastapi-app"]
        direction TB
        D["Manages desired state
        replicas: 2"]
    end

    subgraph ReplicaSet["ReplicaSet: fastapi-app-94c7cf9c6"]
        direction TB
        RS["Ensures pod count
        Current: 2, Desired: 2"]
    end

    subgraph Pods["Managed Pods"]
        P1["Pod: fastapi-app-94c7cf9c6-n9wnt"]
        P2["Pod: fastapi-app-94c7cf9c6-qmx6j"]
    end

    subgraph Containers["Inside Each Pod"]
        C1["Container: fastapi-app
        Image: python-fastapi-app:v1
        Port: 8000"]
    end

    D --> RS
    RS --> P1
    RS --> P2
    P1 --> C1
    P2 --> C1

    style Deployment fill:#e3f2fd,stroke:#1565c0,color:#000
    style ReplicaSet fill:#fff3e0,stroke:#e65100,color:#000
    style Pods fill:#e8f5e9,stroke:#2e7d32,color:#000
    style Containers fill:#fce4ec,stroke:#c2185b,color:#000
```

### Why ReplicaSets Matter

When a Pod dies (crashes, gets deleted, node fails), the ReplicaSet automatically creates a new one to maintain the desired count:

```mermaid
flowchart LR
    subgraph Before["Before: Pod Crashes"]
        RS1["ReplicaSet
        Desired: 2
        Current: 2"]
        P1a["Pod 1 (healthy)"]
        P2a["Pod 2 (crashed)"]
    end

    subgraph After["After: Self-Healing"]
        RS2["ReplicaSet
        Desired: 2
        Current: 2"]
        P1b["Pod 1 (healthy)"]
        P3["Pod 3 (new)"]
    end

    Before --> After

    style RS1 fill:#fff3e0,stroke:#e65100,color:#000
    style RS2 fill:#fff3e0,stroke:#e65100,color:#000
    style P1a fill:#c8e6c9,stroke:#2e7d32,color:#000
    style P2a fill:#ffcdd2,stroke:#c62828,color:#000
    style P1b fill:#c8e6c9,stroke:#2e7d32,color:#000
    style P3 fill:#c8e6c9,stroke:#2e7d32,color:#000
```

### What the Deployment Defines

The Deployment is the blueprint for your Pods. It specifies:

| Setting           | Purpose                                            |
| ----------------- | -------------------------------------------------- |
| `replicas`        | How many identical Pods to run                     |
| `image`           | Which container image to use                       |
| `ports`           | Which ports the container uses                     |
| `resources`       | CPU and memory requests/limits                     |
| `probes`          | Health checks (liveness and readiness)             |
| `securityContext` | Security settings (non-root, read-only filesystem) |
| `env`             | Environment variables                              |

---

## What Does "Listening on a Port" Mean?

When we say an application "listens on port 8000", it means the application has claimed that port and is waiting for incoming connections.

### The Socket Metaphor

Think of ports as numbered doors on a building. Your application stands at door 8000, waiting for someone to knock:

```mermaid
flowchart TB
    subgraph Container["Container (The Building)"]
        direction LR
        P1["Port 22
        (empty)"]
        P2["Port 80
        (empty)"]
        P3["Port 8000
        FastAPI waiting"]
        P4["Port 9000
        (empty)"]
    end

    REQ["Incoming Request"] --> P3

    style Container fill:#e3f2fd,stroke:#1565c0,color:#000
    style P1 fill:#eceff1,stroke:#607d8b,color:#000
    style P2 fill:#eceff1,stroke:#607d8b,color:#000
    style P3 fill:#c8e6c9,stroke:#2e7d32,color:#000
    style P4 fill:#eceff1,stroke:#607d8b,color:#000
    style REQ fill:#fff3e0,stroke:#e65100,color:#000
```

### What Happens Under the Hood

Your FastAPI application (via Uvicorn) does something like this:

```python
# Simplified - what happens when your app starts
socket = create_socket()
socket.bind('0.0.0.0', 8000)  # "I claim port 8000"
socket.listen()               # "I am waiting for connections"

while True:
    connection = socket.accept()  # Blocks here, ear to the ground
    handle_request(connection)    # Someone knocked, handle it
```

### The Meaning of 0.0.0.0

The address your app binds to determines who can connect:

| Address          | Meaning                | Who Can Connect           |
| ---------------- | ---------------------- | ------------------------- |
| `0.0.0.0:8000`   | All network interfaces | Anyone (external traffic) |
| `127.0.0.1:8000` | Localhost only         | Same machine only         |

Your FastAPI app binds to `0.0.0.0:8000` so it can receive traffic from outside the container (from the Service).

### Container Port Declaration

The `containerPort: 8000` in your Deployment is mostly documentation. The port is opened by your application, not by Kubernetes:

```mermaid
flowchart LR
    subgraph Deployment["Deployment YAML"]
        CP["containerPort: 8000
        (documentation)"]
    end

    subgraph App["Your FastAPI App"]
        UV["uvicorn.run(port=8000)
        (actually opens port)"]
    end

    subgraph Result["Result"]
        P["Port 8000 is open
        and listening"]
    end

    CP -.->|hints| Result
    UV -->|creates| Result

    style Deployment fill:#e3f2fd,stroke:#1565c0,color:#000
    style App fill:#e8f5e9,stroke:#2e7d32,color:#000
    style Result fill:#fff3e0,stroke:#e65100,color:#000
```

---

## Services: The Stable Endpoint

### The Problem Services Solve

Pods are ephemeral. Every time a Pod restarts, crashes, or scales, it gets a new IP address:

```mermaid
flowchart TB
    subgraph Monday["Monday"]
        P1M["Pod fastapi-app-abc
        IP: 192.168.1.50"]
        P2M["Pod fastapi-app-def
        IP: 192.168.1.51"]
    end

    subgraph Tuesday["Tuesday (pod crashed)"]
        P1T["Pod fastapi-app-abc
        IP: 192.168.1.50
        (died)"]
        P3T["Pod fastapi-app-ghi
        IP: 192.168.1.87
        (new pod, new IP)"]
    end

    Monday --> Tuesday

    style P1M fill:#c8e6c9,stroke:#2e7d32,color:#000
    style P2M fill:#c8e6c9,stroke:#2e7d32,color:#000
    style P1T fill:#ffcdd2,stroke:#c62828,color:#000
    style P3T fill:#c8e6c9,stroke:#2e7d32,color:#000
```

If another application hardcoded `192.168.1.50`, it would break when that Pod dies.

### How Services Provide Stability

A Service gets its own IP that never changes. It watches for Pods matching its selector and maintains a list of their current IPs:

```mermaid
flowchart TB
    subgraph Service["Service: fastapi-app"]
        SVC["ClusterIP: 192.168.194.100
        (stable forever)
        DNS: fastapi-app.platform-demo.svc.cluster.local"]
    end

    subgraph Pods["Backend Pods (IPs change)"]
        P1["Pod A: 192.168.1.50"]
        P2["Pod B: 192.168.1.51"]
    end

    subgraph Clients["Other Apps"]
        C1["App calling
        fastapi-app:80"]
    end

    C1 --> SVC
    SVC -->|tracks| P1
    SVC -->|tracks| P2

    style Service fill:#fff3e0,stroke:#e65100,color:#000
    style Pods fill:#e8f5e9,stroke:#2e7d32,color:#000
    style Clients fill:#e3f2fd,stroke:#1565c0,color:#000
```

### What Services Provide

| Feature          | Description                                          |
| ---------------- | ---------------------------------------------------- |
| Stable IP        | Service IP never changes, even when Pods come and go |
| DNS Name         | `fastapi-app.platform-demo.svc.cluster.local`        |
| Load Balancing   | Distributes requests across healthy Pods             |
| Port Translation | Service listens on 80, forwards to Pod port 8000     |

### Load Balancing in Action

With 2 replicas, the Service distributes requests between them:

```mermaid
sequenceDiagram
    participant Client
    participant Service as Service (port 80)
    participant Pod1 as Pod 1 (port 8000)
    participant Pod2 as Pod 2 (port 8000)

    Client->>Service: Request 1
    Service->>Pod1: Forward to Pod 1
    Pod1-->>Service: Response
    Service-->>Client: Response

    Client->>Service: Request 2
    Service->>Pod2: Forward to Pod 2
    Pod2-->>Service: Response
    Service-->>Client: Response

    Client->>Service: Request 3
    Service->>Pod1: Forward to Pod 1
    Pod1-->>Service: Response
    Service-->>Client: Response
```

---

## Ingress: External Access

### Ingress Controller vs Ingress Resource

There are two distinct concepts, both called "Ingress":

```mermaid
flowchart TB
    subgraph Controller["Ingress Controller (ingress-nginx namespace)"]
        IC["NGINX Pods
        Running application
        Receives all external HTTP traffic
        Installed once per cluster"]
    end

    subgraph Resources["Ingress Resources (your namespaces)"]
        IR1["Ingress: fastapi-app
        Host: fastapi-app.k8s.orb.local
        Routes to: fastapi-app service"]
        IR2["Ingress: another-app
        Host: another-app.k8s.orb.local
        Routes to: another-app service"]
    end

    IC -->|reads and applies| IR1
    IC -->|reads and applies| IR2

    style Controller fill:#fff3e0,stroke:#e65100,color:#000
    style Resources fill:#e8f5e9,stroke:#2e7d32,color:#000
    style IC fill:#ffcc80,stroke:#e65100,color:#000
    style IR1 fill:#a5d6a7,stroke:#2e7d32,color:#000
    style IR2 fill:#a5d6a7,stroke:#2e7d32,color:#000
```

| Component          | What It Is                              | How Many            |
| ------------------ | --------------------------------------- | ------------------- |
| Ingress Controller | Running NGINX pods that receive traffic | One per cluster     |
| Ingress Resource   | YAML routing rules                      | One per app/service |

### The Receptionist Analogy

Think of the Ingress Controller as a building receptionist, and Ingress Resources as the directory:

```mermaid
flowchart TB
    subgraph Building["Your Kubernetes Cluster"]
        Receptionist["Ingress Controller
        (Receptionist at entrance)"]

        subgraph Directory["Ingress Resources (Directory)"]
            D1["fastapi-app.k8s.orb.local -> Room 80"]
            D2["api.k8s.orb.local -> Room 3000"]
        end

        subgraph Rooms["Services (Rooms)"]
            R1["Service: fastapi-app
            (Room 80)"]
            R2["Service: api-service
            (Room 3000)"]
        end
    end

    V["Visitor asking for
    fastapi-app.k8s.orb.local"] --> Receptionist
    Receptionist -->|looks up| Directory
    Receptionist -->|directs to| R1

    style Building fill:#fce4ec,stroke:#c2185b,color:#000
    style Receptionist fill:#fff3e0,stroke:#e65100,color:#000
    style Directory fill:#e3f2fd,stroke:#1565c0,color:#000
    style Rooms fill:#e8f5e9,stroke:#2e7d32,color:#000
```

### Installing the Ingress Controller

The Ingress Controller is installed once per cluster:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

This creates the NGINX pods in the `ingress-nginx` namespace. Verify with:

```bash
kubectl get pods -n ingress-nginx
```

### Your Ingress Resource

Your `k8s/ingress.yaml` defines the routing rule:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fastapi-app
  namespace: platform-demo
spec:
  ingressClassName: nginx
  rules:
    - host: fastapi-app.k8s.orb.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fastapi-app
                port:
                  number: 80
```

This tells the controller: "When someone requests `fastapi-app.k8s.orb.local`, send them to the `fastapi-app` service on port 80."

---

## Namespaces: Organizational Boundaries

### What Namespaces Provide

Namespaces are logical partitions within a cluster. Think of them as cubby holes or folders:

```mermaid
flowchart TB
    subgraph Cluster["Kubernetes Cluster"]
        subgraph NS1["kube-system"]
            KD["CoreDNS"]
            KS["Scheduler"]
        end

        subgraph NS2["ingress-nginx"]
            IC["NGINX Controller"]
        end

        subgraph NS3["platform-demo"]
            D1["Deployment: fastapi-app"]
            S1["Service: fastapi-app"]
            I1["Ingress: fastapi-app"]
            P1["Pod 1"]
            P2["Pod 2"]
        end

        subgraph NS4["default"]
            Empty["(empty)"]
        end
    end

    style Cluster fill:#fafafa,stroke:#9e9e9e,color:#000
    style NS1 fill:#ffcdd2,stroke:#c62828,color:#000
    style NS2 fill:#fff3e0,stroke:#e65100,color:#000
    style NS3 fill:#c8e6c9,stroke:#2e7d32,color:#000
    style NS4 fill:#eceff1,stroke:#607d8b,color:#000
```

### Benefits of Namespaces

| Benefit          | Description                                          |
| ---------------- | ---------------------------------------------------- |
| Name isolation   | Same resource name can exist in different namespaces |
| Resource scoping | Commands can target a specific namespace             |
| Access control   | RBAC can restrict who accesses which namespaces      |
| Resource quotas  | Limit CPU/memory per namespace                       |
| Network policies | Control which namespaces can communicate             |

### Important Note on Isolation

Namespaces provide organizational separation, not hard security isolation. By default, Pods can still communicate across namespaces unless you add NetworkPolicies.

---

## Local Kubernetes Options

### Orbstack vs Minikube

Both provide local single-node Kubernetes clusters, but take different approaches:

```mermaid
flowchart TB
    subgraph Orbstack["Orbstack"]
        O1["Native macOS virtualization"]
        O2["Low resource usage (~200MB)"]
        O3["Seconds to start"]
        O4["Shared Docker images"]
        O5["Built-in *.k8s.orb.local domains"]
        O6["Uses k3s under the hood"]
    end

    subgraph Minikube["Minikube"]
        M1["VM via driver (Docker, VirtualBox)"]
        M2["Higher resource usage (~1-2GB)"]
        M3["30-60+ seconds to start"]
        M4["Separate Docker environment"]
        M5["Requires tunnel/port-forward"]
        M6["Full Kubernetes by default"]
    end

    style Orbstack fill:#c8e6c9,stroke:#2e7d32,color:#000
    style Minikube fill:#bbdefb,stroke:#1565c0,color:#000
```

| Aspect             | Orbstack                              | Minikube                   |
| ------------------ | ------------------------------------- | -------------------------- |
| Platform           | macOS only                            | Cross-platform             |
| Resource usage     | Very low                              | Higher                     |
| Startup time       | Seconds                               | 30-60+ seconds             |
| Docker integration | Shared (images available instantly)   | Separate environment       |
| Networking         | Native (`*.k8s.orb.local` just works) | Requires `minikube tunnel` |
| Multi-cluster      | No                                    | Yes                        |
| K8s distribution   | k3s                                   | Full K8s (or k3s driver)   |

### k3s vs Full Kubernetes

Orbstack uses k3s, a lightweight Kubernetes distribution. Here is what that means:

```mermaid
flowchart LR
    subgraph Full["Full Kubernetes"]
        F1["etcd (distributed database)"]
        F2["Many cloud integrations"]
        F3["All storage drivers"]
        F4["~1GB+ binary"]
        F5["Multiple processes"]
    end

    subgraph K3s["k3s (What Orbstack Uses)"]
        K1["SQLite or embedded etcd"]
        K2["Minimal integrations"]
        K3["Essential storage only"]
        K4["~60MB binary"]
        K5["Single binary"]
    end

    subgraph Same["What Stays the Same"]
        S1["API Server (100% compatible)"]
        S2["All core resources"]
        S3["kubectl works identically"]
        S4["Helm works identically"]
        S5["Your YAML manifests work unchanged"]
    end

    style Full fill:#ffcdd2,stroke:#c62828,color:#000
    style K3s fill:#c8e6c9,stroke:#2e7d32,color:#000
    style Same fill:#bbdefb,stroke:#1565c0,color:#000
```

The key point: k3s is certified Kubernetes. Everything you learn locally transfers directly to production clusters (EKS, GKE, AKS, self-hosted).

---

## Common Commands Reference

### Deploying and Managing

```bash
# Apply all manifests in a directory
kubectl apply -f k8s/

# Delete all resources defined in manifests
kubectl delete -f k8s/

# Delete an entire namespace (and everything in it)
kubectl delete namespace platform-demo

# Restart a deployment (rolling restart)
kubectl rollout restart deployment fastapi-app -n platform-demo
```

### Viewing Resources

```bash
# List pods in a namespace
kubectl get pods -n platform-demo

# List common resources (pods, services, deployments, replicasets)
kubectl get all -n platform-demo

# List everything including ingress
kubectl get all,ingress -n platform-demo

# Watch pods in real-time
kubectl get pods -n platform-demo -w

# Get detailed information about a resource
kubectl describe pod <pod-name> -n platform-demo
```

### Troubleshooting

```bash
# Check pod logs
kubectl logs <pod-name> -n platform-demo

# Follow logs in real-time
kubectl logs -f <pod-name> -n platform-demo

# Get a shell inside a container
kubectl exec -it <pod-name> -n platform-demo -- /bin/sh

# Check events (useful for debugging)
kubectl get events -n platform-demo --sort-by='.lastTimestamp'
```

### Verifying Ingress

```bash
# Check ingress status
kubectl get ingress -n platform-demo

# Verify ingress controller is running
kubectl get pods -n ingress-nginx

# Test the endpoint
curl http://fastapi-app.k8s.orb.local/api/v1/healthz
```

---

## Quick Reference: The Complete Flow

Here is everything working together:

```mermaid
flowchart TB
    subgraph YourFiles["Your Manifest Files"]
        NS["namespace.yaml"]
        DEP["deployment.yaml"]
        SVC["service.yaml"]
        ING["ingress.yaml"]
    end

    subgraph Cluster["Kubernetes Cluster"]
        subgraph IngressNS["ingress-nginx namespace"]
            IC["Ingress Controller
            (NGINX)"]
        end

        subgraph AppNS["platform-demo namespace"]
            subgraph Created["Created Resources"]
                D["Deployment"]
                RS["ReplicaSet"]
                S["Service
                ClusterIP: 192.168.x.x
                Port: 80"]
                IR["Ingress Resource
                Host: fastapi-app.k8s.orb.local"]
            end

            subgraph Pods["Pods"]
                P1["Pod 1
                Container: 8000"]
                P2["Pod 2
                Container: 8000"]
            end
        end
    end

    subgraph External["External Access"]
        Browser["https://fastapi-app.k8s.orb.local"]
    end

    NS -->|creates| AppNS
    DEP -->|creates| D
    D -->|creates| RS
    RS -->|manages| P1
    RS -->|manages| P2
    SVC -->|creates| S
    ING -->|creates| IR

    Browser --> IC
    IC -->|reads| IR
    IC -->|routes to| S
    S --> P1
    S --> P2

    style YourFiles fill:#e3f2fd,stroke:#1565c0,color:#000
    style Cluster fill:#fafafa,stroke:#9e9e9e,color:#000
    style IngressNS fill:#fff3e0,stroke:#e65100,color:#000
    style AppNS fill:#e8f5e9,stroke:#2e7d32,color:#000
    style Created fill:#f1f8e9,stroke:#689f38,color:#000
    style Pods fill:#dcedc8,stroke:#689f38,color:#000
    style External fill:#e1f5fe,stroke:#0288d1,color:#000
```

**Summary:**

1. **Namespace** creates an isolated space for your resources
2. **Deployment** defines what your Pods look like and how many to run
3. **ReplicaSet** (created by Deployment) ensures the desired Pod count
4. **Pods** run your containers with your application code
5. **Service** provides a stable endpoint and load balances across Pods
6. **Ingress Resource** defines routing rules for external access
7. **Ingress Controller** receives external traffic and applies routing rules
