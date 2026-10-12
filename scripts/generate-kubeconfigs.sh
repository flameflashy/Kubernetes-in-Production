#!/usr/bin/env bash
set -euo pipefail

# Generates local credentials. The output directory is ignored by Git because
# every kubeconfig contains a bearer token.
readonly CONTEXT_NAME="${CONTEXT_NAME:-kind-kuber-in-prod}"
readonly OUTPUT_DIR="${OUTPUT_DIR:-kubeconfigs}"
readonly MAX_TOKEN_WAIT_SECONDS=30

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  }
}

require_command kubectl
require_command base64
require_command mktemp

server="$(kubectl config view --raw --minify --context "$CONTEXT_NAME" -o jsonpath='{.clusters[0].cluster.server}')"
cluster_name="$(kubectl config view --raw --minify --context "$CONTEXT_NAME" -o jsonpath='{.clusters[0].name}')"
ca_data="$(kubectl config view --raw --minify --context "$CONTEXT_NAME" -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"

if [[ -z "$server" || -z "$cluster_name" || -z "$ca_data" ]]; then
  printf 'Could not read cluster server, name, or CA data from context %s.\n' "$CONTEXT_NAME" >&2
  exit 1
fi

umask 077
mkdir -p "$OUTPUT_DIR"
ca_file="$(mktemp)"
trap 'rm -f "$ca_file"' EXIT
printf '%s' "$ca_data" | base64 --decode > "$ca_file"

wait_for_token() {
  local namespace="$1"
  local secret_name="$2"
  local token=""

  for ((attempt = 1; attempt <= MAX_TOKEN_WAIT_SECONDS; attempt++)); do
    token="$(kubectl --context "$CONTEXT_NAME" -n "$namespace" get secret "$secret_name" -o jsonpath='{.data.token}' 2>/dev/null || true)"
    if [[ -n "$token" ]]; then
      printf '%s' "$token" | base64 --decode
      return 0
    fi
    sleep 1
  done

  printf 'Timed out waiting for token in %s/%s. Apply manifests/20-service-account-tokens.yaml first.\n' "$namespace" "$secret_name" >&2
  return 1
}

write_kubeconfig() {
  local actor="$1"
  local namespace="$2"
  local secret_name="$3"
  local output_file="$OUTPUT_DIR/$actor.kubeconfig"
  local token
  token="$(wait_for_token "$namespace" "$secret_name")"

  rm -f "$output_file"
  kubectl config set-cluster "$cluster_name" \
    --server="$server" \
    --certificate-authority="$ca_file" \
    --embed-certs=true \
    --kubeconfig="$output_file" >/dev/null
  kubectl config set-credentials "$actor" \
    --token="$token" \
    --kubeconfig="$output_file" >/dev/null
  kubectl config set-context "$actor@$cluster_name" \
    --cluster="$cluster_name" \
    --namespace="$namespace" \
    --user="$actor" \
    --kubeconfig="$output_file" >/dev/null
  kubectl config use-context "$actor@$cluster_name" --kubeconfig="$output_file" >/dev/null
  chmod 600 "$output_file"
  printf 'Created %s\n' "$output_file"
}

write_kubeconfig mentor mentor mentor-user-token
write_kubeconfig student01 student01 student01-user-token
write_kubeconfig student02 student02 student02-user-token
write_kubeconfig student03 student03 student03-user-token
