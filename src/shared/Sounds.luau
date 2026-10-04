-- Every sound the game plays, and how each toast looks and sounds (user ruling 2026-10-04).
--
-- Only two sources are allowed: audio published by Roblox itself (creator id 1), and the licensed
-- library Roblox provides free to every experience (Pro Sound Effects and APM Music, both verified
-- accounts). Nothing from other creators. `source` records which one, so a scan can check it.
local Sounds = {}

export type Entry = {
	id: number,
	volume: number,
	name: string,
	source: "Roblox" | "ProSoundEffects" | "APM",
}

Sounds.Catalog = {
	-- Interface: Roblox's own UI sets.
	click = { id = 15675059323, volume = 0.5, name = "Roblox_UI_Bright_Click", source = "Roblox" },
	tick = { id = 15675032796, volume = 0.35, name = "Roblox_UI_Small_Click", source = "Roblox" },
	pop = { id = 15675055424, volume = 0.55, name = "Roblox_UI_Cute_Pop", source = "Roblox" },
	whoosh = { id = 15675028888, volume = 0.4, name = "Roblox_UI_Whoosh_02", source = "Roblox" },
	unwrap = { id = 15675037413, volume = 0.5, name = "Roblox_UI_Paper_Swipe", source = "Roblox" },
	good = { id = 17208361335, volume = 0.45, name = "Roblox GUI - Notification High", source = "Roblox" },
	info = { id = 17208372272, volume = 0.4, name = "Roblox GUI - Notification Low", source = "Roblox" },
	nope = { id = 17208353912, volume = 0.45, name = "Roblox GUI - Negative", source = "Roblox" },
	cash = { id = 17208380755, volume = 0.5, name = "Roblox GUI - Purchase", source = "Roblox" },

	-- Moments: the licensed library.
	reveal = { id = 1848287311, volume = 0.5, name = "The Little Things - Hit", source = "APM" },
	revealBig = { id = 133000497392138, volume = 0.5, name = "Kinetic Victory (Sting)", source = "APM" },
	home = { id = 1842141543, volume = 0.45, name = "Victory Lap (sting)", source = "APM" },
	stole = { id = 1840076509, volume = 0.5, name = "Through the Roof (sting)", source = "APM" },
	stamp = { id = 9113573976, volume = 0.6, name = "Boxing Hits 14 (SFX)", source = "ProSoundEffects" },
	bonk = { id = 9113864076, volume = 0.6, name = "Comic Tube Doink 1 (SFX)", source = "ProSoundEffects" },
	whack = { id = 9113496956, volume = 0.55, name = "Body Hit Comic 1 (SFX)", source = "ProSoundEffects" },
	robbed = { id = 9113719080, volume = 0.6, name = "Car Alarm Chirp 1 (SFX)", source = "ProSoundEffects" },
	-- Played in the world at the robbed porch, so the thief hears it too. Cut off when the lights stop.
	alarm = {
		id = 9113719289,
		volume = 0.55,
		name = "Car Alarm Exterior Van Yelp Alarm 2 Takes 1 (SFX)",
		source = "ProSoundEffects",
	},
} :: { [string]: Entry }

-- The four ways a toast can feel. The HUD gives each its own colour and icon.
Sounds.Tones = { good = true, bad = true, alert = true, info = true }

export type Style = { tone: string, sound: string }

-- One entry per Strings.Toasts key. A refusal is "info" with a soft no; losing something is "bad".
Sounds.Toasts = {
	madeItHome = { tone = "good", sound = "home" },
	caught = { tone = "bad", sound = "bonk" },
	batted = { tone = "bad", sound = "bonk" },
	youBatted = { tone = "good", sound = "whack" },
	slotsBusy = { tone = "info", sound = "nope" },
	vaultFull = { tone = "info", sound = "nope" },
	notYourBase = { tone = "info", sound = "nope" },
	notCarrying = { tone = "info", sound = "nope" },
	notHome = { tone = "info", sound = "nope" },
	noPlot = { tone = "info", sound = "info" },
	alreadyCarrying = { tone = "info", sound = "nope" },
	taken = { tone = "info", sound = "nope" },
	unwrapping = { tone = "good", sound = "unwrap" },
	porchFull = { tone = "info", sound = "nope" },
	yours = { tone = "info", sound = "nope" },
	immune = { tone = "info", sound = "nope" },
	dummyDone = { tone = "info", sound = "nope" },
	awayFromHome = { tone = "info", sound = "nope" },
	stashed = { tone = "good", sound = "cash" },
	onPorch = { tone = "good", sound = "cash" },
} :: { [string]: Style }

-- Strings.Theft messages are formatted with a name, so they are styled by key here instead.
Sounds.Theft = {
	stolen = { tone = "alert", sound = "robbed" },
	youStole = { tone = "good", sound = "stole" },
	wentHome = { tone = "bad", sound = "nope" },
	cameBack = { tone = "good", sound = "good" },
} :: { [string]: Style }

function Sounds.uri(key: string): string
	local entry = Sounds.Catalog[key]
	assert(entry, `unknown sound "{key}"`)
	return `rbxassetid://{entry.id}`
end

return Sounds
