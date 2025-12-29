# Makefile for Platform Engineering Demo
# FastAPI app with ArgoCD, Helm, and Kubernetes

.PHONY: help
.DEFAULT_GOAL := help

# Variables
IMAGE_NAME := domniniquehallan/python-fastapi-app
IMAGE_TAG := v3
NAMESPACE := platform-demo
ARGOCD_NAMESPACE := argocd
APP_URL := https://fastapi-app.k8s.orb.local
ARGOCD_URL := https://argocd.k8s.orb.local

help: ## Display details for all commands
	@awk 'BEGIN {FS = ":.*?##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Python Development

venv-activate: ## Show command to activate virtual environment
	@echo "Run: source .venv/bin/activate"

deps-install: ## Install Python dependencies with uv
	uv sync

deps-add: ## Add a new dependency (usage: make deps-add PKG=package-name)
	uv add $(PKG)

test-local: ## Run local tests with TestClient
	@source .venv/bin/activate && python -c "\
	from fastapi.testclient import TestClient; \
	from main import app; \
	import json; \
	client = TestClient(app); \
	print('Testing /api/v1/healthz:', client.get('/api/v1/healthz').json()); \
	print('Testing /api/v1/ready:', client.get('/api/v1/ready').json()); \
	print('Testing /api/v1/stats:', json.dumps(client.get('/api/v1/stats').json(), indent=2))"

lint: ## Run linter on Python code
	uv run ruff check .

format: ## Format Python code
	uv run ruff format .

##@ Docker

docker-buildx-setup: ## Create and configure buildx builder for multi-arch builds
	docker buildx create --name multiplatform --driver docker-container --use 2>/dev/null || docker buildx use multiplatform

docker-buildx-list: ## List available buildx builders
	docker buildx ls

docker-build: docker-buildx-setup ## Build multi-arch Docker image with SBOM and provenance
	docker buildx build --platform linux/amd64,linux/arm64 \
		--sbom=true --provenance=true \
		-t $(IMAGE_NAME):$(IMAGE_TAG) --push .

docker-build-local: ## Build Docker image for local architecture only
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run: ## Run Docker container locally
	docker run --rm -p 8000:8000 $(IMAGE_NAME):$(IMAGE_TAG)

docker-scout: ## Run Docker Scout security analysis
	docker scout quickview $(IMAGE_NAME):$(IMAGE_TAG)

docker-scout-cves: ## Show CVEs in Docker image
	docker scout cves $(IMAGE_NAME):$(IMAGE_TAG)

docker-scout-recommendations: ## Show Docker Scout recommendations
	docker scout recommendations $(IMAGE_NAME):$(IMAGE_TAG)

##@ Helm

helm-repo-add: ## Add Argo Helm repository
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update argo

helm-template: ## Render Helm templates locally (dry-run)
	helm template fastapi-app helm/fastapi-app

helm-template-argocd: ## Render ArgoCD Helm templates locally (dry-run)
	helm template argocd argo/argo-cd --values helm/argocd/values.yaml

helm-lint: ## Lint Helm chart
	helm lint helm/fastapi-app

helm-install-fastapi: ## Install FastAPI app via Helm (without ArgoCD)
	helm upgrade --install fastapi-app helm/fastapi-app \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait

helm-uninstall-fastapi: ## Uninstall FastAPI app Helm release
	helm uninstall fastapi-app --namespace $(NAMESPACE)

##@ ArgoCD

argocd-install: helm-repo-add ## Install ArgoCD via Helm
	helm upgrade --install argocd argo/argo-cd \
		--namespace $(ARGOCD_NAMESPACE) \
		--create-namespace \
		--values helm/argocd/values.yaml \
		--wait

argocd-uninstall: ## Uninstall ArgoCD
	helm uninstall argocd --namespace $(ARGOCD_NAMESPACE)
	kubectl delete namespace $(ARGOCD_NAMESPACE) --ignore-not-found

argocd-password: ## Get ArgoCD admin password
	@kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

argocd-open: ## Open ArgoCD UI in browser
	@echo "Opening $(ARGOCD_URL)"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@open $(ARGOCD_URL) 2>/dev/null || xdg-open $(ARGOCD_URL) 2>/dev/null || echo "Open $(ARGOCD_URL) in your browser"

argocd-add-repo: ## Add GitHub repo credentials to ArgoCD (usage: make argocd-add-repo USER=username TOKEN=ghp_xxx)
	kubectl create secret generic repo-credentials \
		--namespace $(ARGOCD_NAMESPACE) \
		--from-literal=type=git \
		--from-literal=url=https://github.com/$(USER)/from-devops-to-platform-engineering-master-backstage-and-idps.git \
		--from-literal=username=$(USER) \
		--from-literal=password=$(TOKEN) \
		--dry-run=client -o yaml | kubectl apply -f -
	kubectl label secret repo-credentials -n $(ARGOCD_NAMESPACE) argocd.argoproj.io/secret-type=repository --overwrite

argocd-app-create: ## Create ArgoCD Application for fastapi-app
	kubectl apply -f argocd/applications/fastapi-app.yaml

argocd-app-delete: ## Delete ArgoCD Application for fastapi-app
	kubectl delete -f argocd/applications/fastapi-app.yaml --ignore-not-found

argocd-app-sync: ## Force sync ArgoCD application
	kubectl patch application fastapi-app -n $(ARGOCD_NAMESPACE) \
		--type merge \
		-p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

argocd-app-status: ## Check ArgoCD application status
	kubectl get application -n $(ARGOCD_NAMESPACE) fastapi-app -o wide

##@ Kubernetes

k8s-pods: ## List pods in platform-demo namespace
	kubectl get pods -n $(NAMESPACE)

k8s-pods-wide: ## List pods with additional details
	kubectl get pods -n $(NAMESPACE) -o wide

k8s-pods-images: ## Show which image each pod is running
	@kubectl get pods -n $(NAMESPACE) -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.containers[0].image}{"\n"}{end}'

k8s-services: ## List services in platform-demo namespace
	kubectl get svc -n $(NAMESPACE)

k8s-ingress: ## List ingresses in platform-demo namespace
	kubectl get ingress -n $(NAMESPACE)

k8s-all: ## List all resources in platform-demo namespace
	kubectl get all -n $(NAMESPACE)

k8s-logs: ## Tail logs from fastapi-app pods
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=fastapi-app -f --tail=100

k8s-logs-previous: ## Show logs from previous container instance
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=fastapi-app --previous

k8s-describe-pods: ## Describe pods in platform-demo namespace
	kubectl describe pods -n $(NAMESPACE)

k8s-events: ## Show events in platform-demo namespace
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

k8s-argocd-pods: ## List ArgoCD pods
	kubectl get pods -n $(ARGOCD_NAMESPACE)

k8s-argocd-ingress: ## List ArgoCD ingress
	kubectl get ingress -n $(ARGOCD_NAMESPACE)

k8s-exec: ## Exec into a fastapi-app pod (usage: make k8s-exec)
	kubectl exec -it -n $(NAMESPACE) $$(kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=fastapi-app -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

k8s-port-forward: ## Port forward to fastapi-app (localhost:8000)
	kubectl port-forward -n $(NAMESPACE) svc/fastapi-app 8000:80

k8s-rollout-status: ## Check rollout status
	kubectl rollout status deployment/fastapi-app -n $(NAMESPACE)

k8s-rollout-restart: ## Restart deployment (trigger new pods)
	kubectl rollout restart deployment/fastapi-app -n $(NAMESPACE)

##@ Testing and Debugging

test-healthz: ## Test healthz endpoint
	curl -s $(APP_URL)/api/v1/healthz | jq .

test-ready: ## Test readiness endpoint
	curl -s $(APP_URL)/api/v1/ready | jq .

test-ready-toggle-off: ## Toggle readiness to false (simulate failure)
	curl -s -X POST "$(APP_URL)/api/v1/ready/toggle?ready=false&reason=simulated%20failure" | jq .

test-ready-toggle-on: ## Toggle readiness back to true
	curl -s -X POST "$(APP_URL)/api/v1/ready/toggle?ready=true&reason=recovered" | jq .

test-details: ## Test details endpoint
	curl -s $(APP_URL)/api/v1/details | jq .

test-details-k8s: ## Show Kubernetes metadata from details endpoint
	curl -s $(APP_URL)/api/v1/details | jq '.kubernetes, .uptime, .server.hostname'

test-stats: ## Test stats endpoint
	curl -s $(APP_URL)/api/v1/stats | jq .

test-metrics: ## Test Prometheus metrics endpoint
	curl -s $(APP_URL)/metrics | head -30

test-metrics-http: ## Show HTTP request metrics only
	curl -s $(APP_URL)/metrics | grep "http_request"

test-hello: ## Test hello endpoint
	curl -s $(APP_URL)/api/v1/hello | jq .

test-headers: ## Test request and see response headers
	curl -sv $(APP_URL)/api/v1/hello 2>&1 | grep -E "^< (X-Request-ID|X-Response-Time)"

test-all: ## Run all endpoint tests
	@echo "=== /api/v1/healthz ===" && curl -s $(APP_URL)/api/v1/healthz | jq .
	@echo "\n=== /api/v1/ready ===" && curl -s $(APP_URL)/api/v1/ready | jq .
	@echo "\n=== /api/v1/hello ===" && curl -s $(APP_URL)/api/v1/hello | jq .
	@echo "\n=== /api/v1/stats ===" && curl -s $(APP_URL)/api/v1/stats | jq .
	@echo "\n=== Kubernetes metadata ===" && curl -s $(APP_URL)/api/v1/details | jq '.kubernetes'

##@ Git Operations

git-status: ## Show git status
	git status

git-diff: ## Show git diff
	git diff

git-push: ## Push to main branch
	git push origin main

##@ Full Workflows

setup-all: helm-repo-add argocd-install ## Setup everything: ArgoCD + app
	@echo "Waiting for ArgoCD to be ready..."
	@sleep 10
	@echo "ArgoCD installed. Run 'make argocd-password' to get the admin password"
	@echo "Then run 'make argocd-add-repo USER=your-username TOKEN=your-token' to add repo credentials"
	@echo "Finally run 'make argocd-app-create' to deploy the app"

deploy: docker-build ## Build image, update tag, commit and push (triggers ArgoCD sync)
	@echo "Image built and pushed as $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "Update helm/fastapi-app/values.yaml with the new tag, commit, and push"
	@echo "ArgoCD will automatically sync the changes"

teardown: argocd-app-delete argocd-uninstall ## Remove ArgoCD and application
	kubectl delete namespace $(NAMESPACE) --ignore-not-found
	@echo "Cleanup complete"

status: ## Show overall status of deployment
	@echo "=== ArgoCD Application ==="
	@kubectl get application -n $(ARGOCD_NAMESPACE) fastapi-app 2>/dev/null || echo "Not found"
	@echo "\n=== Pods ==="
	@kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "Namespace not found"
	@echo "\n=== Services ==="
	@kubectl get svc -n $(NAMESPACE) 2>/dev/null || echo "Namespace not found"
	@echo "\n=== Ingress ==="
	@kubectl get ingress -n $(NAMESPACE) 2>/dev/null || echo "Namespace not found"
