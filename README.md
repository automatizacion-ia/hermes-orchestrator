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
   Comentario @jules en issue/PR
```

- Hermes recibe mensajes por WhatsApp o eventos de GitHub.
- Para issues/PRs, analiza con Kimi, notifica al admin por WhatsApp y espera aprobación.
- Solo si el admin aprueba, Hermes comenta `@jules` para que Jules ejecute el cambio.

## Requisitos

- VM/cloud server con **8 GB RAM recomendados** (mínimo funcional 4 GB, pero justo con gateway + Kimi + WhatsApp).
- Ubuntu 22.04/24.04 o cualquier Linux con Docker.
- Node.js 18+ (para el bridge de WhatsApp de Hermes).
- `curl`, `git`, `gh` CLI autenticado.
- Tokens:
  - `KIMI_API_KEY` para Kimi Code API.
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

## Estado actual de la VM (mfcodev.x5servers.cloud)

- Hermes Agent v0.20.1 instalado en `/var/lib/hermes`, usuario `hermes`.
- Kimi API configurada como proveedor LLM (`kimi-for-coding`).
- WhatsApp Baileys emparejado y corriendo en modo bot (puerto 3002).
- Webhook de GitHub escuchando en `http://mfcodev.x5servers.cloud:8644`.
- Webhooks configurados en repos de `automatizacion-ia` apuntando a `/webhooks/github-issue` y `/webhooks/github-pr`.
- Flujo validado: issue de prueba generó análisis de Kimi y se entregó por WhatsApp.

> ⚠️ **Nota sobre HTTPS:** actualmente el webhook usa HTTP. GitHub acepta el delivery, pero es inseguro. La solución definitiva de HTTPS debe pasar por Dokploy/Traefik o un túnel seguro.

## Despliegue en Dokploy/Docker

1. Rellena `.env`.
2. Sube el repo a Dokploy como **Docker Compose**.
3. Expón el puerto `8644` (webhooks) y configura HTTPS/Traefik.
4. Configura en GitHub los webhooks apuntando a `https://<tu-dominio>/webhooks/github-issue` y `github-pr`.

## Configuración de webhooks en GitHub

Para cada repositorio de `automatizacion-ia` que quieras monitorear:

1. Settings → Webhooks → Add webhook.
2. Payload URL:
   - Issues: `https://mfcodev.x5servers.cloud:8644/webhooks/github-issue`
   - PRs: `https://mfcodev.x5servers.cloud:8644/webhooks/github-pr`
3. Content type: `application/json`.
4. Secret: el valor de `GITHUB_WEBHOOK_SECRET`.
5. Eventos: **Issues** y/o **Pull requests**.

Puedes automatizarlo con:

```bash
export GITHUB_TOKEN=ghp_...
export WEBHOOK_URL=https://mfcodev.x5servers.cloud:8644/webhooks
export WEBHOOK_SECRET=...
bash scripts/setup-webhooks.sh automatizacion-ia issue
```

## Uso por WhatsApp

- Envía un mensaje al número del bot.
- Para issues/PRs nuevos, el bot te enviará un resumen y esperará tu aprobación.
- Responde `sí`, `apruebo`, `hazlo`, `procede` o `dale` para que comente `@jules`.
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
- [ ] Integración Slack
- [ ] Skill de auto-mejora continua
- [ ] Tests end-to-end
- [ ] HTTPS para webhooks

Flujo Hermes → Kimi → WhatsApp → Jules API probado exitosamente.
