---
name: github-orchestrator
description: Orquesta issues y PRs de GitHub usando Kimi para analizar y notificar al admin; solo ejecuta con Jules tras aprobación explícita.
version: 1.3.0
metadata:
  hermes:
    tags: [github, jules, kimi, orchestration, whatsapp]
    category: devops
---

# GitHub Orchestrator

## When to Use

Este skill se activa cuando Hermes recibe:
- Un **webhook de GitHub** (issue o pull request), o
- Una **respuesta del administrador por WhatsApp** aprobando o rechazando un issue/PR pendiente.

Su trabajo es:

1. Analizar el evento usando el modelo principal (Kimi).
2. Notificar al administrador por WhatsApp con un resumen claro.
3. Esperar la aprobación del administrador.
4. Solo si el admin aprueba, invocar a **Jules** mediante la API para que ejecute el cambio.

## Procedure

### A. Evento entrante de GitHub (webhook)

1. **Analiza el payload** que ya viene en el prompt del webhook.
   - Identifica si es `issue` o `pull_request`.
   - Extrae: repositorio (`owner/repo`), número, título, autor, URL, body, acción.

2. **Genera un resumen para el admin** en español, incluyendo:
   - Qué pide o propone.
   - Repo y URL.
   - Opciones de solución (para issues) o resumen de cambios/riesgos (para PRs).
   - Posibles impedimentos o información faltante.

3. **Guarda el contexto del evento** en `/var/lib/hermes/state/pending_github_event.json` usando la tool `terminal`:
   ```bash
   mkdir -p /var/lib/hermes/state
   cat > /var/lib/hermes/state/pending_github_event.json <<'JSON'
   {
     "repo": "owner/repo",
     "number": 4,
     "type": "issue",
     "url": "https://github.com/owner/repo/issues/4",
     "title": "...",
     "action": "opened"
   }
   JSON
   ```
   - `type` debe ser `"issue"` o `"pull_request"`.
   - `number` es el número del issue o PR.
   - `repo` es el nombre completo `owner/repo`.

4. **Entrega la respuesta por WhatsApp** al número configurado en `deliver_extra.chat_id`.
   - El webhook ya hace esta entrega; tú solo genera el mensaje.
   - Incluye la URL del issue/PR para que el admin pueda revisarlo.
   - Dile al admin que responda con `sí`, `apruebo`, `hazlo`, `procede` o `dale` para invocar a Jules.

### B. Respuesta del administrador por WhatsApp

1. **Ejecuta el script de aprobación** usando la tool `terminal`:
   ```bash
   /var/lib/hermes/bin/approve-github
   ```

2. **Interpreta la salida del script**:
   - Si devuelve `OK: sesión de Jules creada: <URL>`:
     - Responde al admin por WhatsApp: "✅ Ya inicié una sesión con Jules: <URL>. Debería crear un PR en breve."
   - Si devuelve `No hay issue/PR pendiente de aprobación.`:
     - Responde al admin de forma normal, sin mencionar GitHub.
   - Si devuelve un error (por ejemplo, `JULES_API_KEY no está configurada`):
     - Informa al admin que no se pudo invocar a Jules y muestra el error.

3. **No llames a la API de Jules directamente**; usa siempre `/var/lib/hermes/bin/approve-github`.

## Pitfalls

- **Nunca invoques a Jules sin aprobación explícita.** La palabra clave debe ser clara.
- **Siempre guarda el contexto del evento** al recibir el webhook, o no podrás invocar a Jules correctamente cuando el admin responda por WhatsApp.
- El script `/var/lib/hermes/bin/approve-github` se encarga de borrar el archivo pendiente después de actuar.
- Si el issue es ambiguo o falta contexto, pide aclaración antes de actuar.
- Si el PR toca flujos sensibles (CI/CD, secrets, permisos, deploy), menciona el riesgo en el resumen.
- No ejecutes código tú mismo; tu rol es planificar, notificar y orquestar. La ejecución la delegas a Jules.

## Verification

- El evento se guarda en `/var/lib/hermes/state/pending_github_event.json`.
- Se crea una sesión en Jules y se devuelve una URL.
- El administrador recibe la confirmación por WhatsApp.
- Si no hay aprobación, no se invoca a Jules.
