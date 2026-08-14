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

# Ejecuta el comando recibido (por defecto: hermes gateway)
exec "$@"
