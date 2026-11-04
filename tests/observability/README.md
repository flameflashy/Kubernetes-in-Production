# Observability manual checks

Run these checks after the Argo CD applications `monitoring`, `loki`, `alloy`,
`policy-reporter`, and `observability-config` are `Synced` and `Healthy`.

## Open Grafana

Print the generated admin password:

```bash
make grafana-password
```

Start the port forward in a separate terminal:

```bash
make grafana-port-forward
```

Open `http://localhost:3000` and sign in as `admin` with the generated password.

## Generate student load

Create a CPU-limited Pod in a student namespace:

```bash
kubectl --context kind-kuber-in-prod delete \
  -f tests/observability/01-student-load.yaml --ignore-not-found
kubectl --context kind-kuber-in-prod apply \
  -f tests/observability/01-student-load.yaml
```

Wait for the Pod and for at least two Prometheus scrape intervals:

```bash
kubectl --context kind-kuber-in-prod wait \
  --for=condition=Ready pod/student-load -n student02 --timeout=2m
```

Open **Dashboards > Student Namespace Node Load**. The `student02` series should
show CPU usage on the Kind control-plane node. Metrics can take about one minute
to appear because the Prometheus scrape interval is 30 seconds.

## Trigger the audit log and alert

Policy Reporter skips results which already exist when it starts. Recreate the
known non-compliant Pod after Policy Reporter and Loki are ready:

```bash
kubectl --context kind-kuber-in-prod delete \
  -f tests/kyverno/01-student-audit-failure.yaml --ignore-not-found
kubectl --context kind-kuber-in-prod apply \
  -f tests/kyverno/01-student-audit-failure.yaml
```

Confirm that Kyverno creates a failed PolicyReport result:

```bash
kubectl --context kind-kuber-in-prod get policyreports -n student01
```

Open **Dashboards > Read-only Root Filesystem Audit**. The failed result should
appear as a Loki log entry. The dashboard uses this LogQL selector:

```logql
{createdBy="policy-reporter", policy="require-readonly-root-filesystem", status="fail", namespace=~"student.*"}
```

Open **Alerts & IRM > Alerting > Alert rules** and select
`Read-only root filesystem audit failure`. It should enter the `Firing` state
after the next one-minute evaluation while the log entry remains in the
five-minute query window.

## Clean up the test workloads

```bash
kubectl --context kind-kuber-in-prod delete \
  -f tests/observability/01-student-load.yaml --ignore-not-found
kubectl --context kind-kuber-in-prod delete \
  -f tests/kyverno/01-student-audit-failure.yaml --ignore-not-found
```
