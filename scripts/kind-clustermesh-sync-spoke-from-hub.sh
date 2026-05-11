#!/usr/bin/env bash
# Sync CA bundle cho ClusterMesh mTLS giữa hub (management) và các spoke (dev, prod).
# Dùng khi recreate cluster / rotate cert làm KVStoreMesh chưa bắt tay đủ.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HUB_CTX="${HUB_CTX:-}"
HUB_NS="${HUB_NS:-kube-system}"

if [[ -z "${HUB_CTX}" ]]; then
  echo "Thieu HUB_CTX (kubectl context cluster management/hub)." >&2
  echo "  Vi du: export HUB_CTX=rke2-management" >&2
  echo "  Lab Kind: export HUB_CTX=kind-management" >&2
  exit 1
fi

if [[ -z "${SPOKE_CONTEXTS:-}" ]]; then
  echo "Thieu SPOKE_CONTEXTS — danh sach context spoke, cach nhau boi space." >&2
  echo "  Vi du: export SPOKE_CONTEXTS='rke2-dev rke2-prod'" >&2
  echo "  Lab Kind: export SPOKE_CONTEXTS='kind-dev kind-prod'" >&2
  exit 1
fi

read -r -a SPOKE_CTXS <<< "${SPOKE_CONTEXTS}"
ALL_CTXS=("${HUB_CTX}" "${SPOKE_CTXS[@]}")
PEER_SCRIPT="${ROOT}/scripts/kind-clustermesh-peer-ip.sh"

if [[ ! -f "${PEER_SCRIPT}" ]]; then
  echo "Missing ${PEER_SCRIPT}" >&2
  exit 1
fi

echo "==> Update management peer endpoint file (can HUB_CTX / HUB_LB_IP)"
HUB_CTX="${HUB_CTX}" bash "${PEER_SCRIPT}"

echo "==> Gather cilium-ca from all contexts"
CA_ALL="$(mktemp)"
trap 'rm -f "${CA_ALL}"' EXIT
for ctx in "${ALL_CTXS[@]}"; do
  kubectl config get-contexts -o name | rg -x "${ctx}" >/dev/null || { echo "Skip ${ctx} (missing context)"; continue; }
  kubectl --context "${ctx}" -n "${HUB_NS}" get secret cilium-ca -o jsonpath='{.data.ca\.crt}' | base64 -d >> "${CA_ALL}"
  echo >> "${CA_ALL}"
done
CA_B64="$(base64 -w0 "${CA_ALL}")"

echo "==> Patch remote-cert + server-cert on all contexts"
for ctx in "${ALL_CTXS[@]}"; do
  kubectl config get-contexts -o name | rg -x "${ctx}" >/dev/null || continue
  kubectl --context "${ctx}" -n "${HUB_NS}" patch secret clustermesh-apiserver-remote-cert \
    --type=merge -p "{\"data\":{\"ca.crt\":\"${CA_B64}\"}}"
  kubectl --context "${ctx}" -n "${HUB_NS}" patch secret clustermesh-apiserver-server-cert \
    --type=merge -p "{\"data\":{\"ca.crt\":\"${CA_B64}\"}}"
done

echo "==> Restart clustermesh-apiserver + cilium on all contexts"
for ctx in "${ALL_CTXS[@]}"; do
  kubectl config get-contexts -o name | rg -x "${ctx}" >/dev/null || continue
  kubectl --context "${ctx}" -n "${HUB_NS}" rollout restart deploy/clustermesh-apiserver ds/cilium
done

echo "==> Wait for cilium daemonset rollout"
for ctx in "${ALL_CTXS[@]}"; do
  kubectl config get-contexts -o name | rg -x "${ctx}" >/dev/null || continue
  kubectl --context "${ctx}" -n "${HUB_NS}" rollout status ds/cilium --timeout=180s
done

echo "Done."
echo "Next: argocd app sync cilium-management cilium-dev cilium-prod"
echo "Verify: for ctx in ${HUB_CTX} ${SPOKE_CONTEXTS}; do cilium clustermesh status --context \$ctx; done"
