package backend;

import flixel.addons.display.FlxRuntimeShader;
import openfl.display.BitmapData;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * D-Engine: shaders propios. En vez de .frag, cada shader es una carpeta:
 *   shaders/<nombre>/<nombre>.png   imagen (textura / mascara)
 *   shaders/<nombre>/<nombre>.js    script que lo controla (addShader / setShaderParam)
 *   shaders/<nombre>/<nombre>.json  definicion: {"effect":"wave","target":"camGame","params":{...}}
 * Efectos incluidos: tint, wave, chroma, mask.
 * API en scripts .js:  addShader(nombre, ?camara)  setShaderParam(nombre, param, valor)  removeShader(nombre)
 */
class DEngineShader
{
	static var shaders:Map<String, FlxRuntimeShader> = new Map();
	static var filters:Map<String, Array<Dynamic>> = new Map(); // nombre -> [[camara, filtro]]
	static var time:Float = 0;

	static var GLSL:Map<String, String> = [
		'tint' => '#pragma header
			uniform float r; uniform float g; uniform float b; uniform float amount;
			void main(){ vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
				gl_FragColor = vec4(mix(c.rgb, vec3(r,g,b) * c.a, amount), c.a); }',
		'wave' => '#pragma header
			uniform float uTime; uniform float amplitude; uniform float frequency; uniform float speed;
			void main(){ vec2 uv = openfl_TextureCoordv;
				uv.x += sin(uv.y * frequency + uTime * speed) * amplitude;
				gl_FragColor = flixel_texture2D(bitmap, uv); }',
		'chroma' => '#pragma header
			uniform float amount;
			void main(){ vec2 uv = openfl_TextureCoordv;
				float rr = flixel_texture2D(bitmap, uv + vec2(amount, 0.0)).r;
				vec4 gg = flixel_texture2D(bitmap, uv);
				float bb = flixel_texture2D(bitmap, uv - vec2(amount, 0.0)).b;
				gl_FragColor = vec4(rr, gg.g, bb, gg.a); }',
		'mask' => '#pragma header
			uniform sampler2D uTex; uniform float amount;
			void main(){ vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
				vec4 m = texture2D(uTex, openfl_TextureCoordv);
				gl_FragColor = vec4(mix(c.rgb, c.rgb * m.rgb, amount), c.a); }'
	];

	static var DEFAULTS:Map<String, Dynamic> = [
		'tint' => {r: 1.0, g: 0.5, b: 0.5, amount: 0.3},
		'wave' => {amplitude: 0.01, frequency: 20.0, speed: 2.0},
		'chroma' => {amount: 0.003},
		'mask' => {amount: 1.0}
	];

	public static function clear():Void
	{
		for (n in shaders.keys()) remove(n);
		shaders = new Map(); filters = new Map(); time = 0;
	}

	static function camByName(n:String):Array<flixel.FlxCamera>
	{
		var p = states.PlayState.instance;
		if (p == null) return [];
		return switch (n)
		{
			case 'camHUD': [p.camHUD];
			case 'camOther': [p.camOther];
			case 'all': [p.camGame, p.camHUD, p.camOther];
			default: [p.camGame];
		};
	}

	public static function add(name:String, ?target:String):Bool
	{
		#if sys
		if (shaders.exists(name)) return true;
		var jsonPath:String = Paths.modFolders('shaders/$name/$name.json');
		var def:Dynamic = {effect: 'tint', params: {}};
		if (jsonPath != null && FileSystem.exists(jsonPath))
			try def = Json.parse(File.getContent(jsonPath)) catch (e:Dynamic) trace('D-Engine shader json "$name": $e');
		var effect:String = def.effect != null ? Std.string(def.effect) : 'tint';
		var src:String = GLSL.get(effect);
		if (src == null) { trace('D-Engine: efecto de shader desconocido: $effect'); return false; }

		var sh:FlxRuntimeShader = new FlxRuntimeShader(src);
		var dflt:Dynamic = DEFAULTS.get(effect);
		for (f in Reflect.fields(dflt)) sh.setFloat(f, Reflect.field(dflt, f));
		if (def.params != null) for (f in Reflect.fields(def.params)) setOne(sh, f, Reflect.field(def.params, f));

		if (effect == 'mask')
		{
			var png:String = Paths.modFolders('shaders/$name/' + (def.texture != null ? Std.string(def.texture) : '$name.png'));
			if (png != null && FileSystem.exists(png)) sh.setSampler2D('uTex', BitmapData.fromFile(png));
		}
		shaders.set(name, sh);

		var tgt:String = target != null ? target : (def.target != null ? Std.string(def.target) : 'camGame');
		var list:Array<Dynamic> = [];
		for (cam in camByName(tgt))
		{
			var flt:ShaderFilter = new ShaderFilter(sh);
			var cur:Array<BitmapFilter> = cam.filters != null ? cam.filters.copy() : [];
			cur.push(flt);
			cam.filters = cur;
			list.push([cam, flt]);
		}
		filters.set(name, list);
		return true;
		#else
		return false;
		#end
	}

	public static function remove(name:String):Void
	{
		var list:Array<Dynamic> = filters.get(name);
		if (list != null)
			for (pair in list)
			{
				var cam:flixel.FlxCamera = pair[0];
				if (cam != null && cam.filters != null) { var c = cam.filters.copy(); c.remove(pair[1]); cam.filters = c; }
			}
		filters.remove(name); shaders.remove(name);
	}

	static function setOne(sh:FlxRuntimeShader, param:String, value:Dynamic):Void
	{
		if (Std.isOfType(value, Array)) sh.setFloatArray(param, value);
		else sh.setFloat(param, value);
	}

	public static function setParam(name:String, param:String, value:Dynamic):Void
	{
		var sh:FlxRuntimeShader = shaders.get(name);
		if (sh != null) setOne(sh, param, value);
	}

	public static function update(elapsed:Float):Void
	{
		time += elapsed;
		for (sh in shaders) sh.setFloat('uTime', time);
	}
}
