#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/mobile"
FLUTTER="${FLUTTER:-/Users/user/MeloCode/flutter/bin/flutter}"
API_URL="${API_URL:-http://localhost:8000/api/v1}"

if [[ ! -x "$FLUTTER" ]]; then
  FLUTTER="$(command -v flutter)"
fi

cd "$APP"
"$FLUTTER" pub get

build_portal() {
  local target="$1"
  local output="$2"

  "$FLUTTER" build web \
    --release \
    --no-web-resources-cdn \
    --base-href / \
    --dart-define=API_URL="$API_URL" \
    -t "$target" \
    -o "$output"
}

build_portal "lib/main_partner.dart" "$APP/build/web_partner"
build_portal "lib/main_admin.dart" "$APP/build/web_admin"

python3 - "$APP/build/web_partner" \
  "Miam · Espace Partenaire" \
  "Partenaire" \
  "Portail partenaire Miam : commandes, menu et performances du restaurant." \
  "#8B5CF6" <<'PY'
import json
import sys
from pathlib import Path

directory, title, short_name, description, color = sys.argv[1:]
root = Path(directory)
index = root / "index.html"
html = index.read_text()
html = html.replace("<title>Miam</title>", f"<title>{title}</title>")
html = html.replace(
    'content="Miam — plateforme de livraison de repas."',
    f'content="{description}"',
)
html = html.replace(
    'content="Miam">',
    f'content="{title}">',
)
index.write_text(html)

manifest_path = root / "manifest.json"
manifest = json.loads(manifest_path.read_text())
manifest.update(
    {
        "name": title,
        "short_name": short_name,
        "description": description,
        "theme_color": color,
        "background_color": "#FFF9F2",
        "orientation": "any",
    }
)
manifest_path.write_text(json.dumps(manifest, indent=4, ensure_ascii=False) + "\n")
PY

python3 - "$APP/build/web_admin" \
  "Miam · Espace Administrateur" \
  "Admin" \
  "Back-office Miam : pilotage, utilisateurs, restaurants et commandes." \
  "#211A16" <<'PY'
import json
import sys
from pathlib import Path

directory, title, short_name, description, color = sys.argv[1:]
root = Path(directory)
index = root / "index.html"
html = index.read_text()
html = html.replace("<title>Miam</title>", f"<title>{title}</title>")
html = html.replace(
    'content="Miam — plateforme de livraison de repas."',
    f'content="{description}"',
)
html = html.replace(
    'content="Miam">',
    f'content="{title}">',
)
index.write_text(html)

manifest_path = root / "manifest.json"
manifest = json.loads(manifest_path.read_text())
manifest.update(
    {
        "name": title,
        "short_name": short_name,
        "description": description,
        "theme_color": color,
        "background_color": "#FFF9F2",
        "orientation": "any",
    }
)
manifest_path.write_text(json.dumps(manifest, indent=4, ensure_ascii=False) + "\n")
PY

echo "Portails générés :"
echo "  $APP/build/web_partner"
echo "  $APP/build/web_admin"
