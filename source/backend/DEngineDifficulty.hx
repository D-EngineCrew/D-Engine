package backend;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * D-Engine: detecta las dificultades que de verdad tiene cada cancion (Psych, V-Slice y D-Engine)
 * y las agrega al Freeplay: Easy, Normal, Hard, Erect, Nightmare y cualquier otra que exista.
 */
class DEngineDifficulty
{
	static var cache:Map<String, Array<String>> = new Map();
	static var ORDER:Array<String> = ['easy', 'normal', 'hard', 'erect', 'nightmare'];

	public static function clearCache():Void cache.clear();

	/** Agrega a Difficulty.list las dificultades detectadas para la cancion. */
	public static function extend(songName:String):Void
	{
		#if sys
		try
		{
			var song:String = Paths.formatToSongPath(songName);
			var cur:String = Mods.currentModDirectory != null ? Mods.currentModDirectory : '';
			var key:String = cur + '|' + song;
			var found:Array<String> = cache.get(key);
			if (found == null) { found = detect(song); cache.set(key, found); }
			var changed:Bool = false;
			for (d in found)
			{
				var exists:Bool = false;
				for (x in Difficulty.list) if (x.toLowerCase() == d) { exists = true; break; }
				if (!exists) { Difficulty.list.push(d.charAt(0).toUpperCase() + d.substr(1)); changed = true; }
			}
			if (changed)
				Difficulty.list.sort(function(a:String, b:String)
				{
					var ia:Int = ORDER.indexOf(a.toLowerCase()); var ib:Int = ORDER.indexOf(b.toLowerCase());
					if (ia < 0) ia = 99; if (ib < 0) ib = 99;
					return ia - ib;
				});
		}
		catch (e:Dynamic) trace('D-Engine difficulty: $e');
		#end
	}

	#if sys
	static function detect(song:String):Array<String>
	{
		var out:Array<String> = [];
		function add(d:String):Void
		{
			d = d.toLowerCase();
			if (d != '' && d != 'events' && !out.contains(d)) out.push(d);
		}
		var roots:Array<String> = ['assets/shared/', 'assets/', Paths.mods()];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory != '') roots.push(Paths.mods(Mods.currentModDirectory + '/'));
		for (m in Mods.parseList().enabled) roots.push(Paths.mods(m + '/'));

		for (r in roots)
		{
			// V-Slice: data/songs/<id>/<id>-chart[-variacion].json  (las dificultades son las claves de "notes")
			var vs:String = r + 'data/songs/' + song + '/';
			if (FileSystem.exists(vs) && FileSystem.isDirectory(vs))
				for (f in FileSystem.readDirectory(vs))
					if (f.startsWith(song + '-chart') && f.endsWith('.json'))
						try
						{
							var c:Dynamic = Json.parse(File.getContent(vs + f));
							if (c.notes != null) for (k in Reflect.fields(c.notes)) add(k);
						}
						catch (e:Dynamic) {}
			// Psych: data/<cancion>/<cancion>[-dif].json   |   D-Engine: charts/<cancion>/<cancion>[-dif].json
			for (sub in ['data/', 'charts/'])
			{
				var d:String = r + sub + song + '/';
				if (!FileSystem.exists(d) || !FileSystem.isDirectory(d)) continue;
				for (f in FileSystem.readDirectory(d))
				{
					if (!f.endsWith('.json')) continue;
					var n:String = f.substr(0, f.length - 5);
					if (n == song) add('normal');
					else if (n.startsWith(song + '-')) add(n.substr(song.length + 1));
				}
			}
		}
		return out;
	}
	#end
}
