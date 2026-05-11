#!/usr/bin/env bash
# Tạo Secret jenkins-internal-kubeconfig trên cluster management.
#
# Cloud (RKE2): dùng kubeconfig hiện tại (API đã trỏ NLB/VPC), không sửa IP Docker.
#   export KUBE_CTX_MANAGEMENT=rke2-management
#   ./scripts/jenkins-generate-internal-kubeconfig.sh
#
# Lab Kind (tùy chọn): thay API 127.0.0.1 bằng IP container control-plane.
#   export KIND_INTERNAL_KUBECONFIG=1
#   export KUBE_CTX_MANAGEMENT=kind-management
#   ./scripts/jenkins-generate-internal-kubeconfig.sh
#
set -euo pipefail

echo "Generating internal kubeconfig for Jenkins..."

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBE_CTX_MANAGEMENT="${KUBE_CTX_MANAGEMENT:?Set KUBE_CTX_MANAGEMENT to management cluster kubectl context}"

TMP_KUBECONFIG="$(mktemp)"
trap 'rm -f "${TMP_KUBECONFIG}"' EXIT
cp "${KUBECONFIG:-$HOME/.kube/config}" "${TMP_KUBECONFIG}"

if [[ "${KIND_INTERNAL_KUBECONFIG:-}" == "1" ]]; then
  echo "Mode: Kind (docker inspect control-plane IPs)"
  MGMT_IP=$(docker inspect management-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
  DEV_IP=$(docker inspect dev-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
  PROD_IP=$(docker inspect prod-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
  echo "Management IP: $MGMT_IP"
  echo "Dev IP: $DEV_IP"
  echo "Prod IP: $PROD_IP"
  sed -i "s/127.0.0.1:33443/$MGMT_IP:6443/g" "${TMP_KUBECONFIG}"
  sed -i "s/127.0.0.1:30443/$DEV_IP:6443/g" "${TMP_KUBECONFIG}"
  sed -i "s/127.0.0.1:31443/$PROD_IP:6443/g" "${TMP_KUBECONFIG}"
else
  echo "Mode: cloud — giữ server URL trong kubeconfig (không chỉnh Docker)."
fi

echo "Creating/Updating Secret 'jenkins-internal-kubeconfig' in cluster (context ${KUBE_CTX_MANAGEMENT})..."

kubectl --context "${KUBE_CTX_MANAGEMENT}" create namespace jenkins --dry-run=client -o yaml | kubectl --context "${KUBE_CTX_MANAGEMENT}" apply -f -
kubectl --context "${KUBE_CTX_MANAGEMENT}" -n jenkins create secret generic jenkins-internal-kubeconfig \
  --from-file=config="${TMP_KUBECONFIG}" \
  --dry-run=client -o yaml | kubectl --context "${KUBE_CTX_MANAGEMENT}" apply -f -

echo "Done! Secret stored in namespace jenkins on ${KUBE_CTX_MANAGEMENT}."
