# ADR 0002: Scope Kyverno security audit to Module 02 lab namespaces

- Status: accepted
- Date: 2026-10-12

## Context

Module 02 requires a Kyverno policy that validates `securityContext.readOnlyRootFilesystem: true` in audit mode and a policy that controls the Pod label `person` by namespace.

A cluster-wide root filesystem policy would also evaluate Kind, CoreDNS, CNI, and Kyverno system Pods. Their expected violations would make the training report noisy and obscure the student workloads being assessed.

## Decision

The `require-readonly-root-filesystem` ClusterPolicy matches Pods only in `mentor`, `student01`, `student02`, and `student03`. It evaluates regular containers, init containers, and ephemeral containers.

The policy uses `failureAction: Audit` and `emitWarning: true`. A violation is allowed, reported in a PolicyReport, and returned as an API warning; it is not blocked.

The `set-person-label-by-namespace` ClusterPolicy mutates newly created and updated Pods as follows:

| Namespace | Required Pod label |
| --- | --- |
| `student01`, `student02`, `student03` | `person: student` |
| `mentor` | `person: mentor` |
| every other namespace | no `person` label |

The lab-namespace rules overwrite a conflicting submitted `person` value. The non-lab rule removes the label only when it exists, so normal Pods with no label remain valid. Mutation is admission-time only; it does not retroactively change existing Pods.

## Consequences

- Policy reports remain focused on resources created for this lab.
- The audit policy can later be widened by removing the `namespaces` filter once system workload exceptions are understood.
- Workload authors can see warnings and report failures before the policy is promoted to `Enforce`.
- The label policy applies to direct Pods; Kyverno's Pod-controller auto-generation also applies compatible Pod rules to workload templates.
