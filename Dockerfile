FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HERMES_HOME=/var/lib/hermes
ENV PATH="${HERMES_HOME}/.hermes/bin:${PATH}"

# Instala dependencias base
RUN apt-get update && apt-get install -y \
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
    patch \
    && rm -rf /var/lib/apt/lists/*

# Instala Hermes Agent (el script instala uv, Python 3.11, etc.)
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# Copia el parche del bridge de WhatsApp antes de aplicarlo
COPY scripts/whatsapp-bridge-qr.patch /tmp/whatsapp-bridge-qr.patch

# Aplica el parche QR-web al bridge de WhatsApp de Hermes e instala la librería qrcode
RUN for BRIDGE_DIR in $(find /usr/local/lib/hermes-agent /var/lib/hermes -path "*/scripts/whatsapp-bridge" -type d 2>/dev/null); do \
      echo "Patching WhatsApp bridge in $BRIDGE_DIR"; \
      cd "$BRIDGE_DIR"; \
      npm install qrcode; \
      patch -p0 -i /tmp/whatsapp-bridge-qr.patch || true; \
    done

# Crea el home de Hermes y directorio de trabajo
RUN mkdir -p /var/lib/hermes /workspace
WORKDIR /workspace

# Copia el repo al contenedor
COPY . /workspace

# Script de entrada: aplica plantillas de config si no existen y arranca el gateway
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8644

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["hermes", "gateway"]
