# Kit para Claude Code — Mini SO (Godot 4.7)

## Cómo usarlo

1. Crea una carpeta vacía para el proyecto (por ejemplo `~/dev/som-mini`) y haz `git init`.
2. Descomprime aquí el contenido del zip. Debe quedar así:
   ```
   CLAUDE.md
   docs/GDD.md  docs/ARCHITECTURE.md  docs/ROADMAP.md
   .claude/skills/godot-verificar/   (SKILL.md, check.sh, load_all.gd)
   .claude/skills/fisica-coche-arcade/SKILL.md
   .claude/skills/crear-pista/SKILL.md
   .claude/skills/ia-rival/SKILL.md
   ```
3. Asegúrate de que `godot` (4.7.x) está en el PATH, o exporta `GODOT=/ruta/al/Godot_v4.7…`.
4. Abre `claude` en esa carpeta y pega el prompt inicial.

## Prompt inicial

```
Lee CLAUDE.md y los tres documentos de docs/. Después empieza el hito M0 del ROADMAP:
crea el esqueleto del proyecto, instala las herramientas de la skill godot-verificar
y deja ./tools/check.sh en verde. Cuando termines, marca M0 en el ROADMAP, cambia
"Hito actual" a M1 y para: no empieces M1 sin que te lo diga.
```

Después, un hito por sesión: *"Haz M1"*, *"Haz M2"*… Tras M1 y M3 juega tú y ajusta los valores antes de continuar.

## Si quieres cambiar algo antes de empezar

- **Nombre del juego**: busca y reemplaza "Mini SO".
- **3D en lugar de 2D**: es un cambio grande. Pídeselo a Claude Code antes de M0 para que reescriba ARCHITECTURE y la skill de física (`VehicleBody3D` o `CharacterBody3D` en el plano).
- **C# en lugar de GDScript**: cambia el Stack en CLAUDE.md. Los snippets de las skills sirven como pseudocódigo.
