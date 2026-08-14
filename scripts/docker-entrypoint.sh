#!/bin/bash
set -e

export HERMES_HOME="${HERMES_HOME:-/var/lib/hermes}"
export PATH="/opt/node22/bin:${PATH}"
mkdir -p "$HERMES_HOME"

# Asegura que el archivo .env esté cargado si existe
if [ -f /workspace/.env ]; then
  set -a
  # shellcheck source=/dev/null
  source /workspace/.env
  set +a
fi

# Genera config.yaml si no existe o si es obsoleo (falta whatsapp enabled)
if [ ! -f "$HERMES_HOME/config.yaml" ] || ! grep -q "whatsapp:" "$HERMES_HOME/config.yaml" || ! grep -A2 "whatsapp:" "$HERMES_HOME/config.yaml" | grep -q "enabled:"; then
  echo "Generando $HERMES_HOME/config.yaml desde plantilla..."
  envsubst < /workspace/config/hermes-config.yaml.template > "$HERMES_HOME/config.yaml"
fi

# Copia el bridge de WhatsApp a HERMES_HOME si no existe
# (el bridge ya tiene el parche QR-web aplicado en build time)
BRIDGE_SRC="/usr/local/lib/hermes-agent/scripts/whatsapp-bridge"
BRIDGE_DIR="$HERMES_HOME/scripts/whatsapp-bridge"
if [ -d "$BRIDGE_SRC" ] && [ ! -f "$BRIDGE_DIR/bridge.js" ]; then
  echo "Copiando bridge de WhatsApp a $BRIDGE_DIR..."
  mkdir -p "$HERMES_HOME/scripts"
  cp -r "$BRIDGE_SRC" "$BRIDGE_DIR"
fi

# Inicia el bridge de WhatsApp en background si no hay credenciales
SESSION_DIR="$HERMES_HOME/platforms/whatsapp/session"
if [ ! -f "$SESSION_DIR/creds.json" ]; then
  echo "No hay credenciales de WhatsApp. Iniciando bridge en modo QR-web..."
  mkdir -p "$SESSION_DIR"
  export WHATSAPP_QR_WEB_PORT="${WHATSAPP_QR_WEB_PORT:-8080}"
  /opt/node22/bin/node "$BRIDGE_DIR/bridge.js" \
    --port 3002 \
    --session "$SESSION_DIR" \
    --mode "${WHATSAPP_MODE:-bot}" &
fi

# Ejecuta el comando recibido (por defecto: hermes gateway)
exec "$@"
