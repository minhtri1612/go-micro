#!/usr/bin/env bash
# Usage: bump-image-tag.sh <env-file> <service>
# Bump patch +1 từ tag semver LỚN NHẤT trên Docker Hub (cùng prefix với tag trong yaml),
# rồi ghi vào env file. Tag trong yaml chỉ để lấy prefix — không quyết định version build mới.
# Pure bash — Jenkins controller image has no python3.
set -euo pipefail

env_file="${1:?env file}"
service="${2:?service name}"
key="${service}:"

# ── 1. Đọc tag hiện tại trong yaml (prefix + fallback nếu Hub trống) ──
in_block=false
current_tag=""

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "${key}" ]]; then
    in_block=true
    continue
  fi
  if [[ "$in_block" == true ]] && [[ "$line" =~ ^[a-zA-Z0-9_-]+:[[:space:]]*$ ]]; then
    in_block=false
  fi
  if [[ "$in_block" == true ]] && [[ -z "$current_tag" ]] &&
    [[ "$line" =~ ^[[:space:]]+tag:[[:space:]]+\"([^\"]+)\"[[:space:]]*$ ]]; then
    current_tag="${BASH_REMATCH[1]}"
    break
  fi
done <"$env_file"

if [[ -z "$current_tag" ]]; then
  echo "No tag found under ${key}" >&2
  exit 1
fi

if [[ ! "$current_tag" =~ ^(.*-v)([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Cannot parse semver tag: $current_tag" >&2
  exit 1
fi
prefix="${BASH_REMATCH[1]}"

# ── 2. Query Docker Hub — tag lớn nhất cùng prefix ──
repo="${IMAGE_REPO:-minhtri1612/go-microservice}"
repo_ns="${repo%%/*}"
repo_name="${repo#*/}"
hub_latest=""
best_maj=-1
best_min=-1
best_pat=-1

consider_tag() {
  local t="$1"
  if [[ "$t" =~ ^${prefix}([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    local maj="${BASH_REMATCH[1]}" min="${BASH_REMATCH[2]}" pat="${BASH_REMATCH[3]}"
    if (( maj > best_maj )) ||
      { (( maj == best_maj )) && (( min > best_min )); } ||
      { (( maj == best_maj )) && (( min == best_min )) && (( pat > best_pat )); }; then
      best_maj=$maj
      best_min=$min
      best_pat=$pat
      hub_latest="${prefix}${maj}.${min}.${pat}"
    fi
  fi
}

fetch_hub_tags_page() {
  local url="$1"
  local curl_args=(-fsSL)
  if [[ -n "${DOCKER_USER:-}" && -n "${DOCKER_PASS:-}" ]]; then
    curl_args+=(-u "${DOCKER_USER}:${DOCKER_PASS}")
  fi
  curl "${curl_args[@]}" "$url" 2>/dev/null || true
}

# Public Hub API (không cần auth cho repo public); có DOCKER_* thì gửi kèm
url="https://hub.docker.com/v2/repositories/${repo_ns}/${repo_name}/tags/?page_size=100"
while [[ -n "$url" ]]; do
  body="$(fetch_hub_tags_page "$url")"
  if [[ -z "$body" ]]; then
    break
  fi
  while IFS= read -r t; do
    consider_tag "$t"
  done < <(printf '%s' "$body" | grep -oE '"name":"[^"]+"' | sed 's/"name":"//;s/"$//')

  url=""
  if printf '%s' "$body" | grep -q '"next":[^n]'; then
    url="$(printf '%s' "$body" | sed -n 's/.*"next"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    url="${url//\\//}"
  fi
done

base_tag="$current_tag"
if [[ -n "$hub_latest" ]]; then
  base_tag="$hub_latest"
  echo "Hub latest for ${service} (${repo}): ${hub_latest} (yaml had ${current_tag})" >&2
else
  echo "[WARN] Không lấy được tag từ Hub cho prefix '${prefix}' — bump từ yaml: ${current_tag}" >&2
fi

# ── 3. Patch +1 từ base (Hub latest hoặc yaml fallback) ──
if [[ ! "$base_tag" =~ ^(.*-v)([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Cannot parse base tag: $base_tag" >&2
  exit 1
fi
new_tag="${BASH_REMATCH[1]}${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.$((${BASH_REMATCH[4]} + 1))"

# ── 4. Ghi tag mới vào env file ──
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
in_block=false
patched=false

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "${key}" ]]; then
    in_block=true
    printf '%s\n' "$line" >>"$tmp"
    continue
  fi
  if [[ "$in_block" == true ]] && [[ "$line" =~ ^[a-zA-Z0-9_-]+:[[:space:]]*$ ]]; then
    in_block=false
  fi
  if [[ "$in_block" == true ]] && [[ "$patched" == false ]] &&
    [[ "$line" =~ ^([[:space:]]+tag:[[:space:]]+\")[^\"]+(\".*)$ ]]; then
    printf '%s%s%s\n' "${BASH_REMATCH[1]}" "$new_tag" "${BASH_REMATCH[2]}" >>"$tmp"
    patched=true
    continue
  fi
  printf '%s\n' "$line" >>"$tmp"
done <"$env_file"

if [[ "$patched" != true ]]; then
  echo "Failed to patch tag under ${key}" >&2
  exit 1
fi

mv "$tmp" "$env_file"
trap - EXIT
printf '%s\n' "$new_tag"
