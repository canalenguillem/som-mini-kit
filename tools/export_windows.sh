#!/usr/bin/env bash
# Genera el ejecutable de Windows (x86_64) y un .zip listo para repartir.
# Requiere las plantillas de exportación de Windows de la misma versión de Godot.
# Uso: ./tools/export_windows.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PKG=build/som-mini-windows
OUT="$PKG/Mini-SO.exe"
rm -rf "$PKG" && mkdir -p "$PKG"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows" "$OUT" 2>&1 | grep -E "ERROR|error" | grep -v "still in use" && { echo "❌ la exportación falló"; exit 1; } || true
[ -f "$OUT" ] || { echo "❌ no se generó $OUT (¿faltan las plantillas de exportación de Windows?)"; exit 1; }
# Solo debe quedar el .exe (el PCK va dentro)
find "$PKG" -type f ! -name 'Mini-SO.exe' -delete

cp assets/kenney_racing/License.txt "$PKG/LICENCIA-Kenney-CC0.txt"
cat > "$PKG/LEEME.txt" <<'TXT'
Mini SO — Windows (64 bits)

Cómo jugar:
  1. Extrae el .zip: clic derecho -> "Extraer todo..." (no lo ejecutes desde dentro del zip).
  2. Abre la carpeta y haz doble clic en Mini-SO.exe.
  3. En el menú, "Online" para jugar con tus compañeros (necesitas una cuenta) o
     "Carrera rápida" para jugar solo.

Si Windows muestra "Windows protegió su equipo" (SmartScreen):
  Pulsa "Más información" y luego "Ejecutar de todas formas".
  Sale porque el programa no tiene firma digital de pago; es normal en juegos hechos por aficionados.

Controles: flechas o WASD, Espacio = nitro, R = reaparecer, Esc = pausa. También mando.

Requisitos: Windows 10 o 11 (64 bits) y una tarjeta gráfica con OpenGL 3.3. No hace falta instalar nada.

Tus datos (monedas, coches, récords) se guardan en %APPDATA%\Godot\app_userdata\Mini SO\
TXT

python3 - <<'PY'
import hashlib, json, subprocess, time, zipfile
from pathlib import Path

pkg = Path("build/som-mini-windows")
archive = Path("build/som-mini-windows.zip")
archive.unlink(missing_ok=True)
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in sorted(pkg.iterdir()):
        z.write(f, f"som-mini-windows/{f.name}")
data = archive.read_bytes()
try:
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
except Exception:
    sha = "sin-git"
meta = {"file": archive.name, "version": f"{time.strftime('%Y-%m-%d')} · {sha}", "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(), "date": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
Path("build/som-mini-windows.json").write_text(json.dumps(meta, ensure_ascii=False) + "\n")
print(f"✅ {len(data) / 1e6:.0f} MB  {archive}  ({meta['version']})")
PY
