#!/usr/bin/env bash
# shellcheck shell=bash
# Shared helpers: resolve kube-system/clustermesh-apiserver (LoadBalancer) to one IPv4.

# Usage: clustermesh_apiserver_ipv4_for_context <kubectl-context>
# Prints IPv4 on stdout; exit 1 if unavailable (no LB ingress / resolve failure).
clustermesh_apiserver_ipv4_for_context() {
  local ctx="$1"
  local ip host
  ip="$(kubectl --context "${ctx}" get svc clustermesh-apiserver -n kube-system \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  if [[ -n "${ip}" ]]; then
    echo "${ip}"
    return 0
  fi
  host="$(kubectl --context "${ctx}" get svc clustermesh-apiserver -n kube-system \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  if [[ -n "${host}" ]]; then
    _clustermesh_resolve_hostname_ipv4 "${host}"
    return $?
  fi
  return 1
}

_clustermesh_resolve_hostname_ipv4() {
  local h="$1"
  local out
  if command -v getent &>/dev/null; then
    out="$(getent ahosts "${h}" 2>/dev/null | awk '$1 ~ /^[0-9]+\./ {print $1; exit}')"
    if [[ -n "${out}" ]]; then
      echo "${out}"
      return 0
    fi
  fi
  if command -v dig &>/dev/null; then
    out="$(dig +short "${h}" A 2>/dev/null | awk 'NF && $0 !~ /^;/ {print; exit}')"
    if [[ -n "${out}" ]]; then
      echo "${out}"
      return 0
    fi
  fi
  out="$(python3 -c "import socket,sys; print(socket.gethostbyname(sys.argv[1]))" "${h}" 2>/dev/null || true)"
  if [[ -n "${out}" ]]; then
    echo "${out}"
    return 0
  fi
  return 1
}
