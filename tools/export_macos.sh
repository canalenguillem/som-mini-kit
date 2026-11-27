#!/usr/bin/env bash
# Genera el .app de macOS (universal: Apple Silicon e Intel, firmado "ad hoc") y un .zip listo para repartir.
# Requiere las plantillas de exportación de macOS (macos.zip) de la misma versión de Godot.
# No hay firma de desarrollador de Apple ni notarización (cuestan 99 $/año): los usuarios tienen que dar permiso
# la primera vez (el LEEME y la web lo explican). Exportar desde Linux no permite probarlo: hay que abrirlo en un Mac.
# Uso: ./tools/export_macos.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PKG=build/som-mini-macos
RAW="$PKG/Mini-SO.zip"
rm -rf "$PKG" && mkdir -p "$PKG"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "macOS" "$RAW" 2>&1 | grep -E "ERROR|error" | grep -v "still in use" && { echo "❌ la exportación falló"; exit 1; } || true
[ -f "$RAW" ] || { echo "❌ no se generó $RAW (¿faltan las plantillas de exportación de macOS?)"; exit 1; }

python3 - <<'PY'
import hashlib, json, plistlib, struct, subprocess, sys, time, zipfile
from pathlib import Path

RAW = Path("build/som-mini-macos/Mini-SO.zip")
OUT = Path("build/som-mini-macos.zip")
TOP = "som-mini-macos/"

LEEME = """Mini SO — macOS (Mac con chip Apple o Intel)

Cómo jugar:
  1. Descomprime este zip (doble clic). Se crea la carpeta con Mini SO.app dentro.
     Puedes arrastrar Mini SO.app a la carpeta Aplicaciones.
  2. Ábrelo con doble clic. La primera vez macOS lo bloqueará porque no está firmado por
     un desarrollador de Apple (la firma cuesta 99 $ al año). Para darle permiso:

     macOS 15 (Sequoia) o posterior:
       Doble clic en el juego -> cuando diga que no se puede abrir, pulsa "Hecho".
       Ajustes del Sistema -> Privacidad y seguridad -> baja hasta el aviso sobre Mini SO
       -> "Abrir igualmente" -> confirma con tu contraseña o Touch ID.

     macOS 14 o anterior:
       Clic derecho (o Control + clic) sobre el juego -> Abrir -> Abrir.

     Si dice que "está dañada" o no hay forma de abrirlo, quita la marca de cuarentena
     desde la Terminal (ajusta la ruta):
       xattr -dr com.apple.quarantine "$HOME/Downloads/som-mini-macos/Mini SO.app"

  3. En el menú, "Online" para jugar con tus compañeros (necesitas una cuenta) o
     "Carrera rápida" para jugar solo.

Controles: flechas o WASD, Espacio = nitro, R = reaparecer, Esc = pausa. También mando.

Requisitos: macOS 11 o posterior en Mac con chip Apple; macOS 10.13 o posterior en Mac con Intel.

Tus datos (monedas, coches, récords) se guardan en ~/Library/Application Support/Godot/app_userdata/Mini SO/
"""


def macho_slices(data: bytes):
    """[(arquitectura, firmado?)] de un binario Mach-O (universal o no). Solo lectura de cabeceras."""
    magic = struct.unpack(">I", data[:4])[0]
    names = {0x01000007: "x86_64", 0x0100000C: "arm64"}
    slices = []
    if magic == 0xCAFEBABE:  # universal
        n = struct.unpack(">I", data[4:8])[0]
        for i in range(n):
            cpu, _sub, off, size, _al = struct.unpack(">iiIII", data[8 + 20 * i : 28 + 20 * i])
            slices.append((names.get(cpu, hex(cpu)), data[off : off + size]))
    else:
        cpu = struct.unpack("<i", data[4:8])[0]
        slices.append((names.get(cpu, hex(cpu)), data))
    out = []
    for arch, blob in slices:
        magic64, _cpu, _sub, _ft, ncmds, _size, _fl, _res = struct.unpack("<IiiIIIII", blob[:32])
        assert magic64 == 0xFEEDFACF, "cabecera Mach-O 64 inesperada"
        off, signed = 32, False
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack("<II", blob[off : off + 8])
            if cmd == 0x1D:  # LC_CODE_SIGNATURE
                signed = True
            off += cmdsize
        out.append((arch, signed))
    return out


with zipfile.ZipFile(RAW) as zin:
    names = zin.namelist()
    app = next((n.split("/")[0] for n in names if n.endswith(".app/") or ".app/" in n), None)
    assert app, "el zip exportado no contiene un .app"
    plist = plistlib.loads(zin.read(f"{app}/Contents/Info.plist"))
    exe = plist["CFBundleExecutable"]
    info = macho_slices(zin.read(f"{app}/Contents/MacOS/{exe}"))
    print(f"  {app}: id {plist['CFBundleIdentifier']}, versión {plist.get('CFBundleShortVersionString')}, macOS mínimo {plist.get('LSMinimumSystemVersionByArchitecture')}")
    print("  binario: " + ", ".join(f"{a} ({'firmado ad hoc' if s else 'SIN FIRMA'})" for a, s in info))
    if {a for a, _ in info} != {"x86_64", "arm64"}:
        sys.exit("❌ el binario no es universal (x86_64 + arm64)")
    if not all(s for _, s in info):
        sys.exit("❌ el binario no está firmado: en un Mac con chip Apple no arrancaría")

    OUT.unlink(missing_ok=True)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zout:
        for item in zin.infolist():  # se conservan los permisos (el ejecutable debe seguir siéndolo)
            data = zin.read(item)
            new = zipfile.ZipInfo(TOP + item.filename, date_time=item.date_time)
            new.external_attr = item.external_attr
            new.compress_type = zipfile.ZIP_DEFLATED
            zout.writestr(new, data)
        for name, content in (("LEEME.txt", LEEME), ("LICENCIA-Kenney-CC0.txt", Path("assets/kenney_racing/License.txt").read_text())):
            zout.writestr(TOP + name, content)

data = OUT.read_bytes()
try:
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
except Exception:
    sha = "sin-git"
meta = {"file": OUT.name, "version": f"{time.strftime('%Y-%m-%d')} · {sha}", "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(), "date": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
Path("build/som-mini-macos.json").write_text(json.dumps(meta, ensure_ascii=False) + "\n")
print(f"✅ {len(data) / 1e6:.0f} MB  {OUT}  ({meta['version']})")
PY
