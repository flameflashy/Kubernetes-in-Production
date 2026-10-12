# Kyverno manual checks

Apply the policies only after Kyverno is installed and its Pods are ready. These tests are intentionally not part of the normal manifests because they create Pods in the cluster.

```bash
kubectl apply -f policies/10-require-readonly-root-filesystem-audit.yaml
kubectl apply -f policies/20-mutate-person-label.yaml
kubectl apply -f tests/kyverno/01-student-audit-failure.yaml
kubectl apply -f tests/kyverno/02-mentor-label-overwrite.yaml
kubectl apply -f tests/kyverno/03-default-label-removal.yaml
```

Expected results:

| Test | Expected result |
| --- | --- |
| `01-student-audit-failure` | Pod is created, gets `person=student`, and has a failed `require-readonly-root-filesystem` PolicyReport result. |
| `02-mentor-label-overwrite` | Pod is created with `person=mentor`, even though its submitted value was `student`. |
| `03-default-label-removal` | Pod is created without the `person` label. The root filesystem policy does not evaluate `default`. |

Inspect results:

```bash
kubectl get pods -n student01,mentor,default --show-labels
kubectl get policyreport -A
kubectl describe policyreport -n student01
```

Clean up after testing:

```bash
kubectl delete -f tests/kyverno/
```
