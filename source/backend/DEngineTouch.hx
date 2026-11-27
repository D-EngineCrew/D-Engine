package backend;

import flixel.FlxG;
import flixel.FlxObject;

/**
 * D-Engine: navegacion tactil de menus.
 *  - Deslizar vertical = mover la seleccion (un paso cada ~56 px).
 *  - Tocar una fila: si no esta seleccionada la selecciona; si ya lo esta, la acepta.
 *  - Deslizar horizontal = izquierda/derecha (cambiar dificultad, valores de opciones).
 * Los botones en pantalla siguen funcionando igual.
 */
class DEngineTouch
{
	public static var accept:Bool = false;
	public static var left:Bool = false;
	public static var right:Bool = false;

	// puntero (touch o mouse)
	public static var px:Float = 0;
	public static var py:Float = 0;
	public static var justDown:Bool = false;
	public static var justUp:Bool = false;
	public static var isDown:Bool = false;

	static inline var STEP:Float = 56;
	static var tracking:Bool = false;
	static var sx:Float = 0;
	static var sy:Float = 0;
	static var ly:Float = 0;
	static var acc:Float = 0;
	static var dragged:Bool = false;

	public static function poll():Void
	{
		justDown = false; justUp = false;
		if (FlxG.touches != null && FlxG.touches.list.length > 0)
		{
			var t = FlxG.touches.list[0];
			px = t.screenX; py = t.screenY;
			justDown = t.justPressed; justUp = t.justReleased; isDown = t.pressed;
		}
		else
		{
			px = FlxG.mouse.screenX; py = FlxG.mouse.screenY;
			justDown = FlxG.mouse.justPressed; justUp = FlxG.mouse.justReleased; isDown = FlxG.mouse.pressed;
		}
	}

	/** Zonas donde estan los botones en pantalla: no cuentan como toques de menu. */
	static function blocked(x:Float, y:Float):Bool
	{
		return y > FlxG.height - 300 && (x < 260 || x > FlxG.width - 260);
	}

	/**
	 * Llamar al inicio del update de un menu.
	 * @param step    mueve la seleccion (+1 siguiente, -1 anterior)
	 * @param rows    filas del menu (en orden de seleccion)
	 * @param cur     indice seleccionado
	 * @param hswipe  deslizar horizontal (+1 derecha, -1 izquierda), opcional
	 */
	public static function run(step:Int->Void, rows:Void->Array<Dynamic>, cur:Void->Int, ?hswipe:Int->Void):Void
	{
		accept = false; left = false; right = false;
		poll();

		if (justDown && !blocked(px, py))
		{
			tracking = true; sx = px; sy = py; ly = py; acc = 0; dragged = false;
		}
		else if (tracking && isDown)
		{
			acc += py - ly; ly = py;
			if (Math.abs(px - sx) > 24 || Math.abs(py - sy) > 24) dragged = true;
			while (acc <= -STEP) { acc += STEP; step(1); }
			while (acc >= STEP) { acc -= STEP; step(-1); }
		}

		if (tracking && justUp)
		{
			tracking = false;
			var dx:Float = px - sx; var dy:Float = py - sy;
			if (!dragged)
			{
				var list:Array<Dynamic> = rows();
				var idx:Int = -1;
				for (i in 0...list.length)
				{
					var o:FlxObject = cast list[i];
					if (o == null || !o.visible || !o.exists) continue;
					var p = o.getScreenPosition();
					if (py >= p.y - 6 && py <= p.y + o.height + 6) { idx = i; p.put(); break; }
					p.put();
				}
				if (idx >= 0)
				{
					var c:Int = cur();
					if (idx == c) accept = true;
					else step(idx - c);
				}
			}
			else if (Math.abs(dx) > 110 && Math.abs(dy) < 70)
			{
				if (dx > 0) right = true; else left = true;
				if (hswipe != null) hswipe(dx > 0 ? 1 : -1);
			}
		}
	}
}
