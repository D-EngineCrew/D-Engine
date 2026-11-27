package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * D-Engine: datos del engine, carpetas de usuario (.DEngine/files y .DEngine/saves)
 * y utilidades de la estructura de mods propia de D-Engine.
 */
class DEngineInfo
{
	public static inline var NAME:String = 'D-Engine';
	public static inline var VERSION:String = '0.1.0';
	public static inline var CREDIT:String = 'Aquí por siempre D-engine By DYLAN-FNF-PORTS-MOBILE, derechos reservados a FunkiCrew + ShadowMario';

	/** Crea .DEngine/files y .DEngine/saves (el directorio de trabajo ya es la carpeta .DEngine en Android). */
	public static function initFolders():Void
	{
		#if sys
		try
		{
			for (d in ['files', 'files/cache', 'saves', 'saves/charts', 'saves/events', 'saves/weeks', 'saves/characters', 'saves/converter'])
				if (!FileSystem.exists(d)) FileSystem.createDirectory(d);

			// files/: lo que el juego necesita (info, cache de scripts, guia de estructura)
			File.saveContent('files/dengine.json', haxe.Json.stringify({engine: NAME, version: VERSION, credit: CREDIT}, '\t'));
			if (!FileSystem.exists('saves/converter/LEEME.txt'))
				File.saveContent('saves/converter/LEEME.txt', 'Pon aqui la carpeta completa de un mod de V-Slice (con _polymod_meta.json).\nAl abrir D-Engine se crea mods/<NombreDelMod>-dengine/ con la estructura de mods de D-Engine.\nEl resultado queda en <NombreDelMod>.log.txt\n');
			if (!FileSystem.exists('files/ESTRUCTURA_DE_MODS.txt'))
				File.saveContent('files/ESTRUCTURA_DE_MODS.txt', MOD_GUIDE);
		}
		catch (e:Dynamic) trace('D-Engine initFolders: $e');
		#end
	}

	/** Agrega al editor de charts los eventos .js de mods D-Engine (descripcion en <evento>.json). */
	public static function addEditorEvents(stuff:Array<Dynamic>):Void
	{
		#if sys
		var mods:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory != '') mods.push(Mods.currentModDirectory);
		for (m in Mods.parseList().enabled) if (!mods.contains(m)) mods.push(m);
		for (m in mods)
		{
			if (DEngineMode.detectMod(m) != 'dengine') continue;
			var dir:String = Paths.mods(m + '/events/');
			if (!FileSystem.exists(dir)) continue;
			for (f in FileSystem.readDirectory(dir))
			{
				if (!f.endsWith('.js')) continue;
				var name:String = f.substr(0, f.length - 3);
				var exists:Bool = false;
				for (e in stuff) if (e[0] == name) exists = true;
				if (exists) continue;
				var desc:String = 'D-Engine event (' + m + ')';
				var jp:String = dir + name + '.json';
				if (FileSystem.exists(jp))
				{
					try { var j:Dynamic = haxe.Json.parse(File.getContent(jp)); if (j.description != null) desc = Std.string(j.description); } catch (e:Dynamic) {}
				}
				stuff.push([name, desc]);
			}
		}
		#end
	}

	static final MOD_GUIDE:String = "ESTRUCTURA DE MODS DE D-ENGINE
=================================
(Solo para mods de D-Engine. Los mods de Psych y V-Slice mantienen su estructura.)

mods/<MiMod>/
  mod.dengine.json        <- manifiesto (obligatorio, identifica un mod D-Engine)
  scripts/*.js            <- scripts globales
  events/<Nombre>.js      <- evento (define function run(value1, value2))
  events/<Nombre>.json    <- descripcion del evento para el editor (opcional)
  notetypes/<Nombre>.js   <- tipos de nota
  charts/<cancion>/<cancion>-<dificultad>.json   <- chart D-Engine
  charts/<cancion>/*.js   <- scripts de esa cancion
  songs/<cancion>/Inst.ogg, Voices.ogg
  characters/<nombre>.json
  stages/<nombre>.json + <nombre>.js
  weeks/<nombre>.json
  shaders/<nombre>/<nombre>.png   <- imagen (textura/mascara)
  shaders/<nombre>/<nombre>.js    <- script que controla el shader
  shaders/<nombre>/<nombre>.json  <- definicion del shader
  images/ sounds/ music/ videos/ fonts/

.DEngine/files  -> cosas que el juego necesita (cache, info)
.DEngine/saves  -> todo lo que crees: charts/, events/, weeks/, characters/
";
}
