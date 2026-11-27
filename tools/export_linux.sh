#!/usr/bin/env bash
# Genera el ejecutable de Linux (x86_64) y un .tar.gz listo para repartir.
# Requiere las plantillas de exportación de la misma versión de Godot (Editor → Gestionar plantillas de exportación).
# Uso: ./tools/export_linux.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=build/som-mini.x86_64
mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Linux" "$OUT" 2>&1 | grep -E "ERROR|error" | grep -v "still in use" && { echo "❌ la exportación falló"; exit 1; } || true
[ -x "$OUT" ] || { echo "❌ no se generó $OUT (¿faltan las plantillas de exportación?)"; exit 1; }

PKG=build/som-mini-linux
rm -rf "$PKG" && mkdir -p "$PKG"
cp "$OUT" "$PKG/"
cp assets/kenney_racing/License.txt "$PKG/LICENCIA-Kenney-CC0.txt"
cat > "$PKG/LEEME.txt" <<'TXT'
Mini SO — Linux (64 bits)

Cómo jugar:
  1. Descomprime esta carpeta donde quieras.
  2. Abre una terminal en ella y ejecuta:   ./som-mini.x86_64
     (si no arranca: chmod +x som-mini.x86_64)
  3. En el menú, "Online" para jugar con tus compañeros (necesitas una cuenta) o
     "Carrera rápida" para jugar solo.

Controles: flechas o WASD, Espacio = nitro, R = reaparecer, Esc = pausa. También mando.

Requisitos: Ubuntu 18.10 o posterior (u otra distribución con glibc 2.28+) y una tarjeta
gráfica con OpenGL 3.3 (cualquier PC de los últimos 10 años). No hace falta instalar nada más.

Tus datos (monedas, coches, récords) se guardan en ~/.local/share/godot/app_userdata/Mini SO/
TXT
chmod +x "$PKG/som-mini.x86_64"
tar -C build -czf build/som-mini-linux.tar.gz som-mini-linux
# Datos para la página de descargas del servidor (servidor/publish-download.sh los publica)
SIZE=$(stat -c %s build/som-mini-linux.tar.gz)
SHA=$(sha256sum build/som-mini-linux.tar.gz | cut -d' ' -f1)
VERSION="$(date +%Y-%m-%d) · $(git rev-parse --short HEAD 2>/dev/null || echo sin-git)"
cat > build/som-mini-linux.json <<JSON
{"file": "som-mini-linux.tar.gz", "version": "$VERSION", "size": $SIZE, "sha256": "$SHA", "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
JSON
echo "✅ $(du -h build/som-mini-linux.tar.gz | cut -f1)  build/som-mini-linux.tar.gz  ($VERSION)"
