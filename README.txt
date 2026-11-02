D-Engine (HTML/JS). Abre title.html con un servidor local (python -m http.server) o GitHub Pages.
title (pantalla de título) -> index (menú principal V-Slice) -> story | freeplay | options | credits | mods
game.html = PlayState (iconos de vida, pausa, game over, resultados)
engine/: formats.js (personajes/stages/semanas V-Slice, Psych, Codename) · scripts.js (hx/hxc/hscript/lua/js) · scene.js (stage+personajes) · core.js
base/: semanas, personajes y stages del source de Psych y Codename (base.json + raw/). Sin música ni imágenes del juego.
Mods: MOD_FORMAT.txt y mods/ExampleMod/. La versión de un mod no importa.
