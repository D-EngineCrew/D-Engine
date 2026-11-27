// Script global (.js) con la API de D-Engine (nombres de Psych + ayudantes de V-Slice)
function onCreate() {
  console.log('Hola desde un script .js de D-Engine');
}

function onCreatePost() {
  // Texto de prueba con un sprite creado desde codigo (sin assets): un cuadro semitransparente
  makeLuaSprite('cuadro', '', 20, 20);
  getProperty('cuadro').makeGraphic(120, 40, 0x88FF8A00);
  setObjectCamera('cuadro', 'hud');
  addLuaSprite('cuadro', true);
}

function onBeatHit() {
  if (Conductor.curBeat % 4 == 0) {
    doTweenZoom('zoomBeat', 'camGame', 1.05, 0.2, 'quadOut');
    runTimer('volver', 0.25, 1);
  }
}

function onTimerCompleted(tag, loops, loopsLeft) {
  if (tag == 'volver') doTweenZoom('zoomBack', 'camGame', 0.9, 0.4, 'quadOut');
}

function goodNoteHit(note) {
  addScore(5);
}
