SHELL := /bin/bash
.DEFAULT_GOAL := help
.NOTPARALLEL:

CLUSTER_NAME ?= kuber-in-prod
KUBE_CONTEXT := kind-$(CLUSTER_NAME)
ARGOCD_CHART_VERSION ?= 10.11.6
TIMEOUT ?= 10m
KUBECTL := kubectl --context $(KUBE_CONTEXT)

.PHONY: help check-tools cluster-up cluster-down platform-infra \
	argocd-install gitops-apply bootstrap argocd-password port-forward \
	grafana-password grafana-port-forward

help: ## Show all available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "%-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-tools: ## Check docker, kind, kubectl, and helm in WSL
	@for tool in docker kind kubectl helm; do \
		command -v $$tool >/dev/null 2>&1 || { echo "Missing required tool: $$tool"; exit 1; }; \
	done
	@docker info >/dev/null 2>&1 || { echo "Docker is unavailable. Check the WSL integration in Docker Desktop."; exit 1; }

cluster-up: check-tools ## Create the local Kind cluster
	@if kind get clusters 2>/dev/null | grep -Fxq "$(CLUSTER_NAME)"; then \
		echo "Kind cluster $(CLUSTER_NAME) already exists"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --wait $(TIMEOUT); \
	fi
	@$(KUBECTL) cluster-info >/dev/null

platform-infra: cluster-up ## Apply the namespaces, RBAC, and token Secrets
	$(KUBECTL) apply -f manifests/namespaces.yaml
	$(KUBECTL) apply -f manifests/rbac.yaml
	$(KUBECTL) apply -f manifests/20-service-account-tokens.yaml

argocd-install: platform-infra ## Install Argo CD from the official Helm chart
	helm upgrade --install argocd oci://ghcr.io/argoproj/argo-helm/argo-cd \
		--kube-context $(KUBE_CONTEXT) \
		--version $(ARGOCD_CHART_VERSION) \
		--namespace argocd \
		--create-namespace \
		--values gitops/argocd-values.yaml \
		--wait \
		--timeout $(TIMEOUT)

gitops-apply: argocd-install ## Create the root Argo CD Application
	$(KUBECTL) apply -f gitops/root-application.yaml

bootstrap: gitops-apply ## Bootstrap the complete GitOps infrastructure
	@echo "Bootstrap started. Follow the Applications in the Argo CD UI."

argocd-password: ## Show the initial Argo CD admin password
	@$(KUBECTL) get secret argocd-initial-admin-secret -n argocd \
		-o jsonpath='{.data.password}' | base64 -d; echo

port-forward: ## Expose the Argo CD UI at https://localhost:8080
	$(KUBECTL) port-forward service/argocd-server -n argocd 8080:443

grafana-password: ## Show the Grafana admin password
	@$(KUBECTL) get secret monitoring-grafana -n monitoring \
		-o jsonpath='{.data.admin-password}' | base64 -d; echo

grafana-port-forward: ## Expose the Grafana UI at http://localhost:3000
	$(KUBECTL) port-forward service/monitoring-grafana -n monitoring 3000:80

cluster-down: check-tools ## Delete the Kind cluster
	kind delete cluster --name $(CLUSTER_NAME)
