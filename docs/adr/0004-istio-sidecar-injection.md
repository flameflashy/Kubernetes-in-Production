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

Enable the Istio admission webhook for the lab namespaces, but set Istio's
default injection policy to disabled. Configure the injector webhook with
`reinvocationPolicy=IfNeeded` so it can observe mutations made by a later
admission webhook.

Extend the existing Kyverno person-label policy with a final cascading mutation
rule. After the preceding rules establish the final `person` value, the new
rule adds `sidecar.istio.io/inject=true` only when `person=student`. The Istio
admission webhook, rather than Kyverno, injects the `istio-proxy` container.
This avoids depending on the order in which Kubernetes invokes the Kyverno and
Istio mutating webhooks.

## Consequences

- Student Pods opt into the sidecar data plane explicitly; enabling webhook
  processing on a namespace does not inject other Pods by default.
- Mentor and non-lab Pods do not receive a sidecar from this policy.
- Kyverno's cascading mutations remain deterministic, and Istio webhook
  reinvocation removes the cross-webhook ordering dependency.
- Existing Pods are not changed; they must be recreated because Istio injection
  occurs only during Pod admission.
