#!/usr/bin/env bash
# Verificación headless del proyecto Godot. Uso: ./tools/check.sh
set -uo pipefail

GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

echo "→ Importando recursos…"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "→ Cargando e instanciando escenas y recursos…"
"$GODOT" --headless --path . -s res://tools/load_all.gd >"$LOG" 2>&1
LOAD_EXIT=$?

if grep -E "Parse Error|SCRIPT ERROR|ERROR:|Failed to load|FAIL" "$LOG"; then
  echo "❌ Errores al cargar el proyecto (ver arriba)"
  exit 1
fi
if [ "$LOAD_EXIT" -ne 0 ]; then
  cat "$LOG"
  echo "❌ load_all.gd terminó con código $LOAD_EXIT"
  exit 1
fi
tail -n 1 "$LOG"

if [ -d addons/gut ] && [ -d tests ]; then
  echo "→ Ejecutando tests GUT…"
  if ! "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit; then
    echo "❌ Tests fallidos"
    exit 1
  fi
else
  echo "⚠ GUT o tests/ no encontrados: tests omitidos"
fi

echo "✅ Proyecto OK"
