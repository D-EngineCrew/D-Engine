# D-Engine (D-EngineCrew)
Base: Psych Engine 0.7.3 (movil, Lua/HScript, hitbox) + compatibilidad V-Slice 0.8.7.

## Que incluye
- `source/backend/VSliceConverter.hx`: lee charts V-Slice (`-chart.json` + `-metadata.json`) y los convierte a Psych (notas, sustains, BPM, camara, velocidad).
- `source/backend/DEngineLayout.hx` + opcion **Strum Layout** (Opciones moviles): Auto / Psych / V-Slice. Hitbox siempre activo.
- Personajes V-Slice (`data/characters/*.json`) -> formato Psych (animaciones, offsets, camara, iconos).
- Stages V-Slice (`data/stages/*.json`): zoom, posiciones y camara de personajes, y props dibujados por `DEngineStage.hx`.
- Niveles V-Slice (`data/levels/*.json`) aparecen como semanas en Story/Freeplay.
- `vslice-source/`: fuente completa de V-Slice 0.8.7 como referencia para seguir portando (personajes, stages, scripts Polymod).

- Props V-Slice con `danceEvery` (bailan al ritmo, danceLeft/danceRight o idle).
- Personajes MultiSparrow (varios atlas) y Animate Atlas (carpeta con Animation.json).
- Scripts V-Slice `.hxc` traducidos al vuelo a HScript de Psych (`DEngineScripts.hx`; cache en `dengine_cache/`).
- Freeplay estilo V-Slice (opcion **Freeplay Style**: panel lateral + lista diagonal).
- Mods: `pack.json` <-> `_polymod_meta.json` se generan en ambos sentidos (`DEngineMods.hx`).

- **Engine Mode** (`DEngineMode.hx`): detecta si cada mod/cancion es Psych o V-Slice y activa su modo (posiciones, estilo de notas, layout). Se puede forzar en Opciones > C.
- Compatibilidad de charts: note kinds V-Slice -> noteTypes Psych (Alt Animation, Hey!, Hurt Note, GF Sing, No Animation; el resto se deja para custom_notetypes) y noteStyle `pixel` -> skin pixel.
- Controles V-Slice (tecla/boton **C** en Opciones): Hitbox Scheme (Four Lanes, Double Thumb Square, Double Thumb DPad, Arrows, tomados de `FunkinHitbox`), Strum Layout, Freeplay Style, Engine Mode.
- Freeplay V-Slice: DJ BF, capsulas, chips de dificultad. Optimizado: pool fijo de 10 capsulas con 1 grafico compartido, solo se dibuja lo visible, sin recalcular cuando la lista esta quieta.

## Estructura propia de mods D-Engine
Ver `mods/D-Engine-Example/` y `source/backend/DEngineInfo.hx` (guia completa en `.DEngine/files/ESTRUCTURA_DE_MODS.txt`).
- `mod.dengine.json` identifica un mod D-Engine; los mods de Psych/V-Slice NO se tocan.
- Scripts y eventos en `.js` (se traducen a HScript), charts en `.json` (`format: dengine-chart`).
- Shaders: carpeta con `<n>.png` + `<n>.js` + `<n>.json` (efectos: tint, wave, chroma, mask).
- `.DEngine/files` (cache, info) y `.DEngine/saves` (charts, events, weeks, characters creados en el editor).

## Convertidor V-Slice -> D-Engine
Pon un mod V-Slice (carpeta completa) en `.DEngine/saves/converter/<MiMod>/`. Al abrir D-Engine se crea `mods/<MiMod>-dengine/` con la estructura propia de D-Engine (charts dengine-chart con Erect/Nightmare, personajes/stages/weeks JSON, props .js, scripts y note kinds .js, assets). Log en `saves/converter/<MiMod>.log.txt`. Eventos sin equivalente y shaders .frag no se convierten.

## Note kinds
V-Slice -> Psych: noanim -> No Animation, non_scoreable -> Non Scoreable, alt -> Alt Animation, hurt -> Hurt Note, etc. Los scripts `class X extends NoteKind` se traducen a scripts Psych (animSuffix, noAnimation, goodNoteHit/noteMiss solo para ese noteType).

## Ayuda con Mods (menu principal)
Opcion nueva debajo de Options (`states/HelpModsState.hx`): animacion con el icono de la app + frase "Disfruta tu vida, Juegas más." (glitch y arcoiris), y despues la guia `assets/shared/data/MODDING.md` con scroll arriba/abajo (arrastrar, botones o rueda). Toca la pantalla durante la animacion para saltarla; B regresa al menu.

## Layout V-Slice movil
Strum Layout = V-Slice: una sola fila de flechas abajo (separacion ~193 px en 1280), downscroll forzado y rival oculto (se restauran al salir de la cancion). Hitbox Arrows alineado con las flechas. Diferencia con V-Slice: el rival no se muestra en mini arriba a la izquierda.

## Dificultades
Freeplay detecta las dificultades reales de cada cancion (Psych, V-Slice y D-Engine) y agrega Erect, Nightmare y las que existan (`DEngineDifficulty.hx`). Variaciones V-Slice (`-chart-erect.json`) con su Inst/Voices alterno. El convertidor offline (saves/converter) aun no convierte las variaciones erect.

## Posiciones de personajes V-Slice
En stages V-Slice cada personaje se coloca por los pies: esquina = pies - (ancho/2, alto) + offsets, usando el tamano real del sprite (`DEngineStage.placeFeet`), igual que `BaseCharacter.characterOrigin` de V-Slice.

## Tactil
- Flechas V-Slice: hitbox invisible pegada a cada flecha (se toca la flecha). `Hitbox.hx`.
- Menus tactiles (`DEngineTouch.hx`): deslizar, tocar para seleccionar y volver a tocar para aceptar. Main menu, Freeplay (deslizar lateral = dificultad), Opciones, Pausa y Ayuda con Mods. Story, Creditos y menu de Mods aun no.

## Poses de personajes V-Slice
V-Slice dibuja con -(offset_anim - offset_global) * escala; Psych con offset directo. Los personajes convertidos llevan `vslice: true` + `globalOffsets` y `Character.hx` hace la conversion al cargar (incluye el centrado de updateHitbox cuando la escala != 1).

## Scripts, charts y convertidor (ultima version)
- `DEngineApi.hx`: funciones con nombres de Psych (makeLuaSprite, doTweenX, runTimer, cameraFlash, triggerEvent...) y ayudantes de V-Slice (getBoyfriend...) para scripts .js/.hx.
- Charts Psych (.json/.txt) aceptados en `charts/<cancion>/`.
- Convertidor: V-Slice y Psych, error por archivo, informe de personajes/stages faltantes, week automatica.

## Scripts en el convertidor
Busqueda recursiva de scripts (.hxc/.hx/.hscript/.hxs) en todo el mod, clasificados por ruta (charts/<cancion>/, scripts/stage-, scripts/char-, notetypes/, scripts/). Siempre crea las carpetas base. Mods Psych: .hx -> .js en scripts/, stages/ y custom_events/ -> events/; .lua se conserva.

## Limites conocidos
Los .js son JavaScript sencillo traducido a HScript. Los scripts .hxc complejos pueden fallar. Double Thumb Triangle no esta. La fuente del juego puede no dibujar algunos acentos. Codigo sin compilar: corregir errores de CI.
