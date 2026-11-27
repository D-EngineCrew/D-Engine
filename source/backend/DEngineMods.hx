package backend;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * D-Engine: compatibilidad de metadatos entre mods Psych (pack.json) y V-Slice (_polymod_meta.json).
 * Cada mod recibe el archivo que le falta, asi se reconoce en ambos formatos.
 */
class DEngineMods
{
	public static function isVSlice(folder:String):Bool
	{
		return DEngineMode.detectMod(folder) == 'vslice';
	}

	public static function syncMeta(folder:String):Void
	{
		#if sys
		try
		{
			var pack:String = Paths.mods(folder + '/pack.json');
			var poly:String = Paths.mods(folder + '/_polymod_meta.json');
			var hasPack:Bool = FileSystem.exists(pack);
			var hasPoly:Bool = FileSystem.exists(poly);
			var kind:String = DEngineMode.detectMod(folder);
			if (kind == 'dengine')
			{
				if (!hasPack)
				{
					var man:Dynamic = Json.parse(File.getContent(Paths.mods(folder + '/mod.dengine.json')));
					File.saveContent(pack, Json.stringify({name: man.name != null ? man.name : folder, description: (man.description != null ? man.description : '') + ' [D-Engine mod]', restart: false, runsGlobally: false, color: [255, 200, 0]}, '\t'));
				}
				return;
			}
			if (hasPoly && !hasPack)
			{
				var m:Dynamic = Json.parse(File.getContent(poly));
				var desc:String = (m.description != null ? m.description : '') + ' [V-Slice mod]';
				File.saveContent(pack, Json.stringify({
					name: m.title != null ? m.title : folder, description: desc,
					restart: false, runsGlobally: false, color: [170, 0, 255]
				}, '\t'));
			}
			else if (hasPack && !hasPoly)
			{
				var p:Dynamic = Json.parse(File.getContent(pack));
				File.saveContent(poly, Json.stringify({
					title: p.name != null ? p.name : folder, description: p.description != null ? p.description : '',
					author: 'Unknown', api_version: '0.1.0', mod_version: '1.0.0', license: 'All Rights Reserved'
				}, '\t'));
			}
		}
		catch (e:Dynamic) trace('D-Engine syncMeta($folder): $e');
		#end
	}
}
