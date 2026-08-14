# Hermes Orchestrator

Orquestador híbrido para la organización **automatizacion-ia**:

- **Hermes Agent** → entry point y gateway (WhatsApp, Slack, webhooks).
- **Kimi API** → LLM de planificación y análisis.
- **Jules (Google)** → ejecución de código en GitHub.

Este repositorio contiene la configuración como código, skills custom y scripts para desplegar el orquestador en una VM o en Dokploy/Docker.

## Arquitectura

```text
Usuario (WhatsApp/Slack)  │  GitHub (issues/PRs)
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

- Hermes recibe mensajes por WhatsApp o eventos de GitHub.
- Para issues/PRs, analiza con Kimi, notifica al admin por WhatsApp y espera aprobación.
- Solo si el admin aprueba, Hermes invoca a **Jules mediante su API** para que cree un PR con el cambio.

## Requisitos

- VM/cloud server con **8 GB RAM recomendados** (mínimo funcional 4 GB, pero justo con gateway + Kimi + WhatsApp).
- Ubuntu 22.04/24.04 o cualquier Linux con Docker.
- Node.js 18+ (para el bridge de WhatsApp de Hermes).
- `curl`, `git`, `gh` CLI autenticado.
- Tokens:
  - `KIMI_API_KEY` para Kimi Code API.
  - `JULES_API_KEY` para invocar a Jules por API.
  - `GITHUB_TOKEN` clásico con permisos `repo`, `admin:org_hook`, `admin:repo_hook`.
  - `GITHUB_WEBHOOK_SECRET` para validar webhooks.

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

4. Empareja WhatsApp:
   ```bash
   sudo -u hermes HERMES_HOME=/var/lib/hermes hermes whatsapp
   # Escanea el QR con la cuenta del bot
   ```

5. Inicia el gateway:
   ```bash
   sudo systemctl enable --now hermes-gateway
   ```

## Despliegue en Dokploy/Docker

El `docker-compose.yml` ya incluye un volumen persistente (`hermes-data`) para que no se pierdan la sesión de WhatsApp, memorias ni estado de Hermes cuando el contenedor se reinicie.

### Pasos

1. **Fork o sube este repo** a tu cuenta de GitHub.

2. **En Dokploy**, crea un nuevo proyecto tipo **Docker Compose** y selecciona el repo.

3. **Configura las variables de entorno** en Dokploy (Environment). Copia todo el contenido de `.env.example` y rellena los valores reales:
   ```bash
   KIMI_API_KEY=sk-...
   JULES_API_KEY=...
   GITHUB_TOKEN=ghp_...
   GITHUB_WEBHOOK_SECRET=...
   ADMIN_WHATSAPP_NUMBER=584120787255
   WHATSAPP_ENABLED=true
   WHATSAPP_MODE=bot
   WHATSAPP_ALLOWED_USERS=584120787255
   WEBHOOK_PORT=8644
   WEBHOOK_PUBLIC_URL=https://hermes.tudominio.com
   HERMES_HOME=/var/lib/hermes
   ```

4. **Expón el puerto** `8644` en Dokploy y asigna un dominio con HTTPS.

5. **Empareja WhatsApp** la primera vez:
   - Ve a los logs del contenedor en vivo.
   - Busca el QR generado por Hermes.
   - Escanea el QR con la cuenta del bot.
   - La sesión se guarda en el volumen persistente; no tendrás que escanear de nuevo en redeploys.

6. **Configura los webhooks en GitHub** apuntando a tu dominio:
   - Issues: `https://hermes.tudominio.com/webhooks/github-issue`
   - PRs: `https://hermes.tudominio.com/webhooks/github-pr`

> ⚠️ **Importante:** el volumen `hermes-data` conserva todo lo de `/var/lib/hermes`. Sin él, perderías la sesión de WhatsApp y las memorias en cada redeploy.

## Estado actual de la VM (mfcodev.x5servers.cloud)

- Hermes Agent v0.20.1 instalado en `/var/lib/hermes`, usuario `hermes`.
- Kimi API configurada como proveedor LLM (`kimi-for-coding`).
- WhatsApp Baileys emparejado y corriendo en modo bot (puerto 3002).
- Webhook de GitHub escuchando en `http://mfcodev.x5servers.cloud:8644`.
- Webhooks configurados en repos de `automatizacion-ia` apuntando a `/webhooks/github-issue` y `/webhooks/github-pr`.
- Flujo validado: issue de prueba generó análisis de Kimi, se entregó por WhatsApp, y tras aprobación se invocó a Jules creando un PR.

> ⚠️ **Nota sobre HTTPS:** actualmente el webhook de la VM usa HTTP. GitHub lo acepta, pero es inseguro. La solución definitiva de HTTPS pasa por Dokploy/Traefik.

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

## Uso por WhatsApp

- Envía un mensaje al número del bot.
- Para issues/PRs nuevos, el bot te enviará un resumen y esperará tu aprobación.
- Responde `sí`, `apruebo`, `hazlo`, `procede` o `dale` para invocar a Jules.
- Responde `no` para ignorar o pedir más información.

## Notas de seguridad

- No compartas el directorio `~/.hermes/platforms/whatsapp/session`; contiene las credenciales de WhatsApp.
- Usa un número de teléfono dedicado para el bot, no tu personal.
- Mantén `.env` fuera del control de versiones.
- Limita `WHATSAPP_ALLOWED_USERS` a números conocidos.

## Roadmap

- [x] Crear repo y estructura base
- [x] Integración Kimi API
- [x] Gateway WhatsApp (Baileys)
- [x] Webhooks de GitHub
- [x] Entrega de resúmenes por WhatsApp
- [x] Invocación de Jules por API
- [ ] Integración Slack
- [ ] Skill de auto-mejora continua
- [ ] Tests end-to-end
- [ ] HTTPS para webhooks en VM
