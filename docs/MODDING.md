# Guía de mods de D-Engine

> Estado: borrador escrito a partir del código. Aún no probada en el juego.
> Lo que diga "no soportado" es un límite real; lo que diga "soportado" hay que confirmarlo al compilar.

D-Engine tiene su **propia estructura de mods**. Los mods de Psych y V-Slice **no** se tocan: siguen funcionando con su formato.

---

## 1. Dónde van los mods y los datos

| Qué | Dónde |
|---|---|
| Mods | `mods/<MiMod>/` dentro de la carpeta de datos de la app |
| Android (por defecto) | `Android/data/com.dengine.game/files/mods/` |
| Android (almacenamiento `EXTERNAL`) | `.DEngine/mods/` en la raíz del almacenamiento |
| Cosas que el juego necesita | `.DEngine/files/` (cache, info, guía) |
| Lo que creas en los editores | `.DEngine/saves/` → `charts/`, `events/`, `weeks/`, `characters/` |
| Mods V-Slice para convertir | `.DEngine/saves/converter/<MiMod>/` |

Lo que guardan los editores queda en `saves/`: cópialo a tu mod a mano.

---

## 2. Estructura de un mod D-Engine

```
mods/<MiMod>/
  mod.dengine.json        ← OBLIGATORIO (si falta, no es un mod D-Engine)
  scripts/*.js            ← scripts globales
  events/<Nombre>.js      ← evento (function run(value1, value2))
  events/<Nombre>.json    ← descripción del evento para el editor
  notetypes/<Nombre>.js   ← tipos de nota
  charts/<cancion>/<cancion>-<dificultad>.json
  charts/<cancion>/*.js   ← scripts solo de esa canción
  songs/<cancion>/Inst.ogg y Voices.ogg
  characters/<nombre>.json
  stages/<nombre>.json  y  stages/<nombre>.js
  weeks/<nombre>.json
  shaders/<nombre>/<nombre>.png + .js + .json
  images/  sounds/  music/  videos/  fonts/
```

Reglas de nombres:
- Nombres de canción en **minúsculas y con guiones** (`mi-cancion`), sin espacios ni tildes.
- Dificultades: `-easy`, `-normal`, `-hard`. Para normal también vale `<cancion>.json`.
- Personajes, stages y weeks usan el **formato JSON de Psych**.

### `mod.dengine.json`
```json
{
  "name": "Mi Mod",
  "description": "Qué hace el mod",
  "author": "TuNombre",
  "engine": "D-Engine",
  "engineVersion": "0.1.0"
}
```
Con eso D-Engine crea solo el `pack.json` para que el mod aparezca en el menú de mods.

---

## 3. Scripts `.js`

Se traducen a HScript al cargar. Es **JavaScript sencillo**, no un motor JS completo.

### Callbacks disponibles
`onCreate()`, `onUpdate(elapsed)`, `onBeatHit()`, `onStepHit()`, `goodNoteHit(note)`, `opponentNoteHit(note)`, `noteMiss(note)`, `onSpawnNote(note)`, `onEvent(name, value1, value2)`, `onEndSong()`, y el resto de callbacks HScript de Psych.

### Variables y clases disponibles
`game` (el PlayState), `FlxG`, `Paths`, `Conductor`, `Std`, `Math`, y lo que ya expone el HScript de Psych.

### Soportado
- `let`, `const`, `var` (se tratan como `var`)
- `===` y `!==` (se tratan como `==` y `!=`)
- `console.log(...)` (se trata como `trace`)
- `undefined` (se trata como `null`)
- Funciones flecha simples: `(a, b) => { ... }` y `(a) => a + 1`
- `for (const x of lista)`
- `for (let i = 0; i < n; i++)`
- `if`, `else`, `while`, `switch`, arrays y objetos `{a: 1}`

### No soportado
- Clases (`class`), `import`/`export`, módulos
- Promesas, `async`/`await`, `setTimeout`
- Template strings con backticks
- Desestructuración y operador spread (`...`)
- Bucles `for` con `<=`, `i += 2`, `i--` (usa `while`)
- Métodos JS que no existen en Haxe (`forEach`, etc.): usa `for (x of lista)`
- `this` dentro de funciones sueltas

### Ejemplo
```js
function onCreate() {
  console.log('Hola desde D-Engine');
}

function onBeatHit() {
  if (Conductor.curBeat % 4 == 0) FlxG.camera.zoom += 0.03;
}
```

---

## 4. Eventos

`events/Flash.js`
```js
function run(value1, value2) {
  const dur = Std.parseFloat(value1);
  FlxG.camera.flash(0xFFFFFFFF, dur > 0 ? dur : 0.5);
}
```
`events/Flash.json` (opcional, es la descripción que ve el editor de charts)
```json
{ "description": "Flash de cámara. Value1 = duración en segundos" }
```
En el chart se llama por el nombre del archivo: `"name": "Flash"`.
Si tu script ya define `onEvent`, D-Engine no agrega el puente automático.

---

## 5. Charts (`.json`)

```json
{
  "format": "dengine-chart",
  "song": "Mi Cancion",
  "bpm": 120,
  "speed": 2.0,
  "stage": "stage",
  "noteStyle": "funkin",
  "characters": { "player": "bf", "opponent": "dad", "girlfriend": "gf" },
  "bpmChanges": [ { "t": 0, "bpm": 120 } ],
  "camera": [ { "t": 0, "focus": "opponent" } ],
  "notes": [ { "t": 2000, "lane": 0, "side": "player", "len": 0, "kind": "" } ],
  "events": [ { "t": 3000, "name": "Flash", "a": "0.4", "b": "" } ]
}
```

| Campo | Valores |
|---|---|
| `t` | tiempo en **milisegundos** |
| `lane` | 0 izquierda, 1 abajo, 2 arriba, 3 derecha |
| `side` | `player` u `opponent` |
| `len` | duración del sustain en ms (0 = nota normal) |
| `kind` | tipo de nota (ver abajo) |
| `focus` | `player`, `opponent` o `girlfriend` |
| `noteStyle` | `funkin` o `pixel` |
| `origin` | `vslice` (opcional): en modo Auto usa el layout de flechas V-Slice |
| `audio` | opcional: `{"suffix": "-erect", "playerVocal": "bf", "opponentVocal": "dad"}` |

`"format": "dengine-chart"` es obligatorio. Sin eso el chart se ignora.
La cámara cambia por **sección de 4 beats**, no al milisegundo.

Las dificultades que aparecen en Freeplay se detectan solas según los charts que existan (`easy`, `normal`, `hard`, `erect`, `nightmare` y cualquier otra). Para V-Slice se leen también las variaciones (`<cancion>-chart-erect.json`), con su `Inst-erect` y sus voces.



### Charts en formato Psych (`.json` o `.txt`)
Dentro de `charts/<cancion>/` también se aceptan charts de Psych, con el mismo nombre de siempre
(`<cancion>-<dificultad>.json` o `.txt`). El contenido es el JSON de Psych: `{"song": {...}}` (o el objeto de la canción directamente).
Esto sirve para pegar charts hechos con el editor de Psych sin convertirlos. Si un chart no tiene `"format": "dengine-chart"`, D-Engine lo trata como Psych.

### Tipos de nota (`kind`)

| Escribes | Resultado |
|---|---|
| `alt`, `alt-animation` | Alt Animation |
| `hey` | Hey! |
| `hurt`, `mine` | Hurt Note |
| `gf`, `girlfriend` | GF Sing |
| `noanim`, `no_animation` | No Animation |
| `non_scoreable` | Non Scoreable (sin puntuación) |
| cualquier otro nombre | se deja igual; defínelo en `notetypes/<nombre>.js` |

---

## 6. Shaders

En vez de `.frag`, cada shader es una **carpeta con 3 archivos**:

```
shaders/vhs-wave/vhs-wave.png    ← imagen (textura o máscara)
shaders/vhs-wave/vhs-wave.js     ← script que lo controla
shaders/vhs-wave/vhs-wave.json   ← definición
```

`vhs-wave.json`
```json
{ "effect": "wave", "target": "camGame", "params": { "amplitude": 0.01, "frequency": 20.0, "speed": 2.0 } }
```

### Efectos incluidos

| `effect` | Parámetros |
|---|---|
| `tint` | `r`, `g`, `b` (0 a 1), `amount` |
| `wave` | `amplitude`, `frequency`, `speed` |
| `chroma` | `amount` |
| `mask` | `amount` (usa el `.png` como máscara; otro nombre con `"texture"`) |

`target`: `camGame`, `camHUD`, `camOther` o `all`.

### Funciones en el `.js`
```js
function onCreate() { addShader('vhs-wave'); }          // o addShader('vhs-wave', 'camHUD')
function onUpdate(elapsed) {
  setShaderParam('vhs-wave', 'amplitude', 0.008 + Math.sin(Conductor.songPosition / 1000) * 0.004);
}
// removeShader('vhs-wave');
```

### No soportado
- Escribir GLSL propio (`.frag`): solo los 4 efectos de la tabla
- Aplicar un shader a un solo sprite: solo cámaras
- Más de una textura por shader

---

## 7b. API de scripts de D-Engine (nombres de Psych + ayudantes de V-Slice)

Todos los scripts `.js` (y `.hx`) de D-Engine tienen estas funciones, ya instaladas:

| Grupo | Funciones |
|---|---|
| Propiedades | `getProperty(ruta)`, `setProperty(ruta, valor)`, `getPropertyFromClass(clase, campo)`, `setPropertyFromClass(clase, campo, valor)` |
| Sprites | `makeLuaSprite(tag, imagen, x, y)`, `makeAnimatedLuaSprite(tag, imagen, x, y)`, `addAnimationByPrefix(tag, nombre, prefijo, fps, loop)`, `addAnimationByIndices(tag, nombre, prefijo, "0,1,2", fps, loop)`, `objectPlayAnimation(tag, nombre, forzar)`, `addLuaSprite(tag, enFrente)`, `removeLuaSprite(tag)`, `luaSpriteExists(tag)`, `setObjectCamera(tag, camara)`, `scaleObject(tag, x, y)`, `setScrollFactor(tag, x, y)`, `screenCenter(tag, eje)` |
| Tweens | `doTweenX/Y/Angle/Alpha(tag, objeto, valor, duracion, ease)`, `doTweenZoom(tag, camara, valor, duracion, ease)`, `doTweenColor(tag, objeto, color, duracion, ease)`, `cancelTween(tag)` → callback `onTweenCompleted(tag)` |
| Timers | `runTimer(tag, tiempo, repeticiones)`, `cancelTimer(tag)` → callback `onTimerCompleted(tag, loops, loopsLeft)` |
| Cámara | `cameraFlash(cam, color, dur)`, `cameraShake(cam, intensidad, dur)`, `cameraFade(cam, color, dur)`, `cameraSetTarget('boyfriend' o 'dad')` |
| Juego | `triggerEvent(nombre, v1, v2)`, `playSound(nombre, volumen)`, `characterPlayAnim(personaje, anim, forzar)`, `addScore`, `addMisses`, `addHits`, `addHealth`, `setHealth`, `getHealth`, `getScore` |
| Estilo V-Slice | `getBoyfriend()`, `getDad()`, `getOpponent()`, `getGirlfriend()` |
| Útiles | `getSongPosition()`, `getRandomInt(min, max)`, `getRandomFloat(min, max)`, `stringStartsWith`, `stringEndsWith`, `stringSplit`, `stringTrim` |
| Shaders | `addShader`, `setShaderParam`, `removeShader` |

Cámaras: `camGame`, `camHUD`, `camOther` (también `game`, `hud`, `other`).
Callbacks: los de Psych (`onCreate`, `onCreatePost`, `onUpdate(elapsed)`, `onBeatHit`, `onStepHit`, `onSectionHit`, `goodNoteHit(note)`, `opponentNoteHit(note)`, `noteMiss(note)`, `onSpawnNote(note)`, `onEvent`, `onEndSong`...) y, dentro de un `.js`, también la forma de V-Slice: `onNoteHit(event)`, `onUpdate(event)`, `onBeatHit(event)`... con `event.note`, `event.elapsed`, `event.beat`, `event.step`.
Además siguen disponibles las clases de Psych: `FlxG`, `FlxSprite`, `FlxTween`, `FlxTimer`, `FlxEase`, `Paths`, `Conductor`, `PlayState`, `game`...

Un mod "definitivo" de D-Engine se escribe solo con `.js` y estas funciones; mira `mods/D-Engine-Example/`.

---

## 7. Qué se acepta y qué no

| Cosa | ¿Se acepta? |
|---|---|
| Scripts `.js` en la estructura D-Engine | Sí |
| Eventos `.js` | Sí |
| Charts `dengine-chart` | Sí |
| Shaders carpeta (png + js + json) | Sí |
| Personajes, stages y weeks en JSON de Psych | Sí |
| Mods de Psych | Sí, intactos |
| Mods de V-Slice | Se convierten a la estructura D-Engine con el convertidor (`saves/converter`) |
| Scripts `.lua` / `.hx` de Psych dentro de un mod D-Engine | Siguen cargando (la base es Psych), pero la estructura oficial es `.js` |
| Charts en formato Psych (`.json` / `.txt`) en `charts/` | Sí |
| Scripts `.hxc` de V-Slice | Solo vía mods V-Slice o convertidor; los complejos pueden fallar |
| Shaders `.frag` | No |
| Chart sin `"format": "dengine-chart"` | No |
| Mod D-Engine sin `mod.dengine.json` | No se reconoce como D-Engine |

---

## 8. Convertir un mod de V-Slice a D-Engine

1. Copia la carpeta completa del mod a `.DEngine/saves/converter/<MiMod>/`.
2. Abre D-Engine. Se crea `mods/<MiMod>-dengine/` con la estructura de D-Engine.
3. Revisa `saves/converter/<MiMod>.log.txt`. Al llegar al menú principal te avisa que el mod se convirtió, y ya aparece activado en el menú de Mods.

Qué se convierte:
- **Charts** → `charts/<cancion>/<cancion>-<dificultad>.json` (formato `dengine-chart`), incluidas las variaciones **Erect** y **Nightmare** con su audio alterno.
- **Personajes, stages y weeks** → JSON. Los stages guardan los "pies" exactos de V-Slice para colocar a los personajes igual.
- Personajes convertidos llevan `"vslice": true` y `"globalOffsets"`: D-Engine convierte al cargar los offsets de animación de V-Slice (`-(offset_anim - offset_global) × escala`) al sistema de Psych, para que las poses queden igual.
- **Props de los stages** → `stages/<nombre>.js`.
- **Scripts `.hxc`** → `scripts/*.js`; los **note kinds** → `notetypes/<kind>.js`.
- **Assets** (images, sounds, music, songs, videos, fonts) se copian.
- Los charts convertidos llevan `"origin": "vslice"`: en modo Auto usan el layout de flechas V-Slice.

Qué no se convierte (queda en el log): eventos V-Slice sin equivalente (solo se pasan `FocusCamera` y `PlayAnimation`) y shaders `.frag`.
El mod original no se modifica y la conversión se hace una sola vez por mod.

Los **mods de Psych** también se pueden poner en `.DEngine/saves/converter/<MiMod>/`: se copian completos a `mods/<MiMod>-dengine/` con `mod.dengine.json`, y sus charts se copian a `charts/<cancion>/` en formato Psych. Los scripts `.lua` y `.hx` de Psych se conservan y siguen funcionando.

El convertidor busca scripts en **todo** el mod (`.hxc`, `.hx`, `.hscript`, `.hxs`), los pasa a `.js` y crea siempre las carpetas `scripts/`, `notetypes/`, `events/`, `charts/`, `characters/`, `stages/`, `weeks/` y `shaders/`, aunque estén vacías. En mods de Psych, los `.hx` de `scripts/`, `stages/` y `custom_events/` pasan a `.js`; los `.lua` se conservan.

El convertidor trabaja archivo por archivo: si uno falla, el resto continúa y el error queda en `saves/converter/<MiMod>.log.txt`. El informe avisa de personajes o stages que faltan (por ejemplo, personajes del juego base de V-Slice que D-Engine no trae). Si el mod V-Slice no trae `data/levels`, se crea una semana automática con todas sus canciones para que aparezcan en Freeplay.


---

## 9. Opciones del jugador (tecla/botón **C** en Opciones)

- **Engine Mode:** Auto, Psych o V-Slice.
- **Hitbox Scheme:** Four Lanes, Double Thumb Square, Double Thumb DPad, Arrows.
- **Strum Layout:** Auto, Psych o V-Slice. V-Slice = como en V-Slice móvil: **una sola fila de flechas abajo**, centrada y más separada, con downscroll y el rival oculto. El hitbox "Arrows" se alinea con esa fila.
- **Freeplay Style:** Psych o V-Slice (DJ BF, cápsulas, dificultades).

- **Flechas V-Slice táctiles:** con Strum Layout = V-Slice (o un mod V-Slice en Auto) el hitbox de colores desaparece: tocas directamente las flechas de abajo. Las zonas de toque son invisibles, están pegadas y cubren cada flecha hasta el borde inferior de la pantalla.
- **Menús táctiles:** en el menú principal, Freeplay, Opciones y Pausa puedes deslizar el dedo arriba/abajo para moverte, tocar una fila para seleccionarla y tocarla otra vez para aceptarla. En Freeplay, deslizar a los lados cambia la dificultad; en las opciones cambia el valor. Los botones en pantalla siguen funcionando igual.

Al empezar una canción se muestra 4 segundos el modo, las flechas y el hitbox activos.

---

## 10. Ayuda dentro del juego

En el menú principal, debajo de Options, está **Ayuda con Mods**: muestra esta guía y se puede bajar y subir.

---

## 11. Créditos

Aquí por siempre D-engine By DYLAN-FNF-PORTS-MOBILE, derechos reservados a FunkiCrew + ShadowMario
