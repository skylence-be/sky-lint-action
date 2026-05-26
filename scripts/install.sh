#!/bin/sh
# Installer for sky-workflow-lint (open-source linter for .sky workflow files).
#
# Install:
#   curl -fsSL https://github.com/skylence-be/sky-workflow-lint/releases/latest/download/install.sh | sh
#   curl -fsSL https://github.com/skylence-be/sky-workflow-lint/releases/latest/download/install.sh | sh -s -- --version v0.1.0
#   curl -fsSL https://github.com/skylence-be/sky-workflow-lint/releases/latest/download/install.sh | sh -s -- --dir ~/.local/bin

set -eu

REPO="skylence-be/sky-workflow-lint"
VERSION="latest"
INSTALL_DIR="/usr/local/bin"
VERIFY="1"

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --no-verify) VERIFY="0"; shift ;;
    -h|--help)
      cat <<EOF
sky-workflow-lint installer

Flags:
  --version <tag>   Install specific tag (default: latest)
  --dir <path>      Install dir (default: /usr/local/bin)
  --no-verify       Skip checksum verification
EOF
      exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Skip download if sky-workflow-lint is already on PATH.
if command -v sky-workflow-lint >/dev/null 2>&1; then
  echo "sky-workflow-lint already on PATH at $(command -v sky-workflow-lint); skipping install."
  exit 0
fi

uname_s="$(uname -s)"
uname_m="$(uname -m)"

case "$uname_s" in
  Darwin) os="darwin" ;;
  Linux)  os="linux"  ;;
  *) echo "unsupported OS: $uname_s" >&2; exit 1 ;;
esac

case "$uname_m" in
  x86_64|amd64)  arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) echo "unsupported arch: $uname_m" >&2; exit 1 ;;
esac

archive="sky-workflow-lint-${os}-${arch}.tar.gz"
if [ "$VERSION" = "latest" ]; then
  base="https://github.com/${REPO}/releases/latest/download"
else
  base="https://github.com/${REPO}/releases/download/${VERSION}"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading ${archive} from ${base}..."
curl -fsSL -o "${tmp}/${archive}" "${base}/${archive}"

if [ "$VERIFY" = "1" ]; then
  echo "Verifying checksum..."
  curl -fsSL -o "${tmp}/checksums.txt" "${base}/checksums.txt"
  (
    cd "$tmp"
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 -c checksums.txt --ignore-missing
    elif command -v sha256sum >/dev/null 2>&1; then
      sha256sum --check --ignore-missing checksums.txt
    else
      echo "no shasum/sha256sum available; re-run with --no-verify to skip" >&2
      exit 1
    fi
  )
fi

echo "Extracting..."
tar -xzf "${tmp}/${archive}" -C "$tmp"

if [ ! -w "$INSTALL_DIR" ]; then
  echo "Installing to ${INSTALL_DIR} (sudo required)..."
  sudo mv "${tmp}/sky-workflow-lint" "${INSTALL_DIR}/sky-workflow-lint"
else
  mv "${tmp}/sky-workflow-lint" "${INSTALL_DIR}/sky-workflow-lint"
fi

echo ""
echo "Installed sky-workflow-lint to ${INSTALL_DIR}/sky-workflow-lint"
