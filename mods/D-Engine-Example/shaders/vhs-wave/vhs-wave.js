// Controla el shader vhs-wave (definido en vhs-wave.json)
function onCreate() {
  addShader('vhs-wave');
}
function onUpdate(elapsed) {
  setShaderParam('vhs-wave', 'amplitude', 0.008 + Math.sin(Conductor.songPosition / 1000) * 0.004);
}
