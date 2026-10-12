# Kubernetes-in-Production
This course is designed for DevOps, SRE and Platform Engineers who already have a basic understanding of Kubernetes and want to learn how to build, operate and scale production clusters.

## Module 02 - Security and Policy as Code

The initial lab infrastructure is declared under `manifests/`:

- `00-namespaces.yaml` - mentor and student namespaces;
- `10-rbac.yaml` - ServiceAccounts, RBAC roles, and bindings;
- `20-service-account-tokens.yaml` - token Secret declarations without token values.

`scripts/generate-kubeconfigs.sh` produces local kubeconfig files after the manifests have been applied. Those files contain bearer tokens and are excluded from Git.

Kyverno policies for the next exercise are under `policies/`, with manually applied checks under `tests/kyverno/`.

The decision records, RBAC matrix, Kyverno policy scope, security boundaries, and operating commands are documented in [ADR 0001](docs/adr/0001-kind-rbac-service-account-access.md) and [ADR 0002](docs/adr/0002-kyverno-policy-scope.md).
