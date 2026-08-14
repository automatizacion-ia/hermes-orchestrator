# Hermes Orchestrator

Orquestador híbrido para la organización **automatizacion-ia**:

- **Hermes Agent** → entry point y gateway (Telegram, Slack, webhooks).
- **Kimi API** → LLM de planificación y análisis.
- **Jules (Google)** → ejecución de código en GitHub.

Este repositorio contiene la configuración como código, skills custom y scripts para desplegar el orquestador en una VM o en Dokploy/Docker.

## Arquitectura

```text
Usuario (Telegram/Slack)  │  GitHub (issues/PRs)
         │                         │
         ▼                         ▼
   Hermes Gateway ◄───────── Webhook adapter
         │
         ▼
   Kimi API (planning)
         │
         ▼ (tras aprobación del admin)
   API de Jules → PR con el cambio
```

- Hermes recibe mensajes por Telegram o eventos de GitHub.
- Para issues/PRs, analiza con Kimi, notifica al admin por Telegram y espera aprobación.
- Solo si el admin aprueba, Hermes invoca a **Jules mediante su API** para que cree un PR con el cambio.

## Requisitos

- VM/cloud server con **4 GB RAM** (suficiente para Telegram + Kimi).
- Ubuntu 22.04/24.04 o cualquier Linux con Docker.
- `curl`, `git`, `gh` CLI autenticado.
- Tokens:
  - `KIMI_API_KEY` para Kimi Code API.
  - `JULES_API_KEY` para invocar a Jules por API.
  - `GITHUB_TOKEN` clásico con permisos `repo`, `admin:org_hook`, `admin:repo_hook`.
  - `GITHUB_WEBHOOK_SECRET` para validar webhooks.
  - `TELEGRAM_BOT_TOKEN` de @BotFather.

## Estructura

```text
.
├── Dockerfile                         # Imagen base con Hermes instalado
├── docker-compose.yml                 # Despliegue en Dokploy/Docker
├── .env.example                       # Variables de entorno requeridas
├── config/hermes-config.yaml.template # Plantilla de configuración de Hermes
├── skills/github-orchestrator/        # Skill custom para orquestar GitHub
├── scripts/                           # Scripts de instalación y setup
└── systemd/hermes-gateway.service     # Servicio systemd para VM
```

## Configuración de Telegram

1. **Crea el bot:**
   - Abre Telegram y busca **@BotFather**.
   - Envía `/newbot`.
   - Ponle un nombre y username.
   - Guarda el **token** que te da.

2. **Obtén tu chat ID:**
   - Inicia una conversación con tu bot.
   - Envía cualquier mensaje.
   - Visita `https://api.telegram.org/bot<TOKEN>/getUpdates`.
   - Busca `"chat":{"id":123456789` y anota ese número.

3. **Configura `.env`:**
   ```bash
   TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrSTUvwxyz
   ADMIN_TELEGRAM_CHAT_ID=123456789
   TELEGRAM_ALLOWED_USERS=123456789
   ```

## Instalación rápida en VM

1. Clona este repo:
   ```bash
   git clone https://github.com/automatizacion-ia/hermes-orchestrator.git
   cd hermes-orchestrator
   ```

2. Copia y rellena `.env`:
   ```bash
   cp .env.example .env
   # edita .env con tus credenciales
   ```

3. Ejecuta el instalador:
   ```bash
   sudo bash scripts/install-hermes-vm.sh
   ```

4. Inicia el gateway:
   ```bash
   sudo systemctl enable --now hermes-gateway
   ```

## Despliegue en Dokploy/Docker

El `docker-compose.yml` ya incluye un volumen persistente (`hermes-data`) para que no se pierdan las memorias ni el estado de Hermes cuando el contenedor se reinicie.

### Pasos

1. **Fork o sube este repo** a tu cuenta de GitHub.

2. **En Dokploy**, crea un nuevo proyecto tipo **Docker Compose** y selecciona el repo.

3. **Configura las variables de entorno** en Dokploy (Environment). Copia todo el contenido de `.env.example` y rellena los valores reales.

4. **Expón el puerto** `8644` en Dokploy y asigna un dominio con HTTPS.

5. **Configura los webhooks en GitHub** apuntando a tu dominio:
   - Issues: `https://hermes.tudominio.com/webhooks/github-issue`
   - PRs: `https://hermes.tudominio.com/webhooks/github-pr`

> ⚠️ **Importante:** el volumen `hermes-data` conserva todo lo de `/var/lib/hermes`. Sin él, perderías las memorias en cada redeploy.

## Configuración de webhooks en GitHub

Para cada repositorio que quieras monitorear:

1. Settings → Webhooks → Add webhook.
2. Payload URL:
   - Issues: `https://hermes.tudominio.com/webhooks/github-issue`
   - PRs: `https://hermes.tudominio.com/webhooks/github-pr`
3. Content type: `application/json`.
4. Secret: el valor de `GITHUB_WEBHOOK_SECRET`.
5. Eventos: **Issues** y/o **Pull requests**.

Puedes automatizarlo con:

```bash
export GITHUB_TOKEN=ghp_...
export WEBHOOK_URL=https://hermes.tudominio.com/webhooks
export WEBHOOK_SECRET=...
bash scripts/setup-webhooks.sh owner-org issue
```

## Uso por Telegram

- Envía un mensaje al bot de Telegram.
- Para issues/PRs nuevos, el bot te enviará un resumen y esperará tu aprobación.
- Responde `sí`, `apruebo`, `hazlo`, `procede` o `dale` para invocar a Jules.
- Responde `no` para ignorar o pedir más información.

## Notas de seguridad

- Mantén `.env` fuera del control de versiones.
- Limita `TELEGRAM_ALLOWED_USERS` a IDs conocidos.
- No compartas el token del bot de Telegram.

## Roadmap

- [x] Crear repo y estructura base
- [x] Integración Kimi API
- [x] Gateway Telegram
- [x] Webhooks de GitHub
- [x] Entrega de resúmenes por Telegram
- [x] Invocación de Jules por API
- [ ] Integración Slack
- [ ] Skill de auto-mejora continua
- [ ] Tests end-to-end
