#!/bin/bash
set -euo pipefail

# Script de instalación de Hermes Orchestrator en una VM Ubuntu.
# Ejecutar como root en el servidor.

HERMES_USER="${HERMES_USER:-hermes}"
HERMES_HOME="${HERMES_HOME:-/var/lib/hermes}"
REPO_DIR="${REPO_DIR:-$(pwd)}"

echo "=== Instalando dependencias ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  curl \
  ca-certificates \
  git \
  nodejs \
  npm \
  python3 \
  python3-pip \
  python3-venv \
  sshpass \
  jq \
  gettext-base

echo "=== Instalando Hermes Agent ==="
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# El install script de Hermes instala bajo ~/.hermes del usuario root.
# Movemos/añadimos symlinks para el servicio del sistema.
HERMES_BIN="$(find /root -name hermes -type f -path '*bin/hermes' 2>/dev/null | head -n1)"
if [ -z "$HERMES_BIN" ]; then
  HERMES_BIN="/root/.hermes/bin/hermes"
fi
ln -sf "$HERMES_BIN" /usr/local/bin/hermes || true

echo "=== Creando usuario y home de Hermes ==="
if ! id "$HERMES_USER" &>/dev/null; then
  useradd -r -m -d "$HERMES_HOME" -s /bin/bash "$HERMES_USER"
fi
mkdir -p "$HERMES_HOME"
chown -R "$HERMES_USER:$HERMES_USER" "$HERMES_HOME"

echo "=== Copiando configuración ==="
if [ -f "$REPO_DIR/.env" ]; then
  install -o "$HERMES_USER" -g "$HERMES_USER" -m 600 "$REPO_DIR/.env" "$HERMES_HOME/.env"
fi

# Genera config.yaml aplicando variables de entorno
set -a
# shellcheck source=/dev/null
source "$HERMES_HOME/.env"
set +a
envsubst < "$REPO_DIR/config/hermes-config.yaml.template" > "$HERMES_HOME/config.yaml"
chown "$HERMES_USER:$HERMES_USER" "$HERMES_HOME/config.yaml"
chmod 600 "$HERMES_HOME/config.yaml"

echo "=== Instalando skill custom ==="
mkdir -p "$HERMES_HOME/skills/github-orchestrator"
cp "$REPO_DIR/skills/github-orchestrator/SKILL.md" "$HERMES_HOME/skills/github-orchestrator/SKILL.md"
chown -R "$HERMES_USER:$HERMES_USER" "$HERMES_HOME/skills"

echo "=== Configurando servicio systemd ==="
cp "$REPO_DIR/systemd/hermes-gateway.service" /etc/systemd/system/hermes-gateway.service
# Ajusta el path del binario en el servicio
sed -i "s|ExecStart=.*|ExecStart=$HERMES_BIN gateway|" /etc/systemd/system/hermes-gateway.service
systemctl daemon-reload

echo "=== Instalación lista ==="
echo "Ahora debes:"
echo "1. Autenticar gh CLI si aún no lo has hecho: sudo -u $HERMES_USER gh auth login"
echo "2. Emparejar WhatsApp: sudo -u $HERMES_USER HERMES_HOME=$HERMES_HOME hermes whatsapp"
echo "3. Iniciar el gateway: sudo systemctl enable --now hermes-gateway"
echo "4. Ver logs: sudo journalctl -u hermes-gateway -f"
