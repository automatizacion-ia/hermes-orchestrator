---
name: github-orchestrator
description: Orquesta issues y PRs de GitHub usando Kimi para analizar y notificar al admin; solo invoca a Jules tras aprobación explícita.
version: 1.0.0
metadata:
  hermes:
    tags: [github, jules, kimi, orchestration, whatsapp]
    category: devops
---

# GitHub Orchestrator

## When to Use

Este skill se activa cuando Hermes recibe un webhook de GitHub (issue o pull request). Su trabajo es:

1. Analizar el evento usando el modelo principal (Kimi).
2. Notificar al administrador por WhatsApp con un resumen claro.
3. Esperar la aprobación del administrador.
4. Solo si el admin aprueba, comentar en el issue/PR mencionando a **@jules** para que ejecute el cambio.

## Procedure

1. **Analiza el payload** que ya viene en el prompt del webhook.
   - Identifica si es `issue` o `pull_request`.
   - Extrae: repositorio, número, título, autor, URL, body, acción.

2. **Genera un resumen para el admin** en español, incluyendo:
   - Qué pide o propone.
   - Repo y URL.
   - Opciones de solución (para issues) o resumen de cambios/riesgos (para PRs).
   - Posibles impedimentos o información faltante.

3. **Entrega la respuesta por WhatsApp** al número configurado en `deliver_extra.chat_id`.
   - El webhook ya hace esta entrega; tú solo genera el mensaje.

4. **Espera aprobación** (la conversación continúa por WhatsApp).
   - Si el admin responde con alguna de estas palabras clave: `sí`, `si`, `apruebo`, `hazlo`, `procede`, `dale`, `ok`, `vale`, `continúa`:
     - Para **issue**: comenta en el issue/PR:
       ```
       @jules please implement this fix.
       ```
     - Para **pull request**: comenta en el PR:
       ```
       @jules please review and merge if appropriate.
       ```
   - Si el admin responde `no`, `cancela`, `descarta`, `ignora`, explica brevemente que no se actuará.
   - Si pide más información, aclara o pregunta antes de invocar a Jules.

5. **Confirma al admin** por WhatsApp el resultado:
   - "Ya le pedí a Jules que lo revise: <URL del comentario>".
   - O "De acuerdo, no actuaré hasta que me des más detalles".

## Pitfalls

- **Nunca invoques a Jules sin aprobación explícita.** La palabra clave debe ser clara.
- Si el issue es ambiguo o falta contexto, pide aclaración antes de actuar.
- Si el PR toca flujos sensibles (CI/CD, secrets, permisos, deploy), menciona el riesgo en el resumen.
- No ejecutes código tú mismo; tu rol es planificar, notificar y orquestar. La ejecución la delegas a Jules.

## Verification

- El comentario de `@jules` aparece en el issue/PR correspondiente.
- El administrador recibe la confirmación por WhatsApp.
- Si no hay aprobación, no se genera ningún comentario en GitHub.
