# ADR 0005: Use the Grafana stack for cluster observability

- Status: accepted
- Date: 2026-11-04

## Context

Module 05 requires Kubernetes metrics, dashboards grouped by student namespace
and node, Pod log aggregation, and an alert based on Kyverno audit failures.
OpenTelemetry Collector can receive, process, and export telemetry, but it does
not provide the required storage, dashboards, or alerting by itself.

Kyverno audit results are stored as PolicyReport resources. Internal controller
logs are an unstable interface for alerting and may not contain every audit
result at the default log level.

## Decision

Install `kube-prometheus-stack` for metrics, Grafana, and Alertmanager. Install
Loki in single-binary mode for local log storage and Grafana Alloy for
Kubernetes Pod log collection.

Install Policy Reporter without its optional UI. It watches PolicyReport
resources and sends structured violation entries directly to Loki. Grafana
queries those entries with LogQL and evaluates a provisioned alert rule.

Store dashboards and alert provisioning files in Git as labeled ConfigMaps.
Grafana sidecars discover these ConfigMaps and reload the configuration.

## Consequences

- The lab demonstrates metrics, logs, dashboards, and alerting with common
  cloud-native components.
- Policy violations are queried by stable fields such as policy, status, and
  namespace instead of parsing Kyverno controller log text.
- Loki uses ephemeral storage because the Kind cluster is disposable.
- OpenTelemetry can be added later for application traces without replacing the
  selected backends.
- The observability stack adds several Pods and needs more local memory than the
  previous labs.
