package backend;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * D-Engine: convertidor de mods a la estructura de D-Engine.
 *  - Mods V-Slice  (carpeta con data/songs, data/levels o _polymod_meta.json)
 *  - Mods Psych    (carpeta con weeks/, data/<cancion>/, pack.json...)
 * Pon el mod (carpeta completa) en  .DEngine/saves/converter/<MiMod>/
 * Al abrir el juego se crea  mods/<MiMod>-dengine/  y un informe  saves/converter/<MiMod>.log.txt
 * Cada archivo se convierte por separado: si uno falla, el resto sigue y el error queda en el informe.
 */
class DEngineConverter
{
	public static inline var INBOX:String = 'saves/converter/';
	/** Mods convertidos en esta sesion (el menu principal los avisa). */
	public static var converted:Array<String> = [];

	public static function runAll():Void
	{
		#if sys
		try
		{
			if (!FileSystem.exists(INBOX)) return;
			for (name in FileSystem.readDirectory(INBOX))
			{
				var src:String = INBOX + name + '/';
				if (!FileSystem.isDirectory(src)) continue;
				var isV:Bool = FileSystem.exists(src + '_polymod_meta.json') || FileSystem.exists(src + 'data/songs') || FileSystem.exists(src + 'data/levels');
				var isP:Bool = !isV && (FileSystem.exists(src + 'weeks') || FileSystem.exists(src + 'pack.json') || FileSystem.exists(src + 'custom_events') || FileSystem.exists(src + 'data'));
				if (!isV && !isP) continue;
				var out:String = Paths.mods(name + '-dengine/');
				if (FileSystem.exists(out + '.dengine_converted')) continue;
				var log:Array<String> = [];
				try { if (isV) convertVSlice(name, src, out, log); else convertPsych(name, src, out, log); }
				catch (e:Dynamic) log.push('ERROR general: $e');
				VSliceConverter.extraRoot = null;
				File.saveContent(INBOX + name + '.log.txt', log.join('\n'));
				if (FileSystem.exists(out + '.dengine_converted')) converted.push(name);
			}
			if (converted.length > 0) { Mods.updatedOnState = false; try Mods.parseList() catch (e:Dynamic) {} }
		}
		catch (e:Dynamic) trace('D-Engine converter: $e');
		#end
	}

	#if sys
	static function mk(d:String):Void
	{
		if (!FileSystem.exists(d)) FileSystem.createDirectory(d);
	}

	static function copyDir(from:String, to:String):Int
	{
		var n:Int = 0;
		if (!FileSystem.exists(from) || !FileSystem.isDirectory(from)) return 0;
		mk(to);
		for (f in FileSystem.readDirectory(from))
		{
			if (f == '.git') continue;
			if (FileSystem.isDirectory(from + f)) n += copyDir(from + f + '/', to + f + '/');
			else { try { File.copy(from + f, to + f); n++; } catch (e:Dynamic) {} }
		}
		return n;
	}

	static function listFiles(dir:String, suffix:String):Array<String>
	{
		var r:Array<String> = [];
		if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
			for (f in FileSystem.readDirectory(dir)) if (f.endsWith(suffix)) r.push(f);
		return r;
	}

	/** Lista recursiva (rutas relativas) de archivos con alguna de las extensiones; omite carpetas de assets pesados. */
	static function walk(root:String, rel:String, exts:Array<String>, found:Array<String>):Void
	{
		var dir:String = root + rel;
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return;
		for (f in FileSystem.readDirectory(dir))
		{
			var r:String = rel + f;
			if (FileSystem.isDirectory(root + r))
			{
				if (rel == '' && ['images', 'sounds', 'music', 'songs', 'videos', 'fonts', '.git'].contains(f)) continue;
				walk(root, r + '/', exts, found);
			}
			else for (e in exts) if (f.toLowerCase().endsWith(e)) { found.push(r); break; }
		}
	}

	static function mkBase(out:String):Void
	{
		for (d in ['charts', 'characters', 'stages', 'weeks', 'scripts', 'notetypes', 'events', 'shaders']) mk(out + d + '/');
	}

	/** JSON tolerante: quita BOM, comentarios // y comas finales (algunos mods los traen). */
	static function parse(path:String):Dynamic
	{
		var txt:String = File.getContent(path);
		try return Json.parse(txt) catch (e:Dynamic) {}
		if (txt.charCodeAt(0) == 0xFEFF) txt = txt.substr(1);
		txt = ~/^\s*\/\/.*$/gm.replace(txt, '');
		txt = ~/,(\s*[\]\}])/g.replace(txt, "$1");
		return Json.parse(txt);
	}

	/** Alias de personajes base de V-Slice -> nombres que D-Engine (Psych) ya trae. */
	static var charAlias:Map<String, String> = ['pico-playable' => 'pico-player', 'bf-pixel-opponent' => 'bf-pixel', 'tankman-atlas' => 'tankman', 'mom-car' => 'mom-car'];

	static function writeManifest(out:String, title:String, desc:String, author:String, from:String):Void
	{
		File.saveContent(out + 'mod.dengine.json', Json.stringify({name: title, description: desc, author: author, engine: 'D-Engine', engineVersion: DEngineInfo.VERSION, convertedFrom: from}, '\t'));
	}

	// =====================================================================================
	//  V-SLICE
	// =====================================================================================
	static function convertVSlice(name:String, src:String, out:String, log:Array<String>):Void
	{
		mk(out); mkBase(out);
		VSliceConverter.extraRoot = src;
		log.push('Convirtiendo mod V-Slice "$name" -> $out');
		var title:String = name; var desc:String = 'Convertido de V-Slice por D-Engine'; var author:String = 'Unknown';
		try
		{
			if (FileSystem.exists(src + '_polymod_meta.json'))
			{
				var pm:Dynamic = parse(src + '_polymod_meta.json');
				if (pm.title != null) title = pm.title;
				if (pm.description != null) desc = pm.description;
				if (pm.author != null) author = pm.author;
			}
		}
		catch (e:Dynamic) log.push('Aviso: _polymod_meta.json ilegible ($e)');
		writeManifest(out, title, desc, author, 'V-Slice');

		var copied:Int = 0;
		for (d in ['images', 'sounds', 'music', 'songs', 'videos', 'fonts']) copied += copyDir(src + d + '/', out + d + '/');
		log.push('Assets copiados: $copied archivos');

		var usedChars:Array<String> = []; var usedStages:Array<String> = [];
		var songIds:Array<String> = []; var oppOfSong:Map<String, String> = new Map();
		var unsupported:Array<String> = [];

		// ---- charts (base + variaciones) ----
		var songsDir:String = src + 'data/songs/';
		if (FileSystem.exists(songsDir))
			for (id in FileSystem.readDirectory(songsDir))
			{
				if (!FileSystem.isDirectory(songsDir + id)) continue;
				var dir:String = songsDir + id + '/';
				for (cf in listFiles(dir, '.json'))
				{
					if (!cf.startsWith(id + '-chart')) continue;
					try
					{
						var sfx:String = cf.substr(id.length + 6, cf.length - id.length - 11);
						var mp:String = dir + id + '-metadata' + sfx + '.json';
						if (!FileSystem.exists(mp)) mp = dir + id + '-metadata.json';
						if (!FileSystem.exists(mp)) { log.push('Chart $cf: no hay metadata'); continue; }
						var chart:Dynamic = parse(dir + cf);
						var meta:Dynamic = parse(mp);
						mk(out + 'charts/'); mk(out + 'charts/' + id + '/');
						for (diff in Reflect.fields(chart.notes))
						{
							var dc:Dynamic = toDEngineChart(id, diff, chart, meta, unsupported);
							File.saveContent(out + 'charts/' + id + '/' + id + '-' + diff + '.json', Json.stringify(dc, null, '\t'));
							for (cn in [dc.characters.player, dc.characters.opponent, dc.characters.girlfriend])
							{
								var cs:String = Std.string(cn);
								if (!usedChars.contains(cs)) usedChars.push(cs);
							}
							var stg:String = Std.string(dc.stage);
							if (!usedStages.contains(stg)) usedStages.push(stg);
							oppOfSong.set(id, Std.string(dc.characters.opponent));
							log.push('Chart: $id ($diff)');
						}
						if (!songIds.contains(id)) songIds.push(id);
					}
					catch (e:Dynamic) log.push('ERROR chart $cf: $e');
				}
			}
		if (unsupported.length > 0) log.push('Eventos V-Slice sin equivalente (omitidos): ' + unsupported.join(', '));

		// ---- personajes ----
		var convChars:Array<String> = [];
		for (f in listFiles(src + 'data/characters/', '.json'))
		{
			var n:String = f.substr(0, f.length - 5);
			try
			{
				var vs:Dynamic = parse(src + 'data/characters/' + f);
				if (vs.assetPath == null) { log.push('Personaje $n omitido: el JSON no tiene assetPath (no es formato V-Slice)'); continue; }
				if (vs.animations == null || (vs.animations : Array<Dynamic>).length == 0) { log.push('Personaje $n omitido: no tiene animaciones'); continue; }
				var rt:String = vs.renderType != null ? Std.string(vs.renderType) : 'sparrow';
				var ap:String = VSliceConverter.cleanAsset(vs.assetPath);
				if (rt == 'packer') log.push('Aviso $n: renderType "packer" no esta soportado; se convierte como sparrow');
				if (rt == 'animateatlas' && !FileSystem.exists(src + 'images/' + ap + '/Animation.json'))
					log.push('Aviso $n: no encuentro images/$ap/Animation.json (Animate Atlas)');
				else if (rt != 'animateatlas' && !FileSystem.exists(src + 'images/' + ap + '.xml') && !FileSystem.exists(src + 'images/' + ap + '.png'))
					log.push('Aviso $n: no encuentro images/$ap.png/.xml en el mod');
				var c:Dynamic = VSliceConverter.characterFromData(vs, n);
				if (c == null) { log.push('Personaje $n: no se pudo convertir'); continue; }
				mk(out + 'characters/');
				File.saveContent(out + 'characters/' + n + '.json', Json.stringify(c, null, '\t'));
				convChars.push(n);
				log.push('Personaje: $n ($rt)');
			}
			catch (e:Dynamic) log.push('ERROR personaje $n: $e');
		}

		// ---- stages ----
		var convStages:Array<String> = [];
		for (f in listFiles(src + 'data/stages/', '.json'))
		{
			var n:String = f.substr(0, f.length - 5);
			try
			{
				var vs:Dynamic = parse(src + 'data/stages/' + f);
				if (vs.characters == null) log.push('Stage $n: sin "characters"; se usan posiciones por defecto');
				var st:Dynamic = VSliceConverter.stageFromData(vs, n);
				if (st == null) { log.push('Stage $n: no se pudo convertir'); continue; }
				Reflect.setField(st, 'feet', DEngineStage.feet);
				mk(out + 'stages/');
				File.saveContent(out + 'stages/' + n + '.json', Json.stringify(st, null, '\t'));
				if (vs.props != null && (vs.props : Array<Dynamic>).length > 0)
					File.saveContent(out + 'stages/' + n + '.js', propsToJs(vs.props, DEngineStage.charZ));
				convStages.push(n);
				log.push('Stage: $n');
			}
			catch (e:Dynamic) log.push('ERROR stage $n: $e');
		}

		// ---- niveles -> weeks (si no hay, se crea una semana con todas las canciones) ----
		var weeks:Int = 0;
		for (f in listFiles(src + 'data/levels/', '.json'))
		{
			var id:String = f.substr(0, f.length - 5);
			try
			{
				var w:Dynamic = VSliceConverter.level(src + 'data/levels/' + f, id);
				if (w == null) { log.push('Level $id omitido (no es formato V-Slice)'); continue; }
				mk(out + 'weeks/');
				File.saveContent(out + 'weeks/' + id + '.json', Json.stringify(w, null, '\t'));
				weeks++; log.push('Week: $id');
			}
			catch (e:Dynamic) log.push('ERROR level $id: $e');
		}
		if (weeks == 0 && songIds.length > 0)
		{
			try
			{
				var songs:Array<Dynamic> = [];
				for (id in songIds)
				{
					var opp:String = oppOfSong.exists(id) ? oppOfSong.get(id) : 'dad';
					var icon:String = opp;
					if (FileSystem.exists(out + 'characters/' + opp + '.json'))
						try { var cj:Dynamic = parse(out + 'characters/' + opp + '.json'); if (cj.healthicon != null) icon = cj.healthicon; } catch (e:Dynamic) {}
					songs.push([id, icon, [165, 0, 255]]);
				}
				var wid:String = ~/[^A-Za-z0-9_\-]/g.replace(name, '_');
				mk(out + 'weeks/');
				File.saveContent(out + 'weeks/' + wid + '.json', Json.stringify({songs: songs, weekCharacters: ['dad', 'bf', 'gf'], weekBackground: '', weekBefore: '', storyName: title, weekName: wid, freeplayColor: [165, 0, 255], startUnlocked: true, hiddenUntilUnlocked: false, hideStoryMode: true, hideFreeplay: false, difficulties: ''}, '\t'));
				log.push('Week creada automaticamente con ' + songIds.length + ' cancion(es): $wid (el mod no traia data/levels)');
			}
			catch (e:Dynamic) log.push('ERROR creando week: $e');
		}

		// ---- scripts (busqueda recursiva en TODO el mod): .hxc/.hx/.hscript/.hxs -> .js de D-Engine ----
		var scriptFiles:Array<String> = [];
		walk(src, '', ['.hxc', '.hx', '.hscript', '.hxs'], scriptFiles);
		var usedNames:Array<String> = [];
		var nScripts:Int = 0;
		for (rel in scriptFiles)
			try
			{
				var raw:String = File.getContent(src + rel);
				var parts:Array<String> = rel.split('/');
				var fname:String = parts[parts.length - 1];
				var base:String = fname.substr(0, fname.lastIndexOf('.'));
				var nk:Null<String> = DEngineScripts.noteKindScript(raw);
				var kindR = ~/extends\s+(\w+)/;
				var ext:String = kindR.match(raw) ? kindR.matched(1) : 'script';

				var dest:String;
				if (nk != null) dest = 'notetypes/';
				else if (rel.startsWith('data/songs/') && parts.length >= 4) { dest = 'charts/' + parts[2] + '/'; mk(out + dest); }
				else if (rel.startsWith('data/stages/')) dest = 'scripts/stage-';
				else if (rel.startsWith('data/characters/')) dest = 'scripts/char-';
				else dest = 'scripts/';

				var name:String = base; var k:Int = 2;
				while (usedNames.contains(dest + name)) { name = base + '_' + k; k++; }
				usedNames.push(dest + name);
				File.saveContent(out + dest + name + '.js', nk != null ? nk : DEngineScripts.preprocess(raw));
				nScripts++;
				log.push((nk != null ? 'NoteKind -> ' : 'Script (' + ext + ') ' + rel + ' -> ') + dest + name + '.js');
			}
			catch (e:Dynamic) log.push('ERROR script $rel: $e');
		log.push(nScripts > 0 ? 'Scripts convertidos: ' + nScripts : 'AVISO: no encontre scripts (.hxc/.hx/.hscript/.hxs) en el mod. Si tu mod tiene scripts con otra extension o ruta, dime cual.');
		for (f in listFiles(src + 'shaders/', '.frag')) log.push('Shader sin convertir (GLSL propio no soportado): ' + f);

		// ---- verificacion: personajes y stages usados por las canciones ----
		for (cn in usedChars)
		{
			if (cn == null || cn == '' || convChars.contains(cn)) continue;
			if (FileSystem.exists(Paths.getSharedPath('characters/' + cn + '.json'))) continue;
			var al:String = charAlias.get(cn);
			log.push('AVISO: el personaje "' + cn + '" no esta en el mod ni en D-Engine' + (al != null ? ' (alias sugerido: ' + al + ')' : '') + '. Usara BF. Copia su .json a data/characters/ del mod original o agrega uno a characters/.');
		}
		for (sn in usedStages)
			if (!convStages.contains(sn) && !FileSystem.exists(Paths.getSharedPath('stages/' + sn + '.json')))
				log.push('AVISO: el stage "' + sn + '" no esta en el mod ni en D-Engine. Usara el stage por defecto.');

		File.saveContent(out + '.dengine_converted', 'ok');
		DEngineMode.clearCache();
		log.push('Listo. Personajes: ' + convChars.length + ', stages: ' + convStages.length + ', canciones: ' + songIds.length + '.');
	}

	// =====================================================================================
	//  PSYCH
	// =====================================================================================
	static function convertPsych(name:String, src:String, out:String, log:Array<String>):Void
	{
		log.push('Convirtiendo mod Psych "$name" -> $out');
		mk(out);
		var n:Int = copyDir(src, out);
		mkBase(out);
		log.push('Copiados $n archivos (se conservan scripts .lua/.hx, custom_events, stages, etc.: D-Engine los sigue cargando)');
		var title:String = name; var desc:String = 'Convertido de Psych por D-Engine'; var author:String = 'Unknown';
		try
		{
			if (FileSystem.exists(src + 'pack.json'))
			{
				var pk:Dynamic = parse(src + 'pack.json');
				if (pk.name != null) title = pk.name;
				if (pk.description != null) desc = pk.description;
			}
		}
		catch (e:Dynamic) log.push('Aviso: pack.json ilegible ($e)');
		writeManifest(out, title, desc, author, 'Psych');

		// charts Psych -> charts/<cancion>/ (D-Engine los lee en formato Psych, .json o .txt)
		var count:Int = 0;
		if (FileSystem.exists(src + 'data'))
			for (song in FileSystem.readDirectory(src + 'data'))
			{
				var d:String = src + 'data/' + song + '/';
				if (!FileSystem.isDirectory(d)) continue;
				for (f in FileSystem.readDirectory(d))
				{
					if (!(f.endsWith('.json') || f.endsWith('.txt')) || f.startsWith('events')) continue;
					try
					{
						var j:Dynamic = parse(d + f);
						var sj:Dynamic = (j.song != null && !Std.isOfType(j.song, String)) ? j.song : j;
						if (sj.notes == null) continue;
						mk(out + 'charts/'); mk(out + 'charts/' + song + '/');
						File.copy(d + f, out + 'charts/' + song + '/' + f);
						count++; log.push('Chart: $song/$f');
					}
					catch (e:Dynamic) log.push('ERROR chart $song/$f: $e');
				}
			}
		log.push('Charts copiados a charts/: $count');

		// scripts .hx de Psych -> .js de D-Engine (los .lua se conservan: D-Engine los sigue cargando)
		var nJs:Int = 0;
		function conv(fromDir:String, toDir:String):Void
		{
			for (f in listFiles(out + fromDir, '.hx'))
				try
				{
					var base:String = f.substr(0, f.length - 3);
					mk(out + toDir);
					File.saveContent(out + toDir + base + '.js', DEngineScripts.preprocess(File.getContent(out + fromDir + f)));
					FileSystem.deleteFile(out + fromDir + f);
					nJs++; log.push('Script Psych -> ' + toDir + base + '.js');
				}
				catch (e:Dynamic) log.push('ERROR script ' + fromDir + f + ': $e');
		}
		conv('scripts/', 'scripts/');
		conv('stages/', 'stages/');
		conv('custom_events/', 'events/');
		for (f in listFiles(out + 'custom_events/', '.txt')) // descripcion del evento -> events/<n>.json
			try { File.saveContent(out + 'events/' + f.substr(0, f.length - 4) + '.json', Json.stringify({description: File.getContent(out + 'custom_events/' + f)})); }
			catch (e:Dynamic) {}
		var nLua:Int = 0;
		var luaFiles:Array<String> = [];
		walk(out, '', ['.lua'], luaFiles);
		nLua = luaFiles.length;
		log.push('Scripts .hx convertidos a .js: $nJs | scripts .lua conservados: $nLua | custom_notetypes se deja igual (Psych los carga por tipo de nota)');
		File.saveContent(out + '.dengine_converted', 'ok');
		DEngineMode.clearCache();
		log.push('Listo. Reinicia D-Engine y activa el mod en el menu de Mods.');
	}

	// =====================================================================================
	//  Utilidades de conversion V-Slice
	// =====================================================================================
	static function toDEngineChart(id:String, diff:String, chart:Dynamic, meta:Dynamic, unsupported:Array<String>):Dynamic
	{
		var notes:Array<Dynamic> = [];
		for (n in (Reflect.field(chart.notes, diff) : Array<Dynamic>))
		{
			var o:Dynamic = {t: n.t, lane: Std.int(n.d) % 4, side: (n.d < 4) ? 'player' : 'opponent', len: n.l != null ? n.l : 0};
			if (n.k != null && Std.string(n.k) != '' && Std.string(n.k) != 'normal') Reflect.setField(o, 'kind', n.k);
			notes.push(o);
		}
		var camera:Array<Dynamic> = []; var events:Array<Dynamic> = [];
		if (chart.events != null)
			for (e in (chart.events : Array<Dynamic>))
			{
				if (e.e == 'FocusCamera') camera.push({t: e.t, focus: (e.v != null && e.v.char == 0) ? 'player' : ((e.v != null && e.v.char == 2) ? 'girlfriend' : 'opponent')});
				else if (e.e == 'PlayAnimation' && e.v != null)
					events.push({t: e.t, name: 'Play Animation', a: Std.string(e.v.anim), b: (e.v.target == 'boyfriend' || e.v.target == 'bf' || e.v.target == 'player') ? 'bf' : ((e.v.target == 'girlfriend' || e.v.target == 'gf') ? 'gf' : 'dad')});
				else if (!unsupported.contains(Std.string(e.e))) unsupported.push(Std.string(e.e));
			}
		var speed:Float = 1;
		if (chart.scrollSpeed != null)
		{
			var sp:Dynamic = Reflect.field(chart.scrollSpeed, diff);
			if (sp == null) sp = Reflect.field(chart.scrollSpeed, 'default');
			if (sp != null) speed = sp;
		}
		var tcs:Array<Dynamic> = [];
		for (tc in (meta.timeChanges : Array<Dynamic>)) tcs.push({t: tc.t, bpm: tc.bpm});
		var chars:Dynamic = meta.playData.characters;
		var inst:String = chars.instrumental != null ? Std.string(chars.instrumental) : '';
		var pv:Array<Dynamic> = chars.playerVocals; var ov:Array<Dynamic> = chars.opponentVocals;
		return {
			format: 'dengine-chart', origin: 'vslice',
			song: meta.songName != null ? meta.songName : id,
			bpm: tcs.length > 0 ? tcs[0].bpm : 100, speed: speed,
			stage: meta.playData.stage != null ? meta.playData.stage : 'mainStage',
			noteStyle: meta.playData.noteStyle != null ? meta.playData.noteStyle : 'funkin',
			characters: {player: chars.player != null ? chars.player : 'bf', opponent: chars.opponent != null ? chars.opponent : 'dad', girlfriend: chars.girlfriend != null ? chars.girlfriend : 'gf'},
			audio: {suffix: inst == '' ? '' : (inst.charAt(0) == '-' ? inst : '-' + inst), playerVocal: (pv != null && pv.length > 0) ? pv[0] : '', opponentVocal: (ov != null && ov.length > 0) ? ov[0] : ''},
			bpmChanges: tcs, camera: camera, notes: notes, events: events
		};
	}

	static function propsToJs(props:Array<Dynamic>, charZ:Int):String
	{
		var sorted:Array<Dynamic> = props.copy();
		sorted.sort(function(a:Dynamic, b:Dynamic) return Std.int((a.zIndex != null ? a.zIndex : 0) - (b.zIndex != null ? b.zIndex : 0)));
		var sb:StringBuf = new StringBuf();
		sb.add('// Generado por D-Engine (props del stage V-Slice)\nfunction onCreate() {\n\tvar s = null;\n');
		for (p in sorted)
		{
			var pos:Array<Float> = p.position != null ? p.position : [0, 0];
			var z:Int = p.zIndex != null ? Std.int(p.zIndex) : 0;
			var ap:String = VSliceConverter.cleanAsset(p.assetPath);
			sb.add('\ts = new FlxSprite(${pos[0]}, ${pos[1]});\n');
			var anims:Array<Dynamic> = p.animations != null ? p.animations : [];
			if (anims.length > 0)
			{
				sb.add('\ts.frames = Paths.getSparrowAtlas("$ap");\n');
				for (a in anims)
				{
					var fps:Int = a.frameRate != null ? Std.int(a.frameRate) : 24;
					var lp:Bool = a.looped == true;
					if (a.frameIndices != null && (a.frameIndices : Array<Dynamic>).length > 0)
						sb.add('\ts.animation.addByIndices("${a.name}", "${a.prefix}", ${Json.stringify(a.frameIndices)}, "", $fps, $lp);\n');
					else sb.add('\ts.animation.addByPrefix("${a.name}", "${a.prefix}", $fps, $lp);\n');
				}
				if (p.startingAnimation != null) sb.add('\ts.animation.play("${p.startingAnimation}");\n');
			}
			else sb.add('\ts.loadGraphic(Paths.image("$ap"));\n');
			if (p.scale != null)
			{
				if (Std.isOfType(p.scale, Array)) { var sc:Array<Float> = p.scale; sb.add('\ts.scale.set(${sc[0]}, ${sc[1]}); s.updateHitbox();\n'); }
				else sb.add('\ts.scale.set(${p.scale}, ${p.scale}); s.updateHitbox();\n');
			}
			if (p.alpha != null) sb.add('\ts.alpha = ${p.alpha};\n');
			if (p.scroll != null) { var sr:Array<Float> = p.scroll; sb.add('\ts.scrollFactor.set(${sr[0]}, ${sr[1]});\n'); }
			if (p.isPixel == true) sb.add('\ts.antialiasing = false;\n');
			sb.add(z > charZ ? '\tgame.add(s);\n' : '\tgame.addBehindGF(s);\n');
		}
		sb.add('}\n');
		return sb.toString();
	}
	#end
}
