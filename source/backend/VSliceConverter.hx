package backend;

import haxe.Json;
import backend.Section;
import backend.Song.SwagSong;
import backend.StageData;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * D-Engine: convierte charts V-Slice (<song>-chart.json + <song>-metadata.json)
 * al formato SwagSong de Psych para poder jugar mods V-Slice.
 * Soporta: notas, sustains, tipos (kind), cambios de BPM, scroll speed,
 * FocusCamera (camara por seccion) y PlayAnimation.
 */
class VSliceConverter
{
	/** Carpeta de un mod V-Slice externo (la usa el convertidor). */
	public static var extraRoot:Null<String> = null;

	#if sys
	static function findFile(key:String):Null<String>
	{
		var candidates:Array<String> = [Paths.modFolders(key), 'assets/' + key, 'assets/shared/' + key, 'assets/preload/' + key];
		if (extraRoot != null) candidates.insert(0, extraRoot + key);
		for (c in candidates)
			if (c != null && FileSystem.exists(c)) return c;
		return null;
	}
	#end

	// Note kinds de V-Slice -> noteTypes de Psych. Los desconocidos se dejan igual
	// (asi un mod puede definir custom_notetypes/<kind>.lua o .hx).
	static var kindMap:Map<String, String> = [
		'alt' => 'Alt Animation', 'alt-animation' => 'Alt Animation', 'altanim' => 'Alt Animation',
		'hey' => 'Hey!', 'hurt' => 'Hurt Note', 'mine' => 'Hurt Note',
		'gf' => 'GF Sing', 'girlfriend' => 'GF Sing', 'noanim' => 'No Animation', 'no_animation' => 'No Animation',
		'non_scoreable' => 'Non Scoreable'
	];
	static function mapKind(k:String):String
	{
		var m:String = kindMap.get(k.toLowerCase());
		return m != null ? m : k;
	}

	/** Variacion V-Slice que contiene la dificultad pedida ('' = chart base, '-erect', ...). */
	static function variationFor(song:String, difficulty:String):String
	{
		#if sys
		function has(path:String):Bool
		{
			try { var c:Dynamic = Json.parse(File.getContent(path)); return c.notes != null && Reflect.hasField(c.notes, difficulty); }
			catch (e:Dynamic) return false;
		}
		var basePath = findFile('data/songs/$song/$song-chart.json');
		if (basePath != null && has(basePath)) return '';
		var dir:Null<String> = null;
		if (basePath != null) dir = haxe.io.Path.directory(basePath) + '/';
		else
		{
			var cands:Array<String> = [Paths.modFolders('data/songs/$song/'), 'assets/shared/data/songs/$song/', 'assets/data/songs/$song/'];
			if (extraRoot != null) cands.insert(0, extraRoot + 'data/songs/$song/');
			for (c in cands) if (c != null && FileSystem.exists(c) && FileSystem.isDirectory(c)) { dir = c; break; }
		}
		if (dir == null) return '';
		for (f in FileSystem.readDirectory(dir))
			if (f.startsWith(song + '-chart-') && f.endsWith('.json') && has(dir + f))
				return f.substr(song.length + 6, f.length - song.length - 11);
		#end
		return '';
	}

	public static function tryLoad(song:String, difficulty:String):Null<SwagSong>
	{
		#if sys
		var vsfx:String = variationFor(song, difficulty); // '' o '-erect', '-pico', ...
		var chartPath = findFile('data/songs/$song/$song-chart$vsfx.json');
		var metaPath = findFile('data/songs/$song/$song-metadata$vsfx.json');
		if (metaPath == null) metaPath = findFile('data/songs/$song/$song-metadata.json');
		if (chartPath == null || metaPath == null) return null;

		var chart:Dynamic = Json.parse(File.getContent(chartPath));
		var meta:Dynamic = Json.parse(File.getContent(metaPath));

		return convertData(chart, meta, song, difficulty);
		#else
		return null;
		#end
	}

	public static function convertData(chart:Dynamic, meta:Dynamic, song:String, difficulty:String):Null<SwagSong>
	{
		#if sys
		// --- notas de la dificultad pedida (con respaldo) ---
		var vsNotes:Array<Dynamic> = Reflect.field(chart.notes, difficulty);
		if (vsNotes == null)
			for (f in Reflect.fields(chart.notes)) { vsNotes = Reflect.field(chart.notes, f); break; }
		if (vsNotes == null) return null;
		vsNotes = vsNotes.copy();
		vsNotes.sort(function(a:Dynamic, b:Dynamic) return Std.int(a.t - b.t));

		// --- velocidad ---
		var speed:Float = 1;
		if (chart.scrollSpeed != null)
		{
			var sp:Dynamic = Reflect.field(chart.scrollSpeed, difficulty);
			if (sp == null) sp = Reflect.field(chart.scrollSpeed, 'default');
			if (sp != null) speed = sp;
		}

		// --- BPM ---
		var timeChanges:Array<Dynamic> = meta.timeChanges;
		timeChanges.sort(function(a:Dynamic, b:Dynamic) return Std.int(a.t - b.t));
		var bpm0:Float = timeChanges[0].bpm;

		// --- eventos ---
		var focus:Array<Dynamic> = [];
		var events:Array<Dynamic> = [];
		var vsEvents:Array<Dynamic> = chart.events != null ? chart.events : [];
		for (e in vsEvents)
		{
			if (e.e == 'FocusCamera') focus.push(e);
			else if (e.e == 'DEngineEvent') events.push([e.t, [[Std.string(e.n), Std.string(e.a), Std.string(e.b)]]]);
			else if (e.e == 'PlayAnimation' && e.v != null)
			{
				var tgt:String = switch (Std.string(e.v.target)) { case 'boyfriend' | 'bf' | 'player': 'bf'; case 'girlfriend' | 'gf': 'gf'; default: 'dad'; };
				events.push([e.t, [['Play Animation', Std.string(e.v.anim), tgt]]]);
			}
		}
		focus.sort(function(a:Dynamic, b:Dynamic) return Std.int(a.t - b.t));

		// --- secciones de 4 beats ---
		var lastT:Float = vsNotes.length > 0 ? vsNotes[vsNotes.length - 1].t : 0;
		var sections:Array<SwagSection> = [];
		var starts:Array<Float> = [];
		var curBpm:Float = bpm0;
		var appliedTC:Int = 0;
		var secStart:Float = 0;
		while (secStart <= lastT + 1)
		{
			var changed:Bool = false;
			while (appliedTC + 1 < timeChanges.length && timeChanges[appliedTC + 1].t <= secStart + 1)
			{
				appliedTC++;
				curBpm = timeChanges[appliedTC].bpm;
				changed = true;
			}
			var mustHit:Bool = true;
			var gfSec:Bool = false;
			for (f in focus)
			{
				if (f.t > secStart + 1) break;
				var c:Int = (f.v != null && f.v.char != null) ? Std.int(f.v.char) : 0;
				mustHit = (c == 0);
				gfSec = (c == 2);
			}
			sections.push({
				sectionNotes: [], sectionBeats: 4, mustHitSection: mustHit, gfSection: gfSec,
				bpm: curBpm, changeBPM: changed, altAnim: false
			});
			starts.push(secStart);
			secStart += 4 * (60000 / curBpm);
		}

		// --- repartir notas ---
		var si:Int = 0;
		for (n in vsNotes)
		{
			while (si + 1 < starts.length && starts[si + 1] <= n.t + 0.5) si++;
			var sec = sections[si];
			var isPlayer:Bool = n.d < 4;
			var lane:Int = Std.int(n.d) % 4;
			// En Psych, con mustHitSection=true los datos 0-3 son del jugador; con false, 4-7.
			var data:Int = (isPlayer == sec.mustHitSection) ? lane : lane + 4;
			var entry:Array<Dynamic> = [n.t, data, n.l != null ? n.l : 0];
			if (n.k != null && Std.string(n.k) != '' && Std.string(n.k) != 'normal') entry.push(mapKind(Std.string(n.k)));
			sec.sectionNotes.push(entry);
		}

		var chars:Dynamic = meta.playData.characters;
		var result:SwagSong = {
			song: meta.songName != null ? meta.songName : song,
			notes: sections,
			events: events,
			bpm: bpm0,
			needsVoices: true,
			speed: speed,
			player1: chars.player != null ? chars.player : 'bf',
			player2: chars.opponent != null ? chars.opponent : 'dad',
			gfVersion: chars.girlfriend != null ? chars.girlfriend : 'gf',
			stage: meta.playData.stage != null ? meta.playData.stage : 'mainStage'
		};
		// Note style de V-Slice (funkin | pixel | custom) -> skin de notas de Psych
		var ns:String = (meta.playData.noteStyle != null) ? Std.string(meta.playData.noteStyle) : 'funkin';
		if (ns == 'pixel') result.arrowSkin = 'pixelUI/NOTE_assets';
		// audio de la variacion (Inst-erect, Voices-bf-erect...)
		var inst:String = chars.instrumental != null ? Std.string(chars.instrumental) : '';
		Song.audioSuffix = inst == '' ? '' : (inst.charAt(0) == '-' ? inst : '-' + inst);
		var pv:Array<Dynamic> = chars.playerVocals; var ov:Array<Dynamic> = chars.opponentVocals;
		Song.playerVocal = (pv != null && pv.length > 0) ? Std.string(pv[0]) : '';
		Song.opponentVocal = (ov != null && ov.length > 0) ? Std.string(ov[0]) : '';
		return result;
		#else
		return null;
		#end
	}
	public static function multiAtlas(keys:String):flixel.graphics.frames.FlxAtlasFrames
	{
		var parts:Array<String> = keys.split(',');
		var base:flixel.graphics.frames.FlxAtlasFrames = Paths.getAtlas(parts[0]);
		for (i in 1...parts.length)
		{
			var extra = Paths.getAtlas(parts[i]);
			if (extra != null) base.addAtlas(extra);
		}
		return base;
	}

	// ===================== PERSONAJES =====================
	public static function character(name:String):Dynamic
	{
		#if sys
		var path = findFile('data/characters/$name.json');
		if (path == null) return null;
		return characterFromData(Json.parse(File.getContent(path)), name);
		#else
		return null;
		#end
	}

	/** Quita prefijos de libreria V-Slice (shared:, weeks:, ...) de una ruta de asset. */
	public static function cleanAsset(p:Dynamic):String
	{
		var s:String = Std.string(p);
		var i:Int = s.indexOf(':');
		return i >= 0 ? s.substr(i + 1) : s;
	}

	public static function characterFromData(vs:Dynamic, name:String):Dynamic
	{
		#if sys
		if (vs.assetPath == null || vs.animations == null) return null; // no es V-Slice
		var anims:Array<Dynamic> = [];
		for (a in (vs.animations : Array<Dynamic>))
		{
			anims.push({
				anim: a.name,
				name: a.prefix != null ? a.prefix : a.name,
				fps: a.frameRate != null ? Std.int(a.frameRate) : 24,
				loop: a.looped != null ? a.looped : false,
				indices: a.frameIndices != null ? a.frameIndices : [],
				offsets: a.offsets != null ? [a.offsets[0], a.offsets[1]] : [0, 0]
			});
		}
		var icon:String = (vs.healthIcon != null && vs.healthIcon.id != null) ? vs.healthIcon.id : name;
		var image:String = cleanAsset(vs.assetPath);
		for (a in (vs.animations : Array<Dynamic>)) // MultiSparrow: varios atlas separados por coma
			if (a.assetPath != null && (',' + image + ',').indexOf(',' + cleanAsset(a.assetPath) + ',') < 0) image += ',' + cleanAsset(a.assetPath);
		return {
			animations: anims,
			image: image,
			scale: vs.scale != null ? vs.scale : 1,
			sing_duration: vs.singTime != null ? vs.singTime : 4,
			healthicon: icon,
			position: vs.offsets != null ? vs.offsets : [0, 0],
			camera_position: vs.cameraOffsets != null ? vs.cameraOffsets : [0, 0],
			flip_x: vs.flipX == true,
			no_antialiasing: vs.isPixel == true,
			healthbar_colors: [161, 161, 161],
			vocals_file: '',
			vslice: true, // los offsets de animacion son estilo V-Slice (Character.hx los convierte al cargar)
			globalOffsets: vs.offsets != null ? vs.offsets : [0, 0]
		};
		#else
		return null;
		#end
	}

	// ===================== STAGES =====================
	// V-Slice posiciona por los "pies"; Psych por la esquina superior izquierda.
	// Ajustes calibrados con el stage vanilla (mainStage vs stage).
	public static function stage(name:String):Null<StageData.StageFile>
	{
		#if sys
		var path = findFile('data/stages/$name.json');
		if (path == null) return null;
		return stageFromData(Json.parse(File.getContent(path)), name);
		#else
		return null;
		#end
	}

	public static function stageFromData(vs:Dynamic, name:String):Null<StageData.StageFile>
	{
		#if sys
		if (vs.characters == null) // stage sin personajes: posiciones por defecto de V-Slice (mainStage)
			vs.characters = {bf: {position: [989.5, 885], zIndex: 300}, dad: {position: [335, 885], zIndex: 200}, gf: {position: [751.5, 787], zIndex: 100}};
		function pos(c:Dynamic, dx:Float, dy:Float):Array<Dynamic>
			return [(c != null && c.position != null ? c.position[0] : 0) + dx, (c != null && c.position != null ? c.position[1] : 0) + dy];
		function cam(c:Dynamic):Array<Float>
			return (c != null && c.cameraOffsets != null) ? [c.cameraOffsets[0], c.cameraOffsets[1]] : [0.0, 0.0];
		var ch:Dynamic = vs.characters;
		DEngineStage.props = vs.props != null ? vs.props : [];
		var isPixel:Bool = false;
		for (pr in DEngineStage.props) if (pr.isPixel == true) isPixel = true;
		DEngineStage.charZ = ch.bf != null && ch.bf.zIndex != null ? Std.int(ch.bf.zIndex) : 100;
		DEngineStage.feet = {
			bf: ch.bf != null && ch.bf.position != null ? [ch.bf.position[0], ch.bf.position[1]] : null,
			dad: ch.dad != null && ch.dad.position != null ? [ch.dad.position[0], ch.dad.position[1]] : null,
			gf: ch.gf != null && ch.gf.position != null ? [ch.gf.position[0], ch.gf.position[1]] : null
		};
		return {
			directory: '',
			defaultZoom: vs.cameraZoom != null ? vs.cameraZoom : 1.0,
			isPixelStage: isPixel,
			stageUI: isPixel ? 'pixel' : 'normal',
			boyfriend: pos(ch.bf, -220, -785),
			girlfriend: pos(ch.gf, -351, -657),
			opponent: pos(ch.dad, -235, -785),
			hide_girlfriend: false,
			camera_boyfriend: cam(ch.bf),
			camera_opponent: cam(ch.dad),
			camera_girlfriend: cam(ch.gf),
			camera_speed: 1
		};
		#else
		return null;
		#end
	}

	// ===================== NIVELES (SEMANAS) =====================
	public static function level(path:String, id:String):Null<Dynamic>
	{
		#if sys
		var vs:Dynamic = Json.parse(File.getContent(path));
		if (vs.songs == null || vs.titleAsset == null) return null; // no es nivel V-Slice
		var color:Array<Int> = [249, 207, 81];
		if (vs.background != null && Std.string(vs.background).charAt(0) == '#' && Std.string(vs.background).length == 7)
		{
			var v:Int = Std.parseInt('0x' + Std.string(vs.background).substr(1));
			color = [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
		}
		var songs:Array<Dynamic> = [];
		for (sid in (vs.songs : Array<Dynamic>))
		{
			var sidS:String = Std.string(sid);
			var icon:String = 'face';
			var title:String = sidS;
			var mp = findFile('data/songs/$sidS/$sidS-metadata.json');
			if (mp != null)
			{
				var m:Dynamic = Json.parse(File.getContent(mp));
				if (m.songName != null) title = m.songName;
				if (m.playData != null && m.playData.characters != null && m.playData.characters.opponent != null)
				{
					icon = m.playData.characters.opponent;
					var cd:Dynamic = character(icon);
					if (cd != null) icon = cd.healthicon;
				}
			}
			songs.push([title, icon, color]);
		}
		return {
			songs: songs, weekCharacters: ['dad', 'bf', 'gf'], weekBackground: '', weekBefore: '',
			storyName: vs.name != null ? vs.name : id, weekName: id, freeplayColor: color,
			startUnlocked: true, hiddenUntilUnlocked: false,
			hideStoryMode: vs.visible == false, hideFreeplay: false, difficulties: ''
		};
		#else
		return null;
		#end
	}
}
