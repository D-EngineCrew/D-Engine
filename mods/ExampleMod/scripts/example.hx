// Script Haxe (HScript) de ejemplo para D-Engine
var bpmShown:Bool = false;
function onBeatHit(beat:Int):Void {
	if (beat % 16 == 0 && beat > 0) game.say('Beat ' + beat + '!');
}
function goodNoteHit(event) {
	if (event.rating == 'sick') game.health += 0.005;
}
