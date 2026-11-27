package mobile.options;

import options.BaseOptionsMenu;
import options.Option;

/**
 * D-Engine: controles estilo V-Slice. Se abre con C en Opciones.
 * Basado en FunkinHitbox / FunkinHitboxControlSchemes de V-Slice.
 */
class VSliceControlsSubState extends BaseOptionsMenu
{
	var option:Option;

	public function new()
	{
		title = 'V-Slice Controls';
		rpcTitle = 'V-Slice Controls Menu';

		option = new Option('Engine Mode',
			'Auto = detects each mod/song (Psych or V-Slice) and enables its mode.\nPsych / V-Slice = force one.',
			'engineMode', 'string', ["Auto", "Psych", "V-Slice"]);
		addOption(option);

		option = new Option('Hitbox Scheme',
			'V-Slice hitbox layouts.\nFour Lanes = full-height lanes (Psych default).\nDouble Thumb Square = left/right lanes, up/down stacked.\nDouble Thumb DPad = d-pad on the right.\nArrows = four big pads at the bottom.',
			'vsliceHitbox', 'string', ["Four Lanes", "Double Thumb Square", "Double Thumb DPad", "Arrows"]);
		addOption(option);

		option = new Option('Strum Layout',
			'Where the arrows go.\nAuto = native to the mod format.\nPsych = two strumlines (Psych).\nV-Slice = mobile V-Slice: ONE wide row at the bottom, downscroll, opponent hidden.',
			'strumLayout', 'string', ["Auto", "Psych", "V-Slice"]);
		addOption(option);

		option = new Option('Freeplay Style', 'Psych = classic list.\nV-Slice = DJ BF, capsules and difficulty chips.',
			'freeplayStyle', 'string', ["Psych", "V-Slice"]);
		addOption(option);

		super();
	}
}
