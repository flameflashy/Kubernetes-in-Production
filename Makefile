SHELL := /bin/bash
.DEFAULT_GOAL := help
.NOTPARALLEL:

CLUSTER_NAME ?= kuber-in-prod
KUBE_CONTEXT := kind-$(CLUSTER_NAME)
ARGOCD_CHART_VERSION ?= 10.11.6
TIMEOUT ?= 10m
KUBECTL := kubectl --context $(KUBE_CONTEXT)

.PHONY: help check-tools validate cluster-up cluster-down lab-infra \
	argocd-install gitops-apply bootstrap wait status test test-clean \
	argocd-password port-forward

help: ## Show all available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "%-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-tools: ## Check docker, kind, kubectl, and helm in WSL
	@for tool in docker kind kubectl helm; do \
		command -v $$tool >/dev/null 2>&1 || { echo "Missing required tool: $$tool"; exit 1; }; \
	done
	@docker info >/dev/null 2>&1 || { echo "Docker is unavailable. Check the WSL integration in Docker Desktop."; exit 1; }

validate: ## Lint and render the Helm chart locally
	helm lint charts/lab-policies
	helm template lab-policies charts/lab-policies >/dev/null

cluster-up: check-tools ## Create the local Kind cluster
	@if kind get clusters 2>/dev/null | grep -Fxq "$(CLUSTER_NAME)"; then \
		echo "Kind cluster $(CLUSTER_NAME) already exists"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --wait $(TIMEOUT); \
	fi
	@$(KUBECTL) cluster-info >/dev/null

lab-infra: cluster-up ## Apply Module 02 namespaces, RBAC, and token Secrets
	$(KUBECTL) apply -f manifests/namespaces.yaml
	$(KUBECTL) apply -f manifests/rbac.yaml
	$(KUBECTL) apply -f manifests/20-service-account-tokens.yaml

argocd-install: lab-infra ## Install Argo CD from the official Helm chart
	helm upgrade --install argocd oci://ghcr.io/argoproj/argo-helm/argo-cd \
		--kube-context $(KUBE_CONTEXT) \
		--version $(ARGOCD_CHART_VERSION) \
		--namespace argocd \
		--create-namespace \
		--values gitops/argocd-values.yaml \
		--wait \
		--timeout $(TIMEOUT)

gitops-apply: argocd-install validate ## Create the root Argo CD Application
	$(KUBECTL) apply -f gitops/root-application.yaml

bootstrap: gitops-apply ## Bootstrap the cluster, Argo CD, Kyverno, and policies
	@echo "Bootstrap started. Run 'make wait' to wait for synchronization."

wait: ## Wait for Kyverno and policy synchronization
	$(KUBECTL) wait --for=create application/kyverno -n argocd --timeout=$(TIMEOUT)
	$(KUBECTL) wait --for=create application/lab-policies -n argocd --timeout=$(TIMEOUT)
	$(KUBECTL) wait --for=jsonpath='{.status.sync.status}'=Synced application/kyverno -n argocd --timeout=$(TIMEOUT)
	$(KUBECTL) wait --for=jsonpath='{.status.health.status}'=Healthy application/kyverno -n argocd --timeout=$(TIMEOUT)
	$(KUBECTL) wait --for=jsonpath='{.status.sync.status}'=Synced application/lab-policies -n argocd --timeout=$(TIMEOUT)
	$(KUBECTL) wait --for=jsonpath='{.status.health.status}'=Healthy application/lab-policies -n argocd --timeout=$(TIMEOUT)

status: ## Show cluster, Application, and policy status
	@kind get clusters
	$(KUBECTL) get applications -n argocd
	$(KUBECTL) get pods -n argocd
	$(KUBECTL) get pods -n kyverno
	$(KUBECTL) get clusterpolicies

test: wait ## Apply test Pods and show policy results
	$(KUBECTL) apply -f tests/kyverno/
	$(KUBECTL) wait --for=condition=Ready pod/audit-rootfs-failure -n student01 --timeout=2m
	$(KUBECTL) wait --for=condition=Ready pod/mentor-label-overwrite -n mentor --timeout=2m
	$(KUBECTL) wait --for=condition=Ready pod/default-label-removal -n default --timeout=2m
	$(KUBECTL) get pod audit-rootfs-failure -n student01 --show-labels
	$(KUBECTL) get pod mentor-label-overwrite -n mentor --show-labels
	$(KUBECTL) get pod default-label-removal -n default --show-labels
	$(KUBECTL) get policyreports -A

test-clean: ## Delete the test Pods
	$(KUBECTL) delete -f tests/kyverno/ --ignore-not-found=true

argocd-password: ## Show the initial Argo CD admin password
	@$(KUBECTL) get secret argocd-initial-admin-secret -n argocd \
		-o jsonpath='{.data.password}' | base64 -d; echo

port-forward: ## Expose the Argo CD UI at https://localhost:8080
	$(KUBECTL) port-forward service/argocd-server -n argocd 8080:443

cluster-down: check-tools ## Delete the Kind cluster
	kind delete cluster --name $(CLUSTER_NAME)
