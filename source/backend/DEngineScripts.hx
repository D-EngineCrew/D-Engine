package backend;

import states.PlayState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * D-Engine: soporte (best effort) para scripts de V-Slice (.hxc, clases Polymod).
 * Se traducen a scripts HScript de Psych (SScript) en tiempo de carga:
 *  - se quita la cabecera `class X extends Y {` y su llave final
 *  - se quitan modificadores (override/public/private/static) y el constructor
 *  - se traducen los callbacks: onUpdate(event) -> onUpdate(elapsed), onBeatHit(event) -> onBeatHit(), etc.
 *  - `event.elapsed/beat/step/note` -> elapsed / curBeat / curStep / note
 */
class DEngineScripts
{
	static var callbackMap:Array<Array<String>> = [
		['onNoteHit', 'goodNoteHit'], ['onNoteMiss', 'noteMiss'], ['onNoteIncoming', 'onSpawnNote'], ['onCountdownStart', 'onCountdownStarted'],
		['onSongEnd', 'onEndSong'], ['onSongRetry', 'onGameOverStart']
	];

	public static function preprocess(src:String):String
	{
		var s:String = src;
		s = ~/^\s*import\s+funkin\.[^;]*;\s*$/gm.replace(s, '');            // imports de V-Slice
		s = ~/^\s*@:[^\n]*$/gm.replace(s, '');                              // metadata @:hscriptClass ...
		s = ~/\b(override|public|private|final)\s+/g.replace(s, '');        // modificadores
		s = ~/\bstatic\s+(function|var)/g.replace(s, "$1");
		s = ~/function\s+new\s*\([^)]*\)\s*\{[^{}]*\}/g.replace(s, '');   // constructor simple

		// cabecera de clase + llave final
		var cls = ~/class\s+\w+(\s+extends\s+[\w\.]+)?\s*\{/;
		if (cls.match(s))
		{
			s = cls.matchedLeft() + cls.matchedRight();
			var last:Int = s.lastIndexOf('}');
			if (last >= 0) s = s.substr(0, last) + s.substr(last + 1);
		}

		// callbacks con parametros
		s = ~/function\s+onUpdate\s*\(\s*\w+\s*(:\s*\w+)?\s*\)/g.replace(s, 'function onUpdate(elapsed)');
		s = ~/\bevent\.elapsed\b/g.replace(s, 'elapsed');
		s = ~/\bevent\.(beat|step)\b/g.map(s, function(r) return r.matched(1) == 'beat' ? 'curBeat' : 'curStep');
		for (m in callbackMap)
			s = new EReg('function\\s+' + m[0] + '\\s*\\(\\s*\\w+\\s*(:\\s*\\w+)?\\s*\\)', 'g').replace(s, 'function ' + m[1] + '(note)');
		s = ~/\bevent\.note\b/g.replace(s, 'note');
		s = ~/\(\s*event\s*(:\s*\w+)?\s*\)/g.replace(s, '()');              // onCreate(event:ScriptEvent) -> onCreate()
		s = ~/\)\s*:\s*Void/g.replace(s, ')');
		return s;
	}

	/**
	 * Scripts de note kinds de V-Slice (class X extends NoteKind { super('kind', desc, style, params, noanim, suffix) })
	 * -> script de Psych con guardia por noteType + animSuffix / noAnimation. Devuelve null si no es un NoteKind.
	 */
	public static function noteKindScript(src:String):Null<String>
	{
		if (!~/extends\s+NoteKind/.match(src)) return null;
		var kindR = ~/super\s*\(\s*['"]([^'"]+)['"]([^;]*)\)\s*;/;
		if (!kindR.match(src)) return null;
		var kind:String = kindR.matched(1);
		var rest:String = kindR.matched(2);
		var noanim:Bool = rest.indexOf('DISABLE_ANIMATIONS') >= 0 || ~/,\s*true\s*,/.match(rest + ',');
		var suffixR = ~/['"]([^'"]*)['"]\s*$/;
		var suffix:String = suffixR.match(rest.trim()) ? suffixR.matched(1) : '';
		var body:String = preprocess(src);
		body = new EReg('function\\s+(goodNoteHit|noteMiss|onSpawnNote)\\s*\\(note\\)\\s*\\{', 'g').map(body, function(r) return r.matched(0) + " if (note.noteType != '" + kind + "') return;");
		var extra:String = "\nfunction opponentNoteHit(note) { if (note.noteType == '" + kind + "') goodNoteHit(note); }\n";
		if (body.indexOf('function goodNoteHit') < 0) extra = '';
		extra += "function onSpawnNote(note) { if (note.noteType == '" + kind + "') { " + (noanim ? 'note.noAnimation = true; ' : '') + (suffix != '' ? "note.animSuffix = '" + suffix + "'; " : '') + "} }\n";
		if (body.indexOf('function onSpawnNote') >= 0) extra = extra.split("function onSpawnNote(note) {").join("function onSpawnNoteKind(note) {");
		return '// NoteKind V-Slice "' + kind + '" (convertido por D-Engine)\n' + body + extra;
	}

	/** Note kinds internos de V-Slice que Psych no trae. */
	public static function loadBuiltinKinds(state:states.PlayState):Void
	{
		#if (sys && HSCRIPT_ALLOWED)
		if (Song.lastFormat == 'psych') return;
		try
		{
			if (!FileSystem.exists('files')) FileSystem.createDirectory('files');
			if (!FileSystem.exists('files/cache/')) FileSystem.createDirectory('files/cache/');
			var out:String = 'files/cache/dengine_builtin_kinds.hx';
			File.saveContent(out, "function onSpawnNote(note) { if (note.noteType == 'Non Scoreable') { note.ratingDisabled = true; } }\n");
			state.initHScript(out);
		}
		catch (e:Dynamic) trace('D-Engine builtin kinds: $e');
		#end
	}

	/** Traduce un script .js (estilo JavaScript sencillo) a HScript. */
	public static function jsToHx(src:String):String
	{
		var s:String = src;
		s = ~/\b(let|const)\b/g.replace(s, "var");
		s = ~/===/g.replace(s, "==");
		s = ~/!==/g.replace(s, "!=");
		s = ~/\bundefined\b/g.replace(s, "null");
		s = ~/console\.(log|warn|error|info)\s*\(/g.replace(s, "trace(");
		s = ~/for\s*\(\s*var\s+(\w+)\s+of\s+([^)]+)\)/g.replace(s, "for ($1 in $2)");
		s = ~/for\s*\(\s*var\s+(\w+)\s*=\s*([^;]+);\s*\1\s*<\s*([^;]+);\s*\1\+\+\s*\)/g.replace(s, "for ($1 in $2...$3)");
		s = ~/\(([^()]*)\)\s*=>\s*\{/g.replace(s, "function($1) {");
		s = ~/\(([^()]*)\)\s*=>\s*([^{;\n]+)/g.replace(s, "function($1) return $2");
		return s;
	}

	/** Carga los scripts .js de los mods con estructura D-Engine. */
	public static function loadJs(state:states.PlayState, songName:String):Void
	{
		#if (sys && HSCRIPT_ALLOWED)
		var mods:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory != '') mods.push(Mods.currentModDirectory);
		for (m in Mods.parseList().enabled) if (!mods.contains(m)) mods.push(m);
		var done:Array<String> = [];
		function run(full:String, ?eventName:String):Void
		{
			if (done.contains(full)) return;
			done.push(full);
			try
			{
				var code:String = preprocess(jsToHx(File.getContent(full))); // acepta tambien lineas estilo V-Slice (event.note, onNoteHit(event)...)
				// eventos: function run(value1, value2) -> onEvent(name, v1, v2)
				if (eventName != null && code.indexOf('onEvent') < 0)
					code += "\nfunction onEvent(eventName, value1, value2) { if (eventName == '" + eventName + "') run(value1, value2); }\n";
				if (!FileSystem.exists('files')) FileSystem.createDirectory('files');
				if (!FileSystem.exists('files/cache/')) FileSystem.createDirectory('files/cache/');
				var out:String = 'files/cache/' + ~/[^A-Za-z0-9]/g.replace(full, '_') + '.hx';
				File.saveContent(out, code);
				state.initHScript(out);
			}
			catch (e:Dynamic) trace('D-Engine: error cargando $full: $e');
		}
		function scan(dir:String, ?isEvent:Bool = false, ?onlyName:String):Void
		{
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return;
			for (f in FileSystem.readDirectory(dir))
			{
				if (!f.endsWith('.js')) continue;
				var n:String = f.substr(0, f.length - 3);
				if (onlyName != null && n != onlyName) continue;
				run(dir + f, isEvent ? n : null);
			}
		}
		for (m in mods)
		{
			if (DEngineMode.detectMod(m) != 'dengine') continue;
			var r:String = Paths.mods(m + '/');
			scan(r + 'scripts/');
			scan(r + 'events/', true);
			scan(r + 'notetypes/');
			scan(r + 'stages/', false, PlayState.curStage);
			scan(r + 'charts/' + songName + '/');
			if (FileSystem.exists(r + 'shaders/'))
				for (sd in FileSystem.readDirectory(r + 'shaders/'))
					if (FileSystem.isDirectory(r + 'shaders/' + sd)) scan(r + 'shaders/' + sd + '/');
		}
		#end
	}

	public static function loadAll(state:states.PlayState, songName:String):Void
	{
		loadBuiltinKinds(state);
		#if (sys && HSCRIPT_ALLOWED)
		var roots:Array<String> = [Paths.getSharedPath()];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) roots.push(Paths.mods(Mods.currentModDirectory + '/'));
		roots.push(Paths.mods());
		for (m in Mods.parseList().enabled) roots.push(Paths.mods(m + '/'));
		var subs:Array<String> = ['scripts/', 'data/scripts/', 'data/songs/' + songName + '/', 'data/stages/'];
		var done:Array<String> = [];
		for (r in roots)
			for (sub in subs)
			{
				var dir:String = r + sub;
				if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;
				for (f in FileSystem.readDirectory(dir))
				{
					if (!f.toLowerCase().endsWith('.hxc')) continue;
					if (sub == 'data/stages/' && f != PlayState.curStage + '.hxc') continue;
					var full:String = dir + f;
					if (done.contains(full)) continue;
					done.push(full);
					try
					{
						var cacheDir:String = 'files/cache/';
						if (!FileSystem.exists('files')) FileSystem.createDirectory('files'); if (!FileSystem.exists(cacheDir)) FileSystem.createDirectory(cacheDir);
						var out:String = cacheDir + ~/[^A-Za-z0-9]/g.replace(full, '_') + '.hx';
						var raw:String = File.getContent(full);
						var nkScript:Null<String> = noteKindScript(raw);
						File.saveContent(out, nkScript != null ? nkScript : preprocess(raw));
						state.initHScript(out);
					}
					catch (e:Dynamic) trace('D-Engine: error cargando $full: $e');
				}
			}
		#end
	}
}
