#!/bin/bash
set -e

export PATH="/opt/node22/bin:$PATH"

echo "Descargando Hermes Agent..."
cd /tmp
curl -fsSL -o hermes-agent.tar.gz "https://github.com/automatizacion-ia/hermes-orchestrator/releases/download/hermes-agent-v1/hermes-agent.tar.gz"
tar -xzf hermes-agent.tar.gz

echo "Instalando dependencias del bridge..."
cd hermes-agent/scripts/whatsapp-bridge
npm install

echo "Iniciando bridge de WhatsApp..."
node bridge.js --port 3002 --session /var/lib/hermes/platforms/whatsapp/session --mode bot
