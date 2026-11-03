# ADR 0003: Manage lab policies with Helm and Argo CD

- Status: accepted
- Date: 2026-11-02

## Context

Module 03 requires a GitOps system for future changes and asks that the Kyverno
policies from Module 02 be delivered as Helm charts. The cluster is a local
single-node training cluster. It does not need a multi-tenant control plane, but
the deployment flow should still model production practices.

## Decision

Use Argo CD with the app-of-apps pattern. During lab validation, a root
Application tracks `gitops/applications` on the current remote lab branch and
creates child Applications:

1. the pinned upstream Kyverno chart;
2. the repository-local `charts/lab-policies` chart.

Automated sync, pruning, and self-healing are enabled. Chart versions are pinned.
The policy chart exposes policy behavior through validated values and keeps the
resource names from Module 02 so existing resources converge in place.

Kyverno 1.19.2 is pinned because it is the last supported release line for the
legacy `ClusterPolicy` API used by the original homework. Migrating the policy
logic to the CEL-based policy APIs is intentionally a separate change rather
than combining an API migration with Helm packaging.

Argo CD itself is bootstrapped imperatively because a GitOps controller cannot
reconcile an empty cluster before it exists.

## Consequences

- The platform follows the current lab branch while it is being tested. Local
  Application revisions must be changed to `main` after the pull request is
  merged.
- Manual cluster changes are treated as drift and reverted.
- Removing a declared object from Git removes it from the cluster.
- Kyverno CRDs may not exist during the first policy dry run, so the policy
  Application skips that dry run and retries until the dependency is ready.
- The Module 02 namespace and RBAC manifests remain separate because migrating
  them is outside this exercise's scope.
- An upgrade to Kyverno 1.20 requires migrating the deprecated legacy policy
  types first.
