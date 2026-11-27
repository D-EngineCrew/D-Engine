package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

/**
 * D-Engine: "Ayuda con Mods".
 * Fase 1: animacion (icono de la app + frase con efecto glitch).
 * Fase 2: guia de mods (assets/data/MODDING.md) con scroll arriba/abajo.
 */
class HelpModsState extends MusicBeatState
{
	static inline var SLOT:Int = 32;     // alto de cada linea
	static inline var TOP:Int = 70;      // donde empieza el documento
	static inline var WRAP:Int = 86;     // caracteres por linea

	var phase:Int = 1;
	var icon:FlxSprite;
	var tag:FlxText;
	var tagR:FlxText;
	var tagC:FlxText;
	var bgIntro:FlxSprite;
	var fullTag:String = 'Disfruta tu vida, Juegas más.';
	var typed:Int = 0;
	var typingDone:Bool = false;
	var jitter:Float = 0;
	var hue:Float = 0;

	// documento
	var docLines:Array<Array<Dynamic>> = []; // [texto, tamano, color]
	var pool:Array<FlxText> = [];
	var scroll:Float = 0;
	var vel:Float = 0;
	var dragging:Bool = false;
	var lastY:Float = 0;
	var docBg:FlxSprite;
	var docTitle:FlxText;
	var bar:FlxSprite;
	var visibleLines:Int = 0;
	var lastFirst:Int = -999;

	override function create()
	{
		persistentUpdate = true;
		bgIntro = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		add(bgIntro);

		// --- Fase 1: icono + frase ---
		icon = new FlxSprite().loadGraphic(Paths.image('dengine/icon'));
		icon.antialiasing = ClientPrefs.data.antialiasing;
		icon.scale.set(0, 0);
		icon.updateHitbox();
		icon.screenCenter();
		icon.y -= 90;
		add(icon);

		var fnt:String = Paths.font('vcr.ttf');
		tagR = makeTag(fnt, 0xFFFF2255);
		tagC = makeTag(fnt, 0xFF22EEFF);
		tag = makeTag(fnt, 0xFFFFFFFF);
		tag.borderStyle = OUTLINE; tag.borderColor = 0xFF000000; tag.borderSize = 4;

		FlxG.sound.play(Paths.sound('confirmMenu'));
		new FlxTimer().start(0.3, function(_)
		{
			if (ClientPrefs.data.flashing) FlxG.camera.flash(0xFFFFFFFF, 0.5);
			FlxG.camera.shake(0.01, 0.25);
			FlxTween.tween(icon.scale, {x: 0.55, y: 0.55}, 0.9, {ease: FlxEase.elasticOut});
			FlxTween.tween(icon, {angle: 360}, 0.9, {ease: FlxEase.backOut, onComplete: function(_) icon.angle = 0});
		});
		new FlxTimer().start(1.4, function(_) startTyping());

		// --- Fase 2 (oculta) ---
		docBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF0E0E1A);
		docBg.alpha = 0; docBg.visible = false;
		add(docBg);
		docTitle = new FlxText(16, 14, FlxG.width - 32, 'AYUDA CON MODS  |  Guia de D-Engine', 28);
		docTitle.setFormat(fnt, 28, 0xFFFFD84D, LEFT);
		docTitle.visible = false;
		add(docTitle);
		bar = new FlxSprite(FlxG.width - 8, TOP).makeGraphic(6, 40, 0xFFFF7FBF);
		bar.visible = false;
		add(bar);

		loadDoc();
		visibleLines = Math.ceil((FlxG.height - TOP) / SLOT) + 1;
		for (i in 0...visibleLines)
		{
			var t:FlxText = new FlxText(18, TOP + i * SLOT, FlxG.width - 40, '', 20);
			t.setFormat(fnt, 20, 0xFFFFFFFF, LEFT);
			t.visible = false;
			add(t);
			pool.push(t);
		}

		addTouchPad("UP_DOWN", "B");
		super.create();
	}

	function makeTag(fnt:String, color:FlxColor):FlxText
	{
		var t:FlxText = new FlxText(0, FlxG.height - 250, FlxG.width, '', 46);
		t.setFormat(fnt, 46, color, CENTER);
		t.alignment = CENTER;
		add(t);
		return t;
	}

	function startTyping():Void
	{
		new FlxTimer().start(0.05, function(tmr:FlxTimer)
		{
			typed++;
			var s:String = fullTag.substr(0, typed);
			tag.text = s; tagR.text = s; tagC.text = s;
			if (typed % 2 == 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			if (typed >= fullTag.length)
			{
				typingDone = true;
				if (ClientPrefs.data.flashing) FlxG.camera.flash(0x66FFFFFF, 0.3);
				FlxG.camera.shake(0.006, 0.3);
				new FlxTimer().start(2.0, function(_) toDoc());
			}
		}, fullTag.length);
	}

	var toDocStarted:Bool = false;
	function toDoc():Void
	{
		if (toDocStarted) return;
		toDocStarted = true;
		FlxTween.tween(icon, {alpha: 0, y: icon.y - 120}, 0.5);
		for (t in [tag, tagR, tagC]) FlxTween.tween(t, {alpha: 0}, 0.4);
		docBg.visible = true;
		FlxTween.tween(docBg, {alpha: 1}, 0.5, {onComplete: function(_)
		{
			phase = 2;
			bgIntro.visible = icon.visible = tag.visible = tagR.visible = tagC.visible = false;
			docTitle.visible = true; bar.visible = true;
			lastFirst = -999;
		}});
	}

	// ---------- documento ----------
	function loadDoc():Void
	{
		var raw:String = Paths.getTextFromFile('data/MODDING.md');
		if (raw == null || raw.length == 0) raw = '# Sin documentacion\nNo se encontro data/MODDING.md en los assets.';
		raw = raw.split('\r').join('').split('→').join('->').split('←').join('<-').split('↑').join('^').split('…').join('...');
		var inCode:Bool = false;
		for (line in raw.split('\n'))
		{
			if (line.startsWith('```')) { inCode = !inCode; continue; }
			var size:Int = 20; var color:Int = 0xFFFFFFFF; var txt:String = line;
			if (inCode) color = 0xFF9CFF9C;
			else if (line.startsWith('# ')) { size = 28; color = 0xFFFFD84D; txt = line.substr(2).toUpperCase(); }
			else if (line.startsWith('## ')) { size = 24; color = 0xFFFF7FBF; txt = line.substr(3); }
			else if (line.startsWith('### ')) { size = 21; color = 0xFF7FD6FF; txt = line.substr(4); }
			else if (line.startsWith('> ')) { color = 0xFFBBBBBB; txt = line.substr(2); }
			else if (line.startsWith('---')) { color = 0xFF555577; txt = '-----------------------------------------------'; }
			else if (line.startsWith('|'))
			{
				if (~/^\|[\s\-\|:]+\|?$/.match(line)) continue; // separador de tabla
				color = 0xFFDDDDFF;
			}
			if (!inCode) txt = txt.split('**').join('').split('`').join('');
			for (w in wrap(txt, WRAP)) docLines.push([w, size, color]);
		}
	}

	function wrap(s:String, n:Int):Array<String>
	{
		var out:Array<String> = [];
		if (s.length <= n) return [s];
		var indent:String = ''; var i:Int = 0;
		while (i < s.length && s.charAt(i) == ' ') { indent += ' '; i++; }
		var cur:String = '';
		for (word in s.split(' '))
		{
			if (cur.length + word.length + 1 > n && cur.length > 0) { out.push(cur); cur = indent + '  '; }
			cur += (cur.length > 0 && !cur.endsWith(' ') ? ' ' : '') + word;
		}
		if (cur.length > 0) out.push(cur);
		return out;
	}

	function render():Void
	{
		var first:Int = Std.int(Math.max(0, Math.floor(scroll / SLOT)));
		var off:Float = scroll - first * SLOT;
		for (i in 0...pool.length)
		{
			var idx:Int = first + i;
			var t:FlxText = pool[i];
			if (idx >= docLines.length) { t.visible = false; continue; }
			if (first != lastFirst)
			{
				var l:Array<Dynamic> = docLines[idx];
				t.text = l[0]; t.size = l[1]; t.color = l[2];
			}
			t.y = TOP + i * SLOT - off;
			t.visible = t.y > TOP - SLOT && t.y < FlxG.height;
		}
		lastFirst = first;
		var maxS:Float = maxScroll();
		var viewH:Float = FlxG.height - TOP;
		var contentH:Float = docLines.length * SLOT;
		bar.scale.y = Math.max(0.3, viewH / Math.max(contentH, viewH));
		bar.updateHitbox();
		bar.y = TOP + (maxS > 0 ? (scroll / maxS) * (viewH - bar.height) : 0);
	}

	inline function maxScroll():Float return Math.max(0, docLines.length * SLOT - (FlxG.height - TOP));

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		backend.DEngineTouch.poll();
		if (controls.BACK) { FlxG.sound.play(Paths.sound('cancelMenu')); MusicBeatState.switchState(new MainMenuState()); return; }

		if (phase == 1)
		{
			// efecto glitch + arcoiris
			jitter += elapsed;
			if (jitter > 0.05)
			{
				jitter = 0;
				tagR.x = FlxG.random.int(-5, 5); tagC.x = FlxG.random.int(-5, 5);
				tagR.y = FlxG.height - 250 + FlxG.random.int(-3, 3); tagC.y = FlxG.height - 250 + FlxG.random.int(-3, 3);
			}
			if (typingDone)
			{
				hue = (hue + elapsed * 220) % 360;
				tag.color = FlxColor.fromHSB(hue, 0.6, 1);
			}
			if (controls.ACCEPT || backend.DEngineTouch.justDown) toDoc(); // saltar animacion
			return;
		}

		// ---- fase 2: scroll ----
		if (backend.DEngineTouch.justDown && backend.DEngineTouch.py < FlxG.height - 200) { dragging = true; lastY = backend.DEngineTouch.py; vel = 0; }
		else if (backend.DEngineTouch.isDown && dragging)
		{
			var dy:Float = backend.DEngineTouch.py - lastY;
			scroll -= dy; vel = -dy; lastY = backend.DEngineTouch.py;
		}
		else
		{
			dragging = false;
			scroll += vel; vel *= 0.92;
			if (Math.abs(vel) < 0.1) vel = 0;
		}
		if (controls.UI_UP) scroll -= 650 * elapsed;
		if (controls.UI_DOWN) scroll += 650 * elapsed;
		scroll -= FlxG.mouse.wheel * 64;
		scroll = Math.max(0, Math.min(maxScroll(), scroll));
		render();
	}
}
