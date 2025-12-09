#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   promote-current.sh              # tag = stable
#   promote-current.sh latest       # tag = latest
#   promote-current.sh testing      # tag = testing

# ===== CONFIG =====
DEFAULT_TAG="stable"
# ==================

TARGET_TAG="${1:-$DEFAULT_TAG}"

origin="$(
  rpm-ostree status 2>/dev/null \
    | awk '/^●/ {print $2; exit}'
)"

if [[ -z "${origin:-}" ]]; then
  echo "Error: could not detect current deployment origin from 'rpm-ostree status'." >&2
  exit 1
fi

image_part="${origin#*:}"

image_part="${image_part#docker://}"

image_no_digest="${image_part%%@*}"

image_repo="${image_no_digest%%:*}"

variant="${image_repo##*/}"

current_digest="$(
  rpm-ostree status 2>/dev/null \
    | awk '/^[[:space:]]*Digest:/ { print $2; exit }'
)"

if [[ -z "${current_digest:-}" ]]; then
  echo "Error: could not extract Digest from 'rpm-ostree status'." >&2
  exit 1
fi

SRC_REF="docker://${image_repo}@${current_digest}"
DST_REF="docker://${image_repo}:${TARGET_TAG}"

echo "Detected current deployment:"
echo "  Origin:      ${origin}"
echo "  Variant:     ${variant}"
echo "  Image repo:  ${image_repo}"
echo "  Digest:      ${current_digest}"
echo
echo "Will promote:"
echo "  ${SRC_REF}"
echo "    -> ${DST_REF}"
echo

read -r -p "Promote this digest to tag '${TARGET_TAG}' for variant '${variant}'? [y/N] " answer
case "${answer}" in
  [yY]|[yY][eE][sS])
    echo "Promoting..."
    skopeo copy --all "${SRC_REF}" "${DST_REF}"
    echo "Done."
    echo "Tag '${TARGET_TAG}' for ${image_repo} now points to:"
    echo "  ${current_digest}"
    ;;
  *)
    echo "Aborted."
    exit 0
    ;;
esac
