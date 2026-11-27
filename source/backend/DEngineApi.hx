package backend;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import psychlua.LuaUtils;
import psychlua.ModchartSprite;
import states.PlayState;

/**
 * D-Engine: API propia para scripts .js / .hx. Reune funciones con los nombres de Psych Engine (Lua)
 * y ayudantes estilo V-Slice, para que los mods se puedan escribir y convertir con facilidad.
 * Se instala en cada script con DEngineApi.install(set).
 *
 *  Propiedades : getProperty, setProperty, getPropertyFromClass, setPropertyFromClass
 *  Sprites     : makeLuaSprite, makeAnimatedLuaSprite, addAnimationByPrefix, addAnimationByIndices,
 *                objectPlayAnimation, addLuaSprite, removeLuaSprite, luaSpriteExists, setObjectCamera,
 *                scaleObject, setScrollFactor, screenCenter
 *  Tweens      : doTweenX/Y/Angle/Alpha/Zoom/Color, cancelTween  (callback onTweenCompleted)
 *  Timers      : runTimer, cancelTimer                           (callback onTimerCompleted)
 *  Camara      : cameraFlash, cameraShake, cameraFade, cameraSetTarget
 *  Juego       : triggerEvent, playSound, characterPlayAnim, addScore, addMisses, addHits, addHealth, ...
 *  V-Slice     : getBoyfriend, getOpponent, getDad, getGirlfriend
 *  Utiles      : getRandomInt, getRandomFloat, getSongPosition, stringStartsWith, stringEndsWith, stringSplit, stringTrim
 */
class DEngineApi
{
	static inline function pl():PlayState return PlayState.instance;

	static function lookup(tag:String):Dynamic
	{
		var p:PlayState = pl();
		if (p.modchartSprites.exists(tag)) return p.modchartSprites.get(tag);
		if (p.variables.exists(tag)) return p.variables.get(tag);
		return null;
	}

	static function getObj(tag:String):Dynamic
	{
		var o:Dynamic = lookup(tag);
		if (o != null) return o;
		return LuaUtils.getVarInArray(pl(), tag);
	}

	static function color(s:Dynamic):Int
	{
		if (Std.isOfType(s, Int)) return s;
		return CoolUtil.colorFromString(Std.string(s));
	}

	// ---------------- propiedades ----------------
	public static function getProperty(path:String):Dynamic
	{
		var parts:Array<String> = path.split('.');
		var o:Dynamic = getObj(parts[0]);
		for (i in 1...parts.length) o = LuaUtils.getVarInArray(o, parts[i]);
		return o;
	}

	public static function setProperty(path:String, value:Dynamic):Void
	{
		var parts:Array<String> = path.split('.');
		if (parts.length == 1)
		{
			if (pl().variables.exists(parts[0])) pl().variables.set(parts[0], value);
			else LuaUtils.setVarInArray(pl(), parts[0], value);
			return;
		}
		var o:Dynamic = getObj(parts[0]);
		for (i in 1...parts.length - 1) o = LuaUtils.getVarInArray(o, parts[i]);
		LuaUtils.setVarInArray(o, parts[parts.length - 1], value);
	}

	public static function getPropertyFromClass(cls:String, field:String):Dynamic
		return LuaUtils.getVarInArray(Type.resolveClass(cls), field);

	public static function setPropertyFromClass(cls:String, field:String, value:Dynamic):Void
		LuaUtils.setVarInArray(Type.resolveClass(cls), field, value);

	// ---------------- sprites ----------------
	public static function makeLuaSprite(tag:String, ?image:String, ?x:Float = 0, ?y:Float = 0):Void
	{
		removeLuaSprite(tag);
		var spr:ModchartSprite = new ModchartSprite(x, y);
		if (image != null && image.length > 0) spr.loadGraphic(Paths.image(image));
		spr.antialiasing = ClientPrefs.data.antialiasing;
		pl().modchartSprites.set(tag, spr);
	}

	public static function makeAnimatedLuaSprite(tag:String, image:String, ?x:Float = 0, ?y:Float = 0):Void
	{
		removeLuaSprite(tag);
		var spr:ModchartSprite = new ModchartSprite(x, y);
		spr.frames = Paths.getSparrowAtlas(image);
		spr.antialiasing = ClientPrefs.data.antialiasing;
		pl().modchartSprites.set(tag, spr);
	}

	public static function addAnimationByPrefix(tag:String, name:String, prefix:String, ?fps:Int = 24, ?loop:Bool = true):Void
	{
		var s:FlxSprite = lookup(tag);
		if (s == null) return;
		s.animation.addByPrefix(name, prefix, fps, loop);
		if (s.animation.curAnim == null) s.animation.play(name, true);
	}

	public static function addAnimationByIndices(tag:String, name:String, prefix:String, indices:Dynamic, ?fps:Int = 24, ?loop:Bool = false):Void
	{
		var s:FlxSprite = lookup(tag);
		if (s == null) return;
		var list:Array<Int> = [];
		if (Std.isOfType(indices, String)) { for (v in Std.string(indices).split(',')) { var n:Null<Int> = Std.parseInt(StringTools.trim(v)); if (n != null) list.push(n); } }
		else for (v in (indices : Array<Dynamic>)) list.push(Std.int(v));
		s.animation.addByIndices(name, prefix, list, '', fps, loop);
		if (s.animation.curAnim == null) s.animation.play(name, true);
	}

	public static function objectPlayAnimation(tag:String, name:String, ?forced:Bool = false, ?startFrame:Int = 0):Void
	{
		var s:FlxSprite = getObj(tag);
		if (s != null && s.animation != null) s.animation.play(name, forced, false, startFrame);
	}

	public static function addLuaSprite(tag:String, ?front:Bool = false):Void
	{
		var s:FlxSprite = lookup(tag);
		if (s == null) return;
		if (front) pl().add(s); else pl().addBehindGF(s);
	}

	public static function removeLuaSprite(tag:String, ?destroy:Bool = true):Void
	{
		var s:FlxSprite = pl().modchartSprites.get(tag);
		if (s == null) return;
		pl().remove(s);
		if (destroy) s.destroy();
		pl().modchartSprites.remove(tag);
	}

	public static function luaSpriteExists(tag:String):Bool return pl().modchartSprites.exists(tag);

	public static function setObjectCamera(tag:String, ?camera:String = 'game'):Void
	{
		var o:Dynamic = getObj(tag);
		if (o != null) o.cameras = [LuaUtils.cameraFromString(camera)];
	}

	public static function scaleObject(tag:String, x:Float, y:Float, ?updateHitbox:Bool = true):Void
	{
		var s:FlxSprite = getObj(tag);
		if (s == null) return;
		s.scale.set(x, y);
		if (updateHitbox) s.updateHitbox();
	}

	public static function setScrollFactor(tag:String, x:Float, y:Float):Void
	{
		var s:FlxSprite = getObj(tag);
		if (s != null) s.scrollFactor.set(x, y);
	}

	public static function screenCenter(tag:String, ?axis:String = 'xy'):Void
	{
		var s:FlxSprite = getObj(tag);
		if (s == null) return;
		axis = axis.toLowerCase();
		if (axis == 'x') s.screenCenter(flixel.util.FlxAxes.X);
		else if (axis == 'y') s.screenCenter(flixel.util.FlxAxes.Y);
		else s.screenCenter();
	}

	// ---------------- tweens ----------------
	static function tween(tag:String, target:Dynamic, props:Dynamic, dur:Float, ease:String, vars:String):Void
	{
		if (target == null) return;
		cancelTween(tag);
		var t:FlxTween = FlxTween.tween(target, props, dur, {
			ease: LuaUtils.getTweenEaseByString(ease),
			onComplete: function(_) { pl().modchartTweens.remove(tag); pl().callOnScripts('onTweenCompleted', [tag, vars]); }
		});
		pl().modchartTweens.set(tag, t);
	}

	public static function doTweenX(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear'):Void tween(tag, getObj(vars), {x: value}, duration, ease, vars);
	public static function doTweenY(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear'):Void tween(tag, getObj(vars), {y: value}, duration, ease, vars);
	public static function doTweenAngle(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear'):Void tween(tag, getObj(vars), {angle: value}, duration, ease, vars);
	public static function doTweenAlpha(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear'):Void tween(tag, getObj(vars), {alpha: value}, duration, ease, vars);
	public static function doTweenZoom(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear'):Void tween(tag, LuaUtils.cameraFromString(camera), {zoom: value}, duration, ease, camera);

	public static function doTweenColor(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear'):Void
	{
		var o:FlxSprite = getObj(vars);
		if (o == null) return;
		cancelTween(tag);
		var t:FlxTween = FlxTween.color(o, duration, o.color, color(targetColor), {
			ease: LuaUtils.getTweenEaseByString(ease),
			onComplete: function(_) { pl().modchartTweens.remove(tag); pl().callOnScripts('onTweenCompleted', [tag, vars]); }
		});
		pl().modchartTweens.set(tag, t);
	}

	public static function cancelTween(tag:String):Void
	{
		var t:FlxTween = pl().modchartTweens.get(tag);
		if (t != null) { t.cancel(); t.destroy(); pl().modchartTweens.remove(tag); }
	}

	// ---------------- timers ----------------
	public static function runTimer(tag:String, ?time:Float = 1, ?loops:Int = 1):Void
	{
		cancelTimer(tag);
		pl().modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer)
		{
			if (tmr.finished) pl().modchartTimers.remove(tag);
			pl().callOnScripts('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
		}, loops));
	}

	public static function cancelTimer(tag:String):Void
	{
		var t:FlxTimer = pl().modchartTimers.get(tag);
		if (t != null) { t.cancel(); t.destroy(); pl().modchartTimers.remove(tag); }
	}

	// ---------------- camara / sonido / eventos ----------------
	public static function cameraFlash(camera:String, ?col:String = 'WHITE', ?duration:Float = 1, ?force:Bool = false):Void
		LuaUtils.cameraFromString(camera).flash(color(col), duration, null, force);

	public static function cameraShake(camera:String, ?intensity:Float = 0.01, ?duration:Float = 0.5):Void
		LuaUtils.cameraFromString(camera).shake(intensity, duration);

	public static function cameraFade(camera:String, ?col:String = 'BLACK', ?duration:Float = 1, ?force:Bool = false):Void
		LuaUtils.cameraFromString(camera).fade(color(col), duration, false, null, force);

	public static function cameraSetTarget(target:String):Void
		pl().moveCamera(target != 'boyfriend' && target != 'bf' && target != 'player');

	public static function triggerEvent(name:String, ?v1:Dynamic = '', ?v2:Dynamic = ''):Void
		pl().triggerEvent(name, Std.string(v1), Std.string(v2), Conductor.songPosition);

	public static function playSound(name:String, ?volume:Float = 1):Void
		FlxG.sound.play(Paths.sound(name), volume);

	// ---------------- personajes / puntuacion ----------------
	public static function getBoyfriend():Dynamic return pl().boyfriend;
	public static function getDad():Dynamic return pl().dad;
	public static function getOpponent():Dynamic return pl().dad;
	public static function getGirlfriend():Dynamic return pl().gf;

	public static function characterPlayAnim(character:String, anim:String, ?forced:Bool = false):Void
	{
		var c:objects.Character = switch (character.toLowerCase())
		{
			case 'dad' | 'opponent': pl().dad;
			case 'gf' | 'girlfriend': pl().gf;
			default: pl().boyfriend;
		};
		if (c == null || !c.animOffsets.exists(anim)) return;
		c.playAnim(anim, forced);
		c.specialAnim = true;
		c.holdTimer = 0;
	}

	public static function addScore(v:Int = 0):Void { pl().songScore += v; pl().RecalculateRating(); }
	public static function addMisses(v:Int = 0):Void { pl().songMisses += v; pl().RecalculateRating(); }
	public static function addHits(v:Int = 0):Void { pl().songHits += v; pl().RecalculateRating(); }
	public static function addHealth(v:Float = 0):Void pl().health += v;
	public static function setHealth(v:Float = 0):Void pl().health = v;
	public static function getHealth():Float return pl().health;
	public static function getScore():Int return pl().songScore;

	// ---------------- utiles ----------------
	public static function getSongPosition():Float return Conductor.songPosition;
	public static function getRandomInt(min:Int, ?max:Int = 1):Int return FlxG.random.int(min, max);
	public static function getRandomFloat(min:Float, ?max:Float = 1):Float return FlxG.random.float(min, max);
	public static function stringStartsWith(s:String, p:String):Bool return StringTools.startsWith(s, p);
	public static function stringEndsWith(s:String, p:String):Bool return StringTools.endsWith(s, p);
	public static function stringSplit(s:String, sep:String):Array<String> return s.split(sep);
	public static function stringTrim(s:String):String return StringTools.trim(s);

	/** Registra todas las funciones en un script. */
	public static function install(set:String->Dynamic->Void):Void
	{
		set('getProperty', getProperty); set('setProperty', setProperty);
		set('getPropertyFromClass', getPropertyFromClass); set('setPropertyFromClass', setPropertyFromClass);
		set('makeLuaSprite', makeLuaSprite); set('makeAnimatedLuaSprite', makeAnimatedLuaSprite);
		set('addAnimationByPrefix', addAnimationByPrefix); set('addAnimationByIndices', addAnimationByIndices);
		set('objectPlayAnimation', objectPlayAnimation); set('addLuaSprite', addLuaSprite);
		set('removeLuaSprite', removeLuaSprite); set('luaSpriteExists', luaSpriteExists);
		set('setObjectCamera', setObjectCamera); set('scaleObject', scaleObject);
		set('setScrollFactor', setScrollFactor); set('screenCenter', screenCenter);
		set('doTweenX', doTweenX); set('doTweenY', doTweenY); set('doTweenAngle', doTweenAngle);
		set('doTweenAlpha', doTweenAlpha); set('doTweenZoom', doTweenZoom); set('doTweenColor', doTweenColor);
		set('cancelTween', cancelTween); set('runTimer', runTimer); set('cancelTimer', cancelTimer);
		set('cameraFlash', cameraFlash); set('cameraShake', cameraShake); set('cameraFade', cameraFade);
		set('cameraSetTarget', cameraSetTarget); set('triggerEvent', triggerEvent); set('playSound', playSound);
		set('getBoyfriend', getBoyfriend); set('getDad', getDad); set('getOpponent', getOpponent); set('getGirlfriend', getGirlfriend);
		set('characterPlayAnim', characterPlayAnim);
		set('addScore', addScore); set('addMisses', addMisses); set('addHits', addHits);
		set('addHealth', addHealth); set('setHealth', setHealth); set('getHealth', getHealth); set('getScore', getScore);
		set('getSongPosition', getSongPosition); set('getRandomInt', getRandomInt); set('getRandomFloat', getRandomFloat);
		set('stringStartsWith', stringStartsWith); set('stringEndsWith', stringEndsWith);
		set('stringSplit', stringSplit); set('stringTrim', stringTrim);
	}
}
