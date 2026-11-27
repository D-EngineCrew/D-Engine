package backend;

import objects.Alphabet;
import states.PlayState;

/**
 * D-Engine: posiciones de las flechas (strums) segun el "Strum Layout".
 *  - Auto    : usa el diseno nativo del formato del chart (Psych o V-Slice)
 *  - Psych   : flechas donde las pone Psych (aunque el mod sea V-Slice)
 *  - V-Slice : flechas donde las pone V-Slice (aunque el mod sea Psych)
 * El hitbox movil es el mismo en todos los casos.
 */
class DEngineLayout
{
	public static function activeLayout():String
	{
		var l:String = ClientPrefs.data.strumLayout;
		if (l == 'Psych' || l == 'V-Slice') return l;
		return DEngineMode.isVSlice() ? 'V-Slice' : 'Psych';
	}

	// StrumNote suma +50 y +(FlxG.width/2)*player despues, por eso X base igual para ambos bandos.
	// V-Slice: oponente x = 48 - 28.6 ~= 19, jugador x = width/2 + 48 - 28.6 ~= 659  ->  base = -31
	public static function strumLineX():Float
	{
		if (activeLayout() == 'V-Slice') return -31;
		return ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X;
	}

	public static function strumLineY():Float
	{
		var down:Bool = ClientPrefs.data.downScroll;
		if (activeLayout() == 'V-Slice') return down ? (FlxG.height - 128) : 24;
		return down ? (FlxG.height - 150) : 50;
	}

	public static function isVSliceMod(modFolder:String):Bool
	{
		#if sys
		return sys.FileSystem.exists('mods/' + modFolder + '/_polymod_meta.json');
		#else
		return false;
		#end
	}

	// ---------- Freeplay estilo V-Slice (DJ BF + capsulas + dificultades) ----------
	// Optimizado: pool fijo de capsulas (1 grafico compartido), solo se dibujan las visibles,
	// los chips de dificultad solo se actualizan al cambiar, y no se recalcula nada si la lista esta quieta.
	static inline var CAPS:Int = 10;
	static var fpCaps:Array<flixel.FlxSprite> = [];
	static var fpChips:Array<flixel.text.FlxText> = [];
	static var fpKey:String = '';
	public static var fpDirty:Bool = true;

	public static function addFreeplayPanel(state:flixel.FlxState):Void
	{
		fpCaps = []; fpChips = []; fpKey = ''; fpDirty = true;

		var panel:flixel.FlxSprite = new flixel.FlxSprite().makeGraphic(500, FlxG.height, 0xFF14142B);
		panel.alpha = 0.88;
		panel.scrollFactor.set();
		state.add(panel);

		var title:flixel.text.FlxText = new flixel.text.FlxText(28, 24, 450, 'FREEPLAY', 52);
		title.setFormat(Paths.font('vcr.ttf'), 52, 0xFFFFD84D, LEFT);
		title.scrollFactor.set();
		state.add(title);

		// chips de dificultad (maximo 6)
		for (i in 0...6)
		{
			var c:flixel.text.FlxText = new flixel.text.FlxText(30 + (i % 3) * 150, 92 + Std.int(i / 3) * 32, 145, '', 22);
			c.setFormat(Paths.font('vcr.ttf'), 22, 0xFF8888AA, LEFT);
			c.scrollFactor.set();
			c.visible = false;
			state.add(c);
			fpChips.push(c);
		}

		// DJ BF (usa el atlas de BF que ya trae Psych): 1 sprite, animacion en bucle
		try
		{
			var dj:flixel.FlxSprite = new flixel.FlxSprite(30, FlxG.height - 400);
			dj.frames = Paths.getSparrowAtlas('characters/BOYFRIEND');
			dj.animation.addByPrefix('idle', 'BF idle dance', 24, true);
			dj.animation.play('idle');
			dj.scale.set(0.9, 0.9);
			dj.antialiasing = ClientPrefs.data.antialiasing;
			dj.scrollFactor.set();
			state.add(dj);
		}
		catch (e:Dynamic) trace('D-Engine: DJ BF no disponible: $e');

		// capsulas: un unico grafico en cache, pool reutilizable
		var base:flixel.FlxSprite = new flixel.FlxSprite().makeGraphic(540, 92, 0x00000000, true, 'dengine_capsule');
		flixel.util.FlxSpriteUtil.drawRoundRect(base, 0, 0, 540, 92, 92, 92, 0xFFFFFFFF);
		base.destroy();
		for (i in 0...CAPS)
		{
			var c:flixel.FlxSprite = new flixel.FlxSprite();
			c.loadGraphic(FlxG.bitmap.get('dengine_capsule'));
			c.scrollFactor.set();
			c.visible = false;
			c.antialiasing = ClientPrefs.data.antialiasing;
			state.add(c);
			fpCaps.push(c);
		}
	}

	/** Se llama una vez por frame desde updateTexts. Devuelve true si no hay nada que redibujar. */
	public static function freeplayFrame(lerp:Float, selected:Int, diffs:Array<String>, curDiff:Int):Bool
	{
		var key:String = diffs.join(',') + '|' + curDiff;
		if (key != fpKey)
		{
			fpKey = key;
			for (i in 0...fpChips.length)
			{
				var c = fpChips[i];
				if (i < diffs.length)
				{
					c.visible = true;
					c.text = diffs[i].toUpperCase();
					c.color = (i == curDiff) ? 0xFFFFD84D : 0xFF8888AA;
					c.size = (i == curDiff) ? 26 : 22;
				}
				else c.visible = false;
			}
		}
		if (!fpDirty && Math.abs(lerp - selected) < 0.001) return true; // lista quieta: no recalcular
		fpDirty = false;
		for (c in fpCaps) c.visible = false;
		return false;
	}

	public static function freeplayCapsule(item:Alphabet, lerp:Float):Void
	{
		var d:Float = item.targetY - lerp;
		item.x = 560 + d * 38;               // lista diagonal hacia la derecha
		item.y = 300 + d * 112;
		if (fpCaps.length == 0) return;
		var slot:Int = ((Std.int(item.targetY) % CAPS) + CAPS) % CAPS;
		var cap = fpCaps[slot];
		var sel:Bool = Math.abs(d) < 0.5;
		cap.setPosition(item.x - 26, item.y - 8);
		cap.color = sel ? 0xFFFF7FBF : 0xFF2C2C52;
		cap.alpha = sel ? 1 : 0.85;
		cap.visible = true;
	}

	/** Muestra 4 segundos que modo/layout/hitbox quedaron activos (para verificar las opciones). */
	public static function announce(state:states.PlayState):Void
	{
		var t:flixel.text.FlxText = new flixel.text.FlxText(10, 10, 0,
			'D-Engine | modo: ' + DEngineMode.current() + ' | flechas: ' + activeLayout() + ' | hitbox: ' + ClientPrefs.data.vsliceHitbox, 16);
		t.setFormat(Paths.font('vcr.ttf'), 16, 0xFFFFFFFF, LEFT, flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, 0xFF000000);
		t.cameras = [state.camOther];
		state.add(t);
		flixel.tweens.FlxTween.tween(t, {alpha: 0}, 1, {startDelay: 4, onComplete: function(_) { state.remove(t); t.destroy(); }});
	}

	// ---------- Layout "V-Slice movil" (esquema Arrows de V-Slice) ----------
	// Una sola fila de flechas ABAJO y centrada, mas separadas entre si, con downscroll.
	// El rival se oculta (V-Slice lo deja en mini arriba a la izquierda).
	static var savedDown:Null<Bool> = null;
	static var savedOpp:Null<Bool> = null;

	public static inline function arrowsMode():Bool return activeLayout() == 'V-Slice';

	/** Separacion entre flechas (V-Slice: NOTE_SPACING * 1.575 * 1.097 ~ 193 px en 1280). */
	public static inline function arrowsPitch():Float return FlxG.width * 0.151;

	public static inline function arrowsX0():Float return (FlxG.width - (3 * arrowsPitch() + 112)) / 2;

	public static inline function arrowsY():Float return (FlxG.height - 112) * 0.95 - 24;

	public static function pushArrows():Void
	{
		if (!arrowsMode() || savedDown != null) return;
		savedDown = ClientPrefs.data.downScroll;
		savedOpp = ClientPrefs.data.opponentStrums;
		ClientPrefs.data.downScroll = true;
		ClientPrefs.data.opponentStrums = false;
	}

	public static function popArrows():Void
	{
		if (savedDown == null) return;
		ClientPrefs.data.downScroll = savedDown;
		ClientPrefs.data.opponentStrums = savedOpp;
		savedDown = null; savedOpp = null;
	}

	/** Se llama despues de crear cada strum. */
	public static function arrowsPlace(strum:objects.StrumNote, i:Int, player:Int):Void
	{
		if (savedDown == null) return;
		if (player == 1)
		{
			strum.x = arrowsX0() + i * arrowsPitch();
			strum.y = arrowsY();
		}
	}
}
