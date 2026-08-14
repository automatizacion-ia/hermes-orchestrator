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

echo "Listando repositorios de $ORG..."
repos=$(gh repo list "$ORG" --json name -q '.[].name' --limit 1000)

for repo in $repos; do
  full="$ORG/$repo"

  add_hook() {
    local path="$1"
    local events="$2"
    local url="${WEBHOOK_URL%/}/${path}"

    # Comprueba si ya existe un webhook idéntico
    existing=$(gh api "repos/$full/hooks" --jq ".[] | select(.config.url==\"$url\") | .id" 2>/dev/null || true)
    if [ -n "$existing" ]; then
      echo "  [$full] webhook $path ya existe (id=$existing)"
      return
    fi

    echo "  [$full] creando webhook $path -> $url"
    gh api "repos/$full/hooks" \
      --method POST \
      -f name=web \
      -f config.url="$url" \
      -f config.content_type=json \
      -f config.secret="$WEBHOOK_SECRET" \
      -f events="$events" \
      --silent
  }

  if [ "$TYPE" = "issue" ] || [ "$TYPE" = "both" ]; then
    add_hook "github-issue" "issues"
  fi
  if [ "$TYPE" = "pr" ] || [ "$TYPE" = "both" ]; then
    add_hook "github-pr" "pull_request"
  fi
done

echo "Listo."
