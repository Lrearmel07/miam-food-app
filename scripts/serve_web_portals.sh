#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARTNER_DIR="$ROOT/mobile/build/web_partner"
ADMIN_DIR="$ROOT/mobile/build/web_admin"
RUN_DIR="$ROOT/.run"

for directory in "$PARTNER_DIR" "$ADMIN_DIR"; do
  if [[ ! -f "$directory/index.html" ]]; then
    echo "Build web manquant : $directory"
    echo "Lancez d'abord scripts/build_web_portals.sh"
    exit 1
  fi
done

if ! curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1; then
  echo "Attention : l'API Miam ne répond pas sur http://127.0.0.1:8000"
fi

mkdir -p "$RUN_DIR"

for port in 8081 8082; do
  pids="$(lsof -ti "tcp:$port" 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    echo "$pids" | xargs kill
    sleep 0.3
  fi
done

nohup python3 -m http.server 8081 \
  --bind 127.0.0.1 \
  --directory "$PARTNER_DIR" \
  >"$RUN_DIR/partner_web.log" 2>&1 &
echo $! >"$RUN_DIR/partner_web.pid"

nohup python3 -m http.server 8082 \
  --bind 127.0.0.1 \
  --directory "$ADMIN_DIR" \
  >"$RUN_DIR/admin_web.log" 2>&1 &
echo $! >"$RUN_DIR/admin_web.pid"

sleep 0.7

echo "Portail partenaire : http://127.0.0.1:8081"
echo "Portail admin      : http://127.0.0.1:8082"
echo
echo "Connexion partenaire : partner@miam.app / demo1234"
echo "Connexion admin      : admin@miam.app / demo1234"
