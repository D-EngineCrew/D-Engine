-- Script Lua (Psych) de ejemplo para D-Engine
function onCreate()
  debugPrint('ExampleMod: onCreate desde Lua')
end
function onBeatHit()
  if curBeat % 32 == 0 and curBeat > 0 then setHealth(getHealth() + 0.05) end
end
