#!/bin/bash
set -e

export HERMES_HOME="${HERMES_HOME:-/var/lib/hermes}"
mkdir -p "$HERMES_HOME"

# Asegura que el archivo .env esté cargado si existe
if [ -f /workspace/.env ]; then
  set -a
  # shellcheck source=/dev/null
  source /workspace/.env
  set +a
fi

# Si no existe config.yaml, genera uno a partir de la plantilla
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
  echo "Generando $HERMES_HOME/config.yaml desde plantilla..."
  envsubst < /workspace/config/hermes-config.yaml.template > "$HERMES_HOME/config.yaml"
fi

# Asegura que el bridge de WhatsApp tenga el parche QR-web aplicado.
# Hermes puede regenerar el bridge al arrancar, por lo que se re-aplica en runtime.
BRIDGE_DIR="$HERMES_HOME/scripts/whatsapp-bridge"
if [ -f "$BRIDGE_DIR/bridge.js" ]; then
  if grep -q "import qrcode from 'qrcode-terminal';" "$BRIDGE_DIR/bridge.js"; then
    echo "Aplicando parche QR-web al bridge de WhatsApp..."
    (cd "$BRIDGE_DIR" && npm install qrcode && patch -p0 -i /workspace/scripts/whatsapp-bridge-qr.patch)
  fi
fi

# Ejecuta el comando recibido (por defecto: hermes gateway)
exec "$@"
