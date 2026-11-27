// Evento D-Engine: se ejecuta con run(value1, value2)
function run(value1, value2) {
  const dur = Std.parseFloat(value1);
  FlxG.camera.flash(0xFFFFFFFF, dur > 0 ? dur : 0.5);
}
