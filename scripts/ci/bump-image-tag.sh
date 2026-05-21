#!/usr/bin/env bash
# Usage: bump-image-tag.sh <env-file> <service>
# Pure bash — Jenkins controller image has no python3.
set -euo pipefail

env_file="${1:?env file}"
service="${2:?service name}"
key="${service}:"

in_block=false
new_tag=""
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "${key}" ]]; then
    in_block=true
    printf '%s\n' "$line" >>"$tmp"
    continue
  fi

  if [[ "$in_block" == true ]] && [[ "$line" =~ ^[a-zA-Z0-9_-]+:[[:space:]]*$ ]]; then
    in_block=false
  fi

  if [[ "$in_block" == true ]] && [[ -z "$new_tag" ]] && [[ "$line" =~ ^[[:space:]]+tag:[[:space:]]+\"([^\"]+)\"[[:space:]]*$ ]]; then
    indent="${line%%\"*}"
    old="${BASH_REMATCH[1]}"
    if [[ "$old" =~ ^(.*-v)([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      new_tag="${BASH_REMATCH[1]}${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.$((${BASH_REMATCH[4]} + 1))"
      printf '%s"%s"\n' "$indent" "$new_tag" >>"$tmp"
      continue
    fi
    echo "Cannot parse tag: $old" >&2
    exit 1
  fi

  printf '%s\n' "$line" >>"$tmp"
done <"$env_file"

if [[ -z "$new_tag" ]]; then
  echo "No tag under ${key}" >&2
  exit 1
fi

mv "$tmp" "$env_file"
trap - EXIT
printf '%s\n' "$new_tag"
