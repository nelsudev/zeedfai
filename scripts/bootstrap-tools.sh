#!/usr/bin/env bash
# Installs the zeedfai toolchain into ~/.local (no sudo, except docker, which must already exist).
set -euo pipefail

BIN="$HOME/.local/bin"
mkdir -p "$BIN"
export PATH="$BIN:$HOME/.local/go/bin:$PATH"

GO_VERSION=1.23.4
KIND_VERSION=v0.27.0
KUBECTL_VERSION=v1.32.3
HELM_VERSION=v3.17.2

arch=$(uname -m); case "$arch" in x86_64) arch=amd64;; aarch64) arch=arm64;; esac

if ! command -v go >/dev/null; then
  echo ">> Installing Go $GO_VERSION"
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${arch}.tar.gz" | tar -C "$HOME/.local" -xz
  mv -f "$HOME/.local/go" "$HOME/.local/go" 2>/dev/null || true
fi

if ! command -v kind >/dev/null; then
  echo ">> Installing kind $KIND_VERSION"
  curl -fsSLo "$BIN/kind" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${arch}" && chmod +x "$BIN/kind"
fi

if ! command -v kubectl >/dev/null; then
  echo ">> Installing kubectl $KUBECTL_VERSION"
  curl -fsSLo "$BIN/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" && chmod +x "$BIN/kubectl"
fi

if ! command -v helm >/dev/null; then
  echo ">> Installing helm $HELM_VERSION"
  curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${arch}.tar.gz" | tar -xzO "linux-${arch}/helm" > "$BIN/helm" && chmod +x "$BIN/helm"
fi

if ! command -v flux >/dev/null; then
  echo ">> Installing flux (latest)"
  curl -fsSL https://fluxcd.io/install.sh | BIN_DIR="$BIN" bash
fi

echo
echo "Add this to your shell profile if you haven't already:"
echo '  export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$PATH"'
for t in go kind kubectl helm flux docker; do printf '%-8s %s\n' "$t" "$(command -v $t || echo MISSING)"; done
