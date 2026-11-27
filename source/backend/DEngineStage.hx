package backend;

import flixel.FlxSprite;

/**
 * D-Engine: dibuja los "props" de un stage V-Slice (los stages Psych usan scripts).
 * Los props con zIndex menor al de los personajes van detras, el resto delante.
 */
class DEngineStage
{
	public static var props:Array<Dynamic> = [];
	public static var charZ:Int = 100;

	static var dancers:Array<Dynamic> = [];
	/** Posiciones de los PIES de bf/dad/gf del stage V-Slice (null si el stage no es V-Slice). */
	public static var feet:Dynamic = null;
	public static function clear():Void { props = []; charZ = 100; dancers = []; feet = null; DEngineShader.clear(); }

	/** V-Slice: esquina = pies - (ancho/2, alto) + offsets del personaje. Se calcula con el tamano REAL del personaje. */
	public static function placeFeet(bf:objects.Character, dad:objects.Character, gf:objects.Character):Void
	{
		if (feet == null) return;
		function put(c:objects.Character, f:Array<Float>):Void
		{
			if (c == null || f == null) return;
			c.x = f[0] - c.width / 2 + c.positionArray[0];
			c.y = f[1] - c.height + c.positionArray[1];
		}
		put(bf, feet.bf);
		put(dad, feet.dad);
		if (gf != null) put(gf, feet.gf);
	}

	public static function beat(curBeat:Int):Void
	{
		for (d in dancers)
		{
			var every:Int = Std.int(Math.max(1, Math.round(d.every)));
			if (curBeat % every != 0) continue;
			var spr:FlxSprite = d.spr;
			if (spr.animation.exists('danceLeft') && spr.animation.exists('danceRight'))
			{
				d.left = !d.left;
				spr.animation.play(d.left ? 'danceLeft' : 'danceRight', true);
			}
			else if (spr.animation.exists('idle')) spr.animation.play('idle', true);
		}
	}

	public static function addProps(state:flixel.FlxState, front:Bool):Void
	{
		if (props == null) return;
		var sorted:Array<Dynamic> = props.copy();
		sorted.sort(function(a:Dynamic, b:Dynamic) return Std.int((a.zIndex != null ? a.zIndex : 0) - (b.zIndex != null ? b.zIndex : 0)));
		for (p in sorted)
		{
			var z:Int = p.zIndex != null ? Std.int(p.zIndex) : 0;
			if ((z > charZ) != front) continue;
			var pos:Array<Float> = p.position != null ? p.position : [0, 0];
			var spr:FlxSprite = new FlxSprite(pos[0], pos[1]);
			var hasAnims:Bool = p.animations != null && (p.animations : Array<Dynamic>).length > 0;
			if (hasAnims)
			{
				spr.frames = Paths.getSparrowAtlas(VSliceConverter.cleanAsset(p.assetPath));
				for (a in (p.animations : Array<Dynamic>))
				{
					var fps:Int = a.frameRate != null ? Std.int(a.frameRate) : 24;
					var loop:Bool = a.looped != null ? a.looped : false;
					if (a.frameIndices != null && (a.frameIndices : Array<Dynamic>).length > 0)
						spr.animation.addByIndices(a.name, a.prefix, a.frameIndices, '', fps, loop);
					else
						spr.animation.addByPrefix(a.name, a.prefix, fps, loop);
				}
				if (p.startingAnimation != null && spr.animation.exists(p.startingAnimation))
					spr.animation.play(p.startingAnimation);
			}
			else spr.loadGraphic(Paths.image(VSliceConverter.cleanAsset(p.assetPath)));

			// escala puede ser numero o [x, y]
			if (p.scale != null)
			{
				if (Std.isOfType(p.scale, Array)) { var sc:Array<Float> = p.scale; spr.scale.set(sc[0], sc[1]); }
				else spr.scale.set(p.scale, p.scale);
				spr.updateHitbox();
			}
			if (p.alpha != null) spr.alpha = p.alpha;
			if (p.angle != null) spr.angle = p.angle;
			if (p.flipX == true) spr.flipX = true;
			if (p.flipY == true) spr.flipY = true;
			if (p.scroll != null) { var s:Array<Float> = p.scroll; spr.scrollFactor.set(s[0], s[1]); }
			spr.antialiasing = ClientPrefs.data.antialiasing && p.isPixel != true;
			if (hasAnims && p.danceEvery != null && p.danceEvery > 0) dancers.push({spr: spr, every: p.danceEvery, left: false});
			state.add(spr);
		}
	}
}
