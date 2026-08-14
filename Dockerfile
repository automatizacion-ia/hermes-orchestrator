FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HERMES_HOME=/var/lib/hermes
ENV PATH="${HERMES_HOME}/.hermes/bin:${PATH}"

# Habilita universe e instala dependencias base
RUN apt-get update && apt-get install -y software-properties-common \
    && add-apt-repository universe \
    && apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    sshpass \
    jq \
    patch \
    gettext-base \
    ripgrep \
    ffmpeg \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Instala uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Instala Python 3.11 con uv
RUN uv python install 3.11

# Instala Node.js 22 en HERMES_HOME
RUN curl -fsSL https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-x64.tar.xz -o /tmp/node.tar.xz \
    && mkdir -p /var/lib/hermes/node \
    && tar -xJf /tmp/node.tar.xz -C /var/lib/hermes/node --strip-components=1 \
    && rm /tmp/node.tar.xz

# Descarga tarball de Hermes desde el release (evita git clone lento)
RUN curl -fsSL -o /tmp/hermes-agent.tar.gz \
    "https://github.com/automatizacion-ia/hermes-orchestrator/releases/download/hermes-agent-v1/hermes-agent.tar.gz" \
    && mkdir -p /usr/local/lib/hermes-agent \
    && tar -xzf /tmp/hermes-agent.tar.gz -C /usr/local/lib/hermes-agent --strip-components=1 \
    && rm /tmp/hermes-agent.tar.gz

WORKDIR /usr/local/lib/hermes-agent

# Crea venv e instala dependencias de Hermes (PyPI es rapido)
RUN uv venv venv --python 3.11 \
    && UV_PROJECT_ENVIRONMENT="/usr/local/lib/hermes-agent/venv" uv sync --extra all --locked

# Sincroniza skills y crea symlink de hermes
RUN mkdir -p /var/lib/hermes/skills \
    && /usr/local/lib/hermes-agent/venv/bin/python /usr/local/lib/hermes-agent/tools/skills_sync.py 2>/dev/null || true \
    && ln -sf /usr/local/lib/hermes-agent/venv/bin/hermes /usr/local/bin/hermes

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
