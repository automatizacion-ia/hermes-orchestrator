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

# Genera config.yaml si no existe o si es obsoleo (falta telegram enabled)
if [ ! -f "$HERMES_HOME/config.yaml" ] || ! grep -q "telegram:" "$HERMES_HOME/config.yaml" || ! grep -A2 "telegram:" "$HERMES_HOME/config.yaml" | grep -q "enabled:"; then
  echo "Generando $HERMES_HOME/config.yaml desde plantilla..."
  envsubst < /workspace/config/hermes-config.yaml.template > "$HERMES_HOME/config.yaml"
fi

# Ejecuta el comando recibido (por defecto: hermes gateway)
exec "$@"
