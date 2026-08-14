#!/bin/bash
set -euo pipefail

# Configura webhooks de GitHub para todos los repos de una organización.
# Uso: setup-webhooks.sh <org> [issue|pr|both]

ORG="${1:-}"
TYPE="${2:-both}"
WEBHOOK_URL="${WEBHOOK_URL:-}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"

if [ -z "$ORG" ] || [ -z "$WEBHOOK_URL" ] || [ -z "$WEBHOOK_SECRET" ]; then
  echo "Uso: WEBHOOK_URL=https://... WEBHOOK_SECRET=... setup-webhooks.sh <org> [issue|pr|both]"
  exit 1
fi

TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "Error: GITHUB_TOKEN no está definido"
  exit 1
fi

echo "Listando repositorios de $ORG..."
repos=$(gh repo list "$ORG" --json name -q '.[].name' --limit 1000)

for repo in $repos; do
  full="$ORG/$repo"

  add_hook() {
    local path="$1"
    local event="$2"
    local url="${WEBHOOK_URL%/}/${path}"

    # Comprueba si ya existe un webhook idéntico
    existing=$(curl -fsS -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$full/hooks" 2>/dev/null | jq -r ".[] | select(.config.url==\"$url\") | .id" || true)
    if [ -n "$existing" ]; then
      echo "  [$full] webhook $path ya existe (id=$existing)"
      return
    fi

    echo "  [$full] creando webhook $path -> $url"
    curl -fsS -X POST \
      -H "Authorization: token $TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$full/hooks" \
      -d "$(jq -n --arg url "$url" --arg secret "$WEBHOOK_SECRET" --arg event "$event" '
        {
          name: "web",
          config: {url: $url, content_type: "json", secret: $secret},
          events: [$event],
          active: true
        }')" >/dev/null
  }

  if [ "$TYPE" = "issue" ] || [ "$TYPE" = "both" ]; then
    add_hook "github-issue" "issues"
  fi
  if [ "$TYPE" = "pr" ] || [ "$TYPE" = "both" ]; then
    add_hook "github-pr" "pull_request"
  fi
done

echo "Listo."
