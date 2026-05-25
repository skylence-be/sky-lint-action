#!/bin/sh
# Skylence installer / uninstaller.
#
# Install:
#   curl -fsSL https://github.com/skylence-be/releases/releases/latest/download/install.sh | sh
#   curl -fsSL https://github.com/skylence-be/releases/releases/latest/download/install.sh | sh -s -- --version v0.1.1
#   curl -fsSL https://github.com/skylence-be/releases/releases/latest/download/install.sh | sh -s -- --dir ~/.local/bin
#
# Uninstall:
#   curl -fsSL https://github.com/skylence-be/releases/releases/latest/download/install.sh | sh -s -- --uninstall
#   curl -fsSL https://github.com/skylence-be/releases/releases/latest/download/install.sh | sh -s -- --uninstall --purge
#   curl -fsSL https://github.com/skylence-be/releases/releases/latest/download/install.sh | sh -s -- --uninstall --dir ~/.local/bin -y

set -eu

REPO="skylence-be/releases"
VERSION="latest"
INSTALL_DIR="/usr/local/bin"
VERIFY="1"
MODE="install"
PURGE="0"
ASSUME_YES="0"
RUN_SETUP="1"

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --no-verify) VERIFY="0"; shift ;;
    --no-setup) RUN_SETUP="0"; shift ;;
    --uninstall) MODE="uninstall"; shift ;;
    --purge) PURGE="1"; shift ;;
    -y|--yes) ASSUME_YES="1"; shift ;;
    -h|--help)
      cat <<EOF
Skylence installer / uninstaller

Install flags:
  --version <tag>   Install specific tag (default: latest)
  --dir <path>      Install dir (default: /usr/local/bin)
  --no-verify       Skip checksum verification
  --no-setup        Skip the automatic 'sky setup' step after install

Uninstall flags:
  --uninstall       Remove the sky binary
  --purge           Also remove ~/.sky data directory (configs, DB, workflows)
  --dir <path>      Uninstall from this dir (default: /usr/local/bin)
  -y, --yes         Skip confirmation prompts
EOF
      exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

confirm() {
  prompt="$1"
  if [ "$ASSUME_YES" = "1" ]; then
    return 0
  fi
  printf "%s [y/N] " "$prompt"
  read -r answer </dev/tty || answer=""
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$MODE" = "uninstall" ]; then
  target="${INSTALL_DIR}/sky"
  if [ ! -e "$target" ]; then
    echo "sky not found at ${target} — nothing to remove."
  else
    if ! confirm "Remove ${target}?"; then
      echo "Aborted."
      exit 0
    fi
    if [ ! -w "$INSTALL_DIR" ]; then
      echo "Removing ${target} (sudo required)..."
      sudo rm -f "$target"
    else
      rm -f "$target"
    fi
    echo "Removed ${target}"
  fi

  data_dir="${HOME}/.sky"
  if [ "$PURGE" = "1" ]; then
    if [ -d "$data_dir" ]; then
      if confirm "Remove data dir ${data_dir}? (configs, DB, workflows)"; then
        rm -rf "$data_dir"
        echo "Removed ${data_dir}"
      else
        echo "Kept ${data_dir}"
      fi
    else
      echo "No data dir at ${data_dir}"
    fi
  else
    if [ -d "$data_dir" ]; then
      echo "Data dir kept: ${data_dir} (re-run with --purge to remove)"
    fi
  fi

  echo "Uninstall complete."
  exit 0
fi

# Skip download if sky is already on PATH (e.g. built from source in CI).
if command -v sky >/dev/null 2>&1; then
  echo "sky already on PATH at $(command -v sky); skipping install."
  exit 0
fi

# Install mode
uname_s="$(uname -s)"
uname_m="$(uname -m)"

case "$uname_s" in
  Darwin) os="darwin" ;;
  Linux) os="linux" ;;
  *) echo "unsupported OS: $uname_s" >&2; exit 1 ;;
esac

case "$uname_m" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) echo "unsupported arch: $uname_m" >&2; exit 1 ;;
esac

archive="sky-${os}-${arch}.tar.gz"
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
  sudo mv "${tmp}/sky" "${INSTALL_DIR}/sky"
else
  mv "${tmp}/sky" "${INSTALL_DIR}/sky"
fi

echo ""
"${INSTALL_DIR}/sky" --version
echo ""
echo "Skylence installed to ${INSTALL_DIR}/sky"

if [ "$RUN_SETUP" = "1" ]; then
  echo ""
  echo "Running sky setup..."
  if [ "$(id -u)" = "0" ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" "${INSTALL_DIR}/sky" setup || echo "Warning: sky setup failed; run it manually."
  elif [ "$(id -u)" = "0" ]; then
    echo "Skipping auto-setup (running as root with no SUDO_USER). Run 'sky setup' as your regular user."
  else
    "${INSTALL_DIR}/sky" setup || echo "Warning: sky setup failed; run it manually."
  fi
else
  echo "Next: sky setup"
fi
