#!/usr/bin/env bash
# Provision Flutter + resolve dependencies for a fresh Linux box
# (Claude Code cloud sessions: Ubuntu 24.04 x86_64, no Flutter preinstalled).
#
# Idempotent: safe to re-run. Usage, from the repo root:
#   bash scripts/cloud-setup.sh
#
# Overrides (mainly for testing):
#   FLUTTER_VERSION  Flutter tag to install      (default: 3.47.4)
#   FLUTTER_HOME     where the SDK is cloned     (default: /opt/flutter, or ~/flutter if not root)
#   BIN_DIR          where flutter/dart symlinks go (default: /usr/local/bin, or ~/.local/bin if not root)
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.4}"
if [ "$(id -u)" -eq 0 ]; then
  FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter}"
  BIN_DIR="${BIN_DIR:-/usr/local/bin}"
else
  FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
  BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\n==> %s\n' "$*"; }

# Flutter's tool needs these; most are present on the cloud image already.
if command -v apt-get >/dev/null 2>&1; then
  missing=()
  for bin in git curl unzip xz; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    log "Installing system packages: ${missing[*]}"
    SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq git curl unzip xz-utils ca-certificates
  fi
fi

if [ -x "$FLUTTER_HOME/bin/flutter" ]; then
  log "Flutter already at $FLUTTER_HOME"
else
  log "Cloning Flutter $FLUTTER_VERSION into $FLUTTER_HOME"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

# Root-owned SDK used by other users trips git's safe.directory check.
git config --global --add safe.directory "$FLUTTER_HOME" || true

mkdir -p "$BIN_DIR"
ln -sf "$FLUTTER_HOME/bin/flutter" "$BIN_DIR/flutter"
ln -sf "$FLUTTER_HOME/bin/dart" "$BIN_DIR/dart"
export PATH="$BIN_DIR:$PATH"

export FLUTTER_SUPPRESS_ANALYTICS=true
flutter config --no-analytics >/dev/null 2>&1 || true
dart --disable-analytics >/dev/null 2>&1 || true

log "Flutter version"
flutter --version

log "Resolving dependencies"
cd "$REPO_ROOT"
flutter pub get
for pkg in packages/*/; do
  if [ -f "$pkg/pubspec.yaml" ]; then
    (cd "$pkg" && dart pub get)
  fi
done

log "Setup complete. flutter/dart are on PATH via $BIN_DIR"
