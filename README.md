# Kubernetes in Production

## Module 02 — Security and Policy as Code

The initial lab infrastructure is declared under `manifests/`:

- `namespaces.yaml` - mentor and student namespaces;
- `rbac.yaml` - ServiceAccounts, RBAC roles, and bindings;
- `20-service-account-tokens.yaml` - token Secret declarations without token values.

`scripts/generate-kubeconfigs.sh` produces local kubeconfig files after the manifests have been applied. Those files contain bearer tokens and are excluded from Git.

## Module 03 — Platform Engineering

### Assignment

1. Configure a GitOps system for future changes.
2. Package the Module 02 policies as a Helm chart.

### Implementation

- Argo CD uses the app-of-apps pattern.
- Argo CD installs Kyverno `1.19.2` from Helm chart `3.9.2`.
- The Module 02 policies are packaged under `charts/lab-policies`.
- Policy settings are defined in `values.yaml` and validated by JSON Schema.
- Automated synchronization, self-healing, and pruning are enabled.
- Test Pods verify the Audit and mutation policies.

During active lab development, the applications track the corresponding remote
lab branch. After the pull request is merged, change `targetRevision` to `main`.

### Result

After bootstrap, Argo CD installs Kyverno and applies two policies:

- `require-readonly-root-filesystem` audits the read-only root filesystem
  setting in the lab namespaces;
- `set-person-label-by-namespace` sets the correct `person` label and removes
  it outside the lab namespaces.

Changes in Git are synchronized with the cluster automatically. Argo CD repairs
manual drift and removes resources that have been deleted from Git.

## Module 04 — Service Mesh

### Assignment

1. Install Istio service mesh in sidecar mode.
2. Use a Kyverno policy to inject an Istio sidecar into every Pod labeled
   `person=student`.

### Implementation

- Argo CD installs the pinned Istio `base` and `istiod` Helm charts at version
  `1.31.3`.
- Lab namespaces enable the Istio admission webhook, while Istio's default
  injection policy remains disabled.
- The Kyverno person-label policy adds `sidecar.istio.io/inject=true` after it
  determines that the final `person` value is `student`. Istio webhook
  reinvocation observes that mutation regardless of webhook ordering.
- Istio's admission webhook injects the `istio-proxy` container.
- Ambient components and an ingress gateway are not installed because they are
  outside this lab's scope.

During Module 04 development, the root and local chart Applications track the
remote `lab3` branch.

Manual verification is documented in
[`tests/istio/README.md`](tests/istio/README.md).

## Makefile usage

The commands are intended for WSL with access to a Docker Engine. They require
`docker`, `kind`, `kubectl`, `helm`, and `make`. On Ubuntu or Debian, install
`make` with:

```bash
sudo apt update && sudo apt install -y make
```

The branch must be available on GitHub before bootstrap:

```bash
git push -u origin lab3
make bootstrap
```

Available commands:

| Command | Purpose |
| --- | --- |
| `make help` | show all available commands |
| `make cluster-up` | create the `kuber-in-prod` Kind cluster |
| `make platform-infra` | apply namespaces, RBAC, and token Secrets |
| `make argocd-install` | install or upgrade Argo CD |
| `make gitops-apply` | apply the root Argo CD Application |
| `make bootstrap` | create the cluster and bootstrap the complete platform |
| `make argocd-password` | show the initial Argo CD admin password |
| `make port-forward` | expose the Argo CD UI at `https://localhost:8080` |
| `make cluster-down` | delete the Kind cluster |

All observation and validation steps are intentionally manual. After bootstrap,
inspect the GitOps applications and the Istio control plane with:

```bash
kubectl --context kind-kuber-in-prod get applications -n argocd
kubectl --context kind-kuber-in-prod get pods -n istio-system
kubectl --context kind-kuber-in-prod get clusterpolicies
```

To open the Argo CD UI, run the port-forward in one terminal:

```bash
make port-forward
```

Read the initial `admin` password in another terminal:

```bash
make argocd-password
```

The cluster name and timeout can be overridden:

```bash
make cluster-up CLUSTER_NAME=my-lab TIMEOUT=15m
```

The key decisions are documented in [ADR 0001](docs/adr/0001-kind-rbac-service-account-access.md), [ADR 0002](docs/adr/0002-kyverno-policy-scope.md), [ADR 0003](docs/adr/0003-argocd-helm-gitops.md), and [ADR 0004](docs/adr/0004-istio-sidecar-injection.md).
