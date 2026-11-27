package backend;

#if sys
import sys.FileSystem;
#end

/**
 * D-Engine: detecta que motor usa cada mod / cancion y activa su modo
 * ("psych" o "vslice") para evitar bugs y posiciones malas.
 *
 *  - Por cancion: Song.lastFormat (lo fija el cargador de charts).
 *  - Por mod: detectMod() mira la estructura de carpetas.
 *  - Opcion "Engine Mode": Auto (detecta) | Psych | V-Slice (forzar).
 */
class DEngineMode
{
	static var modCache:Map<String, String> = new Map();

	/** Modo activo ahora mismo. */
	public static function current():String
	{
		var forced:String = ClientPrefs.data.engineMode;
		if (forced == 'Psych') return 'psych';
		if (forced == 'V-Slice') return 'vslice';
		if (Song.lastFormat == 'vslice' || (Song.lastFormat == 'dengine' && Song.origin == 'vslice')) return 'vslice';
		return 'psych';
	}

	public static inline function isVSlice():Bool return current() == 'vslice';

	/** 'dengine' | 'psych' | 'vslice' | 'mixed' segun la estructura del mod. '' = juego base (Psych). */
	public static function detectMod(folder:String):String
	{
		#if sys
		if (folder == null || folder == '') return 'psych';
		if (modCache.exists(folder)) return modCache.get(folder);
		var root:String = Paths.mods(folder + '/');
		if (FileSystem.exists(root + 'mod.dengine.json')) { modCache.set(folder, 'dengine'); return 'dengine'; }
		var v:Int = 0, p:Int = 0;
		inline function dir(path:String):Bool return FileSystem.exists(root + path) && FileSystem.isDirectory(root + path);
		function list(path:String):Array<String> return dir(path) ? FileSystem.readDirectory(root + path) : [];

		// --- V-Slice ---
		if (dir('data/levels')) v++;
		for (s in list('data/songs'))
			if (dir('data/songs/' + s))
				for (f in list('data/songs/' + s)) if (f.endsWith('-chart.json') || f.endsWith('-metadata.json')) v++;
		for (sub in ['scripts', 'data/scripts', 'data/stages', 'data/characters'])
			for (f in list(sub)) if (f.endsWith('.hxc')) v++;
		// --- Psych ---
		if (dir('weeks')) p++;
		if (dir('custom_events') || dir('custom_notetypes') || dir('stages')) p++;
		for (f in list('scripts')) if (f.endsWith('.lua') || f.endsWith('.hx')) p++;
		for (s in list('data'))
			if (s != 'songs' && s != 'levels' && s != 'scripts' && s != 'stages' && s != 'characters' && dir('data/' + s))
				for (f in list('data/' + s)) if (f.endsWith('.json')) p++;

		var r:String = (v > 0 && p > 0) ? 'mixed' : (v > 0 ? 'vslice' : 'psych');
		modCache.set(folder, r);
		return r;
		#else
		return 'psych';
		#end
	}

	public static function clearCache():Void modCache.clear();
}
