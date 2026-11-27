package backend;

import haxe.Json;
import backend.Song.SwagSong;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * D-Engine: chart nativo de D-Engine (charts/<cancion>/<cancion>-<dificultad>.json).
 * {
 *   "format":"dengine-chart", "song":"Nombre", "bpm":120, "speed":2.0, "stage":"stage", "noteStyle":"funkin",
 *   "characters":{"player":"bf","opponent":"dad","girlfriend":"gf"},
 *   "bpmChanges":[{"t":0,"bpm":120}],
 *   "camera":[{"t":0,"focus":"opponent"}],            // player | opponent | girlfriend
 *   "notes":[{"t":0,"lane":0,"side":"player","len":0,"kind":""}],
 *   "events":[{"t":1000,"name":"Flash","a":"0.5","b":""}],
 *   "origin":"vslice" (opcional: usa el layout V-Slice en Auto),
 *   "audio":{"suffix":"-erect","playerVocal":"bf","opponentVocal":"dad"} (opcional)
 * }
 * Se convierte a SwagSong (el formato interno) reutilizando el convertidor de V-Slice.
 */
class DEngineChart
{
	/** true si el ultimo chart cargado estaba en formato Psych (Song.hx le aplica onLoadJson). */
	public static var lastPsych:Bool = false;

	public static function tryLoad(song:String, difficulty:String):Null<SwagSong>
	{
		#if sys
		lastPsych = false;
		var cands:Array<String> = [];
		for (ext in ['json', 'txt'])
		{
			cands.push(Paths.modFolders('charts/$song/$song-$difficulty.$ext'));
			cands.push(Paths.modFolders('charts/$song/$difficulty.$ext'));
			if (difficulty == 'normal') cands.push(Paths.modFolders('charts/$song/$song.$ext'));
		}
		var path:Null<String> = null;
		for (c in cands) if (c != null && FileSystem.exists(c)) { path = c; break; }
		if (path == null) return null;

		var d:Dynamic = Json.parse(File.getContent(path));
		if (d.format != 'dengine-chart')
		{
			// Chart en formato Psych (.json o .txt): {"song": {...}} o el objeto de la cancion directamente
			var sj:Dynamic = (d.song != null && !Std.isOfType(d.song, String)) ? d.song : d;
			if (sj.notes == null) return null;
			lastPsych = true;
			return cast sj;
		}

		var notes:Array<Dynamic> = [];
		for (n in (d.notes : Array<Dynamic>))
		{
			var lane:Int = Std.int(n.lane) % 4;
			notes.push({t: n.t, d: (n.side == 'opponent') ? lane + 4 : lane, l: n.len != null ? n.len : 0, k: n.kind});
		}
		var events:Array<Dynamic> = [];
		if (d.camera != null)
			for (c in (d.camera : Array<Dynamic>))
				events.push({t: c.t, e: 'FocusCamera', v: {char: (c.focus == 'player') ? 0 : (c.focus == 'girlfriend' ? 2 : 1)}});
		if (d.events != null)
			for (e in (d.events : Array<Dynamic>))
				events.push({t: e.t, e: 'DEngineEvent', n: e.name, a: e.a != null ? e.a : '', b: e.b != null ? e.b : ''});

		var chart:Dynamic = {notes: {}, scrollSpeed: {}, events: events};
		Reflect.setField(chart.notes, difficulty, notes);
		Reflect.setField(chart.scrollSpeed, difficulty, d.speed != null ? d.speed : 1);

		var tcs:Array<Dynamic> = d.bpmChanges != null ? d.bpmChanges : [{t: 0, bpm: d.bpm != null ? d.bpm : 100}];
		var meta:Dynamic = {
			songName: d.song != null ? d.song : song,
			timeChanges: tcs,
			playData: {
				stage: d.stage != null ? d.stage : 'stage',
				noteStyle: d.noteStyle != null ? d.noteStyle : 'funkin',
				characters: d.characters != null ? d.characters : {player: 'bf', opponent: 'dad', girlfriend: 'gf'}
			}
		};
		var result = VSliceConverter.convertData(chart, meta, song, difficulty);
		// audio de variaciones (Inst-erect...) y origen del mod
		Song.origin = d.origin != null ? Std.string(d.origin) : '';
		if (d.audio != null)
		{
			Song.audioSuffix = d.audio.suffix != null ? Std.string(d.audio.suffix) : '';
			Song.playerVocal = d.audio.playerVocal != null ? Std.string(d.audio.playerVocal) : '';
			Song.opponentVocal = d.audio.opponentVocal != null ? Std.string(d.audio.opponentVocal) : '';
		}
		return result;
		#else
		return null;
		#end
	}
}
