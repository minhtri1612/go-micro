#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/cilium/clustermesh-management-peer.yaml"
# shellcheck source=/dev/null
source "${ROOT}/scripts/lib/clustermesh-apiserver-endpoint.sh"

HUB_CTX="${HUB_CTX:-}"
HUB_LB_IP="${HUB_LB_IP:-}"

if [[ -n "${HUB_LB_IP}" ]]; then
  :
elif [[ -n "${HUB_CTX}" ]]; then
  if ! HUB_LB_IP="$(clustermesh_apiserver_ipv4_for_context "${HUB_CTX}")"; then
    echo "Loi: khong doc duoc IP/hostname clustermesh-apiserver tren context '${HUB_CTX}'." >&2
    echo "  Dat HUB_LB_IP=... hoac dam bao Service co LoadBalancer ingress." >&2
    exit 1
  fi
else
  echo "Thieu HUB_CTX hoac HUB_LB_IP." >&2
  echo "  Cloud:  export HUB_CTX=rke2-management   # hoac: export HUB_LB_IP=<NLB-IP>" >&2
  echo "  Lab Kind (tuy chon): export HUB_CTX=kind-management" >&2
  exit 1
fi

cat > "${OUT}" <<EOF
# AUTO — scripts/kind-clustermesh-peer-ip.sh — endpoint clustermesh-apiserver của management
clustermesh:
  config:
    clusters:
      - name: management
        port: 2379
        ips:
          - ${HUB_LB_IP}
EOF

echo "Wrote ${OUT} with management LB IP: ${HUB_LB_IP}"
