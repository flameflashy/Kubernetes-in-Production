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

During testing, the applications track the remote `lab2` branch. After the pull
request is merged, change `targetRevision` to `main` in
`gitops/root-application.yaml` and `gitops/applications/lab-policies.yaml`.

### Result

After bootstrap, Argo CD installs Kyverno and applies two policies:

- `require-readonly-root-filesystem` audits the read-only root filesystem
  setting in the lab namespaces;
- `set-person-label-by-namespace` sets the correct `person` label and removes
  it outside the lab namespaces.

Changes in Git are synchronized with the cluster automatically. Argo CD repairs
manual drift and removes resources that have been deleted from Git.

## Makefile usage

The commands are intended for WSL with access to a Docker Engine. They require
`docker`, `kind`, `kubectl`, `helm`, and `make`. On Ubuntu or Debian, install
`make` with:

```bash
sudo apt update && sudo apt install -y make
```

The branch must be available on GitHub before bootstrap:

```bash
git push -u origin lab2
make bootstrap
make wait
make status
make test
```

Available commands:

| Command | Purpose |
| --- | --- |
| `make help` | show all available commands |
| `make validate` | lint and render the Helm chart |
| `make cluster-up` | create the `kuber-in-prod` Kind cluster |
| `make bootstrap` | apply Module 02 and install Argo CD/GitOps |
| `make wait` | wait for the Synced and Healthy states |
| `make status` | show Applications, Pods, and policies |
| `make test` | apply the test Pods and show PolicyReports |
| `make test-clean` | delete the test Pods |
| `make argocd-password` | show the initial password for the `admin` user |
| `make port-forward` | expose the UI at `https://localhost:8080` |
| `make cluster-down` | delete the Kind cluster |

The cluster name and timeout can be overridden:

```bash
make cluster-up CLUSTER_NAME=my-lab TIMEOUT=15m
```

The key decisions are documented in [ADR 0001](docs/adr/0001-kind-rbac-service-account-access.md), [ADR 0002](docs/adr/0002-kyverno-policy-scope.md), and [ADR 0003](docs/adr/0003-argocd-helm-gitops.md).
