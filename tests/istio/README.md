# Istio sidecar manual checks

Run these checks only after the Argo CD applications `istio-base`, `istiod`,
`kyverno`, and `lab-policies` are `Synced` and `Healthy`.

Create the Pods manually:

```bash
kubectl --context kind-kuber-in-prod apply -f tests/istio/01-student-sidecar.yaml
kubectl --context kind-kuber-in-prod apply -f tests/istio/02-mentor-without-sidecar.yaml
```

Inspect the labels and both regular and init container names:

```bash
kubectl --context kind-kuber-in-prod get pod student-sidecar -n student01 --show-labels
kubectl --context kind-kuber-in-prod get pod mentor-without-sidecar -n mentor --show-labels
kubectl --context kind-kuber-in-prod get pod student-sidecar -n student01 \
  -o custom-columns='APP:.spec.containers[*].name,INIT:.spec.initContainers[*].name'
kubectl --context kind-kuber-in-prod get pod mentor-without-sidecar -n mentor \
  -o custom-columns='APP:.spec.containers[*].name,INIT:.spec.initContainers[*].name'
```

Expected results:

| Pod | Person label | Injection label | Containers |
| --- | --- | --- | --- |
| `student01/student-sidecar` | `student` | `sidecar.istio.io/inject=true` | regular `app`; native sidecar `istio-proxy` under `initContainers` |
| `mentor/mentor-without-sidecar` | `mentor` | absent | regular `app`; no `istio-proxy` |

Istio uses Kubernetes native sidecars when the cluster supports them. A native
sidecar appears under `spec.initContainers` with `restartPolicy: Always`, but
runs for the entire lifetime of the Pod and contributes to the `2/2` readiness
count.

Sidecar injection happens only during Pod creation. Delete the existing Pods
before repeating the check:

```bash
kubectl --context kind-kuber-in-prod delete -f tests/istio/
```
