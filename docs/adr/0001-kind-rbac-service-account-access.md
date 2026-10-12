# ADR 0001: Use ServiceAccount identities with namespace-scoped RBAC

- Status: accepted
- Date: 2026-10-12

## Context

Module 02 requires one local Kubernetes cluster, separate kubeconfig files for a mentor and three students, and least-privilege access without `cluster-admin`.

The lab cluster is a single-control-plane Kind cluster named `kuber-in-prod`. It is intended for local learning, rather than production use.

## Decision

The cluster configuration is declared in `manifests/`.

- `00-namespaces.yaml` creates `mentor`, `student01`, `student02`, and `student03`.
- `10-rbac.yaml` creates a ServiceAccount for each identity, the reusable `lab-app-rw` and `lab-app-readonly` ClusterRoles, and namespace-scoped RoleBindings.
- `20-service-account-tokens.yaml` declares one manually managed ServiceAccount token Secret for each identity. The manifest contains no token; Kubernetes fills the token only after the Secret is applied.

`ClusterRole` is used only as a reusable set of permission rules. Every grant is made through a `RoleBinding`, so its scope is the binding namespace rather than the entire cluster.

| Identity | Permissions |
| --- | --- |
| `mentor-user` | RW in `mentor`, `student01`, `student02`, and `student03` |
| `student01-user` | RW only in `student01` |
| `student02-user` | RO in `student02`, `student01`, and `default` |
| `student03-user` | RW only in `student03` |

RW permits routine application resources, including workloads, Services, ConfigMaps, Secrets, PVCs, Ingresses, NetworkPolicies, HPA, and PDBs. It does not permit changing RBAC objects, namespaces, nodes, or other cluster-scoped resources.

RO permits `get`, `list`, and `watch` on routine application resources. It intentionally excludes Secrets because their values are credentials, not harmless metadata.

Generated kubeconfig files use ServiceAccount bearer tokens. `scripts/generate-kubeconfigs.sh` creates them locally under `kubeconfigs/`; this path is ignored by Git and generated files have mode `0600`.

## Consequences

- The access policy is reproducible and reviewable in Git.
- No mentor or student identity receives `cluster-admin` or any cluster-wide RoleBinding.
- A manually managed ServiceAccount token is long-lived, which is convenient for this lab but has greater exposure than a short-lived TokenRequest token. It must be treated as a password and never committed, pasted into chat, or shared.
- ServiceAccount identities are simple for Kind. They model API identities rather than interactive human login identities.

## Alternatives considered

### X.509 client certificates

These more closely model classic human kubeconfig identities, but issuing, distributing, renewing, and revoking certificates adds unnecessary complexity to a Kind lab.

### OIDC provider

OIDC is a common production pattern because it supports central identity and short-lived tokens. It requires an identity provider and API-server configuration, so it is outside the scope of this local lab.

### Short-lived tokens from the TokenRequest API

Short-lived tokens are preferred operationally, but each kubeconfig would need periodic regeneration. Long-lived tokens were selected explicitly for this training exercise.

## Apply and verify

```bash
kubectl apply -f manifests/00-namespaces.yaml
kubectl apply -f manifests/10-rbac.yaml
kubectl apply -f manifests/20-service-account-tokens.yaml
bash scripts/generate-kubeconfigs.sh
```

Use `kubectl --kubeconfig kubeconfigs/<identity>.kubeconfig auth can-i ...` to verify every intended allow and deny before using the credentials.
