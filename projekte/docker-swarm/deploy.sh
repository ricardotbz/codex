#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

mode="${1:-http}"
case "$mode" in
  http|tls) ;;
  *) echo "Verwendung: bash deploy.sh [http|tls]" >&2; exit 1 ;;
esac
export STACK_NAME="${STACK_NAME:-demo}"
export DOMAIN="${DOMAIN:-demo.localhost}"
if [[ ! "$STACK_NAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
  echo "STACK_NAME muss mit a-z beginnen und darf a-z, 0-9, _ und - enthalten." >&2
  exit 1
fi
if [[ ! "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
  echo "DOMAIN muss ein Hostname ohne Protokoll, Port oder Pfad sein." >&2
  exit 1
fi
if [[ "$(docker info --format '{{.Swarm.ControlAvailable}}')" != true ]]; then
  echo "Auf einem Swarm-Manager ausführen. Anleitung: README.md" >&2
  exit 1
fi
managers="$(docker node ls --filter role=manager --filter node.label=traefik=true --format '{{.ID}}')"
if [[ -z "$managers" || "$managers" == *$'\n'* ]]; then
  echo "Genau ein Manager muss das Label traefik=true tragen. Siehe README.md." >&2
  exit 1
fi
# Docker Configs sind unveränderlich: neuer Inhalt bekommt einen neuen Namen.
WEBSITE_VERSION="$(sha256sum website/index.html | cut -c1-12)"
export WEBSITE_VERSION
files=(-c stack.yml)
if [[ "$mode" == tls ]]; then
  : "${ACME_EMAIL:?Für HTTPS zuerst ACME_EMAIL exportieren.}"
  if [[ "$DOMAIN" == *localhost* || "$DOMAIN" != *.* ]]; then
    echo "HTTPS benötigt eine öffentliche Domain, die auf den Traefik-Node zeigt." >&2
    exit 1
  fi
  files+=(-c stack.tls.yml)
fi
docker stack config "${files[@]}" >/dev/null
docker stack deploy --resolve-image always "${files[@]}" "$STACK_NAME"
echo "Deployment angefordert. Status: docker stack services $STACK_NAME"
echo "Tasks prüfen: docker stack ps $STACK_NAME --no-trunc"
