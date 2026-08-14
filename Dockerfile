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
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Instala Hermes Agent (el script instala uv, Python 3.11, etc.)
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# Crea el home de Hermes y directorio de trabajo
RUN mkdir -p /var/lib/hermes /workspace
WORKDIR /workspace

# Copia el repo al contenedor
COPY . /workspace

# Script de entrada: aplica plantillas de config si no existen y arranca el gateway
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8644 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["hermes", "gateway"]
