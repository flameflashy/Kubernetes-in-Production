# Istio sidecar manual checks

Run these checks only after the Argo CD applications `istio-base`, `istiod`,
`kyverno`, and `lab-policies` are `Synced` and `Healthy`.

Create the Pods manually:

```bash
kubectl --context kind-kuber-in-prod apply -f tests/istio/01-student-sidecar.yaml
kubectl --context kind-kuber-in-prod apply -f tests/istio/02-mentor-without-sidecar.yaml
```

Inspect the labels and container names:

```bash
kubectl --context kind-kuber-in-prod get pod student-sidecar -n student01 --show-labels
kubectl --context kind-kuber-in-prod get pod mentor-without-sidecar -n mentor --show-labels
kubectl --context kind-kuber-in-prod get pod student-sidecar -n student01 \
  -o jsonpath='{.spec.containers[*].name}'; echo
kubectl --context kind-kuber-in-prod get pod mentor-without-sidecar -n mentor \
  -o jsonpath='{.spec.containers[*].name}'; echo
```

Expected results:

| Pod | Person label | Injection label | Containers |
| --- | --- | --- | --- |
| `student01/student-sidecar` | `student` | `sidecar.istio.io/inject=true` | `app istio-proxy` |
| `mentor/mentor-without-sidecar` | `mentor` | absent | `app` |

Sidecar injection happens only during Pod creation. Delete the existing Pods
before repeating the check:

```bash
kubectl --context kind-kuber-in-prod delete -f tests/istio/
```
