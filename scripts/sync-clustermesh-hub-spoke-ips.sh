#!/usr/bin/env bash
# Ghi IP/NLB endpoint của clustermesh-apiserver (spoke dev + prod) vào hub Helm values
# (cilium/cilium-values-management.yaml → clustermesh.config.clusters[].ips).
#
# Cách dùng:
#   export CTX_DEV=rke2-dev CTX_PROD=rke2-prod
#   ./scripts/sync-clustermesh-hub-spoke-ips.sh
#   CLUSTERMESH_SPOKE_IP_DEV=10.0.1.2 CLUSTERMESH_SPOKE_IP_PROD=10.0.2.2 ./scripts/sync-clustermesh-hub-spoke-ips.sh
#   ./scripts/sync-clustermesh-hub-spoke-ips.sh --print-only
#
# Biến môi trường:
#   CTX_DEV, CTX_PROD           — kubectl context (bắt buộc trừ khi override IP)
#   CLUSTERMESH_SPOKE_IP_DEV    — nếu set, không gọi kubectl cho dev
#   CLUSTERMESH_SPOKE_IP_PROD   — nếu set, không gọi kubectl cho prod
#   CLUSTERMESH_HUB_VALUES_FILE — mặc định: cilium/cilium-values-management.yaml
#
# Yêu cầu: kubectl, yq (https://github.com/mikefarah/yq).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT}/scripts/lib/clustermesh-apiserver-endpoint.sh"

if [[ -z "${CTX_DEV:-}" || -z "${CTX_PROD:-}" ]]; then
  echo "Thieu CTX_DEV hoac CTX_PROD (kubectl context cua tung spoke)." >&2
  echo "  Vi du:  export CTX_DEV=rke2-dev CTX_PROD=rke2-prod" >&2
  echo "  Lab Kind (tuy chon): export CTX_DEV=kind-dev CTX_PROD=kind-prod" >&2
  exit 1
fi

VALUES_REL="${CLUSTERMESH_HUB_VALUES_FILE:-cilium/cilium-values-management.yaml}"
VALUES="${ROOT}/${VALUES_REL}"

PRINT_ONLY=false
for arg in "$@"; do
  if [[ "$arg" == --print-only ]]; then
    PRINT_ONLY=true
  elif [[ "$arg" == -h || "$arg" == --help ]]; then
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
  fi
done

if ! command -v yq &>/dev/null; then
  echo "Cần cài yq (v4): https://github.com/mikefarah/yq" >&2
  exit 1
fi

if [[ ! -f "${VALUES}" ]]; then
  echo "Không tìm thấy ${VALUES}" >&2
  exit 1
fi

resolve_one() {
  local label="$1" ctx="$2" override_var="$3"
  local ip="${!override_var:-}"
  if [[ -n "${ip}" ]]; then
    echo "${ip}"
    return 0
  fi
  if ip="$(clustermesh_apiserver_ipv4_for_context "${ctx}")"; then
    echo "${ip}"
    return 0
  fi
  echo "Không đọc được LoadBalancer ingress cho clustermesh-apiserver (context=${ctx}, ${label})." >&2
  echo "  Chờ NLB/EXTERNAL-IP, hoặc set ${override_var}." >&2
  return 1
}

DEV_IP="$(resolve_one dev "${CTX_DEV}" CLUSTERMESH_SPOKE_IP_DEV)" || exit 1
PROD_IP="$(resolve_one prod "${CTX_PROD}" CLUSTERMESH_SPOKE_IP_PROD)" || exit 1

echo "dev  (${CTX_DEV}):  ${DEV_IP}"
echo "prod (${CTX_PROD}): ${PROD_IP}"

if [[ "${PRINT_ONLY}" == true ]]; then
  exit 0
fi

yq -i '(.clustermesh.config.clusters[] | select(.name == "dev") | .ips) = ["'"${DEV_IP}"'"]' "${VALUES}"
yq -i '(.clustermesh.config.clusters[] | select(.name == "prod") | .ips) = ["'"${PROD_IP}"'"]' "${VALUES}"

echo "Đã cập nhật ${VALUES_REL} (clustermesh.config.clusters dev/prod → ips)."
