package backend;

import haxe.Json;
import lime.utils.Assets;

import backend.Section;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';

	private static function onLoadJson(songJson:Dynamic) // Convert old charts to newest format
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			songJson.player3 = null;
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}
	}

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static var lastFormat:String = 'psych'; // D-Engine: 'psych' | 'vslice' | 'dengine'
	public static var audioSuffix:String = '';   // D-Engine: p.ej. '-erect' (Inst-erect.ogg)
	public static var origin:String = '';         // D-Engine: 'vslice' si el chart D-Engine viene de un mod V-Slice
	public static var playerVocal:String = '';
	public static var opponentVocal:String = '';

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var rawJson = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);

		// D-Engine: si no hay chart Psych, intentar chart V-Slice
		lastFormat = 'psych';
		audioSuffix = ''; playerVocal = ''; opponentVocal = ''; origin = '';
		#if sys
		if(jsonInput != 'events')
		{
			// D-Engine: chart nativo (charts/<cancion>/<cancion>-<dif>.json)
			var deDiff:String = (formattedSong == formattedFolder) ? 'normal' : formattedSong.substr(formattedFolder.length + 1);
			var deChart:SwagSong = DEngineChart.tryLoad(formattedFolder, deDiff);
			if(deChart != null)
			{
				lastFormat = 'dengine';
				if(DEngineChart.lastPsych) onLoadJson(deChart); // chart en formato Psych dentro de charts/
				StageData.loadDirectory(deChart);
				return deChart;
			}
			var hasPsych:Bool = FileSystem.exists(Paths.modsJson(formattedFolder + '/' + formattedSong))
				|| FileSystem.exists(Paths.json(formattedFolder + '/' + formattedSong));
			if(!hasPsych)
			{
				var diff:String = (formattedSong == formattedFolder) ? 'normal' : formattedSong.substr(formattedFolder.length + 1);
				var converted:SwagSong = VSliceConverter.tryLoad(formattedFolder, diff);
				if(converted != null)
				{
					lastFormat = 'vslice';
					StageData.loadDirectory(converted);
					return converted;
				}
			}
		}
		#end
		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsJson(formattedFolder + '/' + formattedSong);
		if(FileSystem.exists(moddyFile)) {
			rawJson = File.getContent(moddyFile).trim();
		}
		#end

		if(rawJson == null) {
			var path:String = Paths.json(formattedFolder + '/' + formattedSong);

			#if sys
			if(FileSystem.exists(path))
				rawJson = File.getContent(path).trim();
			else
			#end
				rawJson = Assets.getText(Paths.json(formattedFolder + '/' + formattedSong)).trim();
		}

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}

		// FIX THE CASTING ON WINDOWS/NATIVE
		// Windows???
		// trace(songData);

		// trace('LOADED FROM JSON: ' + songData.notes);
		/* 
			for (i in 0...songData.notes.length)
			{
				trace('LOADED FROM JSON: ' + songData.notes[i].sectionNotes);
				// songData.notes[i].sectionNotes = songData.notes[i].sectionNotes
			}

				daNotes = songData.notes;
				daSong = songData.song;
				daBpm = songData.bpm; */

		var songJson:Dynamic = parseJSONshit(rawJson);
		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		onLoadJson(songJson);
		return songJson;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		return cast Json.parse(rawJson).song;
	}
}
