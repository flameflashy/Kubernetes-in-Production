# ADR 0004: Select Istio sidecar injection with a Kyverno label mutation

- Status: accepted
- Date: 2026-11-03

## Context

Module 04 requires Istio in sidecar mode and requires every Pod labeled
`person=student` to run with an Istio sidecar. The existing Kyverno policy
assigns the final `person` value during Pod admission.

## Decision

Install the pinned upstream Istio `base` and `istiod` Helm charts through Argo
CD. Do not install ambient-mode components or an ingress gateway because they
are outside the lab scope.

Keep namespace-wide automatic injection disabled. Extend the existing Kyverno
person-label policy with a final cascading mutation rule. After the preceding
rules establish the final `person` value, the new rule adds
`sidecar.istio.io/inject=true` only when `person=student`. The Istio admission
webhook, rather than Kyverno, injects the `istio-proxy` container.

## Consequences

- Student Pods opt into the sidecar data plane without enabling mesh injection
  for every Pod in their namespaces.
- Mentor and non-lab Pods do not receive a sidecar from this policy.
- The ordering dependency is explicit and deterministic because the cascading
  mutations are rules in the same Kyverno policy.
- Existing Pods are not changed; they must be recreated because Istio injection
  occurs only during Pod admission.
