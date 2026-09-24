-- Every player-facing string (spec §18). Draft copy for the vertical slice; partner review pending.
local Strings = {}

-- Indexed by size 1..6 (spec §8).
Strings.SizeStamps = { "A Fine Boi", "He Chomnk", "A Heckin' Chonker", "HEFTYCHONK", "MEGACHONKER", "OH LAWD HE COMIN" }

-- How each size attaches to a name: "Beans, A Fine Boi", "Beans the HEFTYCHONK" (spec §8 naming grammar).
Strings.SizeSuffix = {
	", A Fine Boi",
	", He Chomnk",
	", A Heckin' Chonker",
	" the HEFTYCHONK",
	" the MEGACHONKER",
	", OH LAWD HE COMIN",
}

Strings.Toasts = {
	madeItHome = "Made it home. The burrito is safe. The burrito is warm.",
	caught = "MRRP. Mama Chonk wants her blanket back.",
	batted = "BONK. You dropped the burrito.",
	youBatted = "BONK. Burrito loose!",
	slotsBusy = "Both incubators are busy. Chonks cannot be rushed.",
	vaultFull = "Your Vault is full. The Chonks are touching.",
	notYourBase = "That's not your basement.",
	notCarrying = "Bring a burrito first.",
	notHome = "Get the burrito home first.",
	noPlot = "The neighborhood is full. You get the lawn.",
	alreadyCarrying = "Your arms are already full of burrito.",
	taken = "Someone got there first.",
	unwrapping = "Unwrapping. Do not peek.",
}

Strings.Guardian = {
	name = "Mama Chonk",
	wake = "MRRP",
}

Strings.Prompts = {
	grab = "Grab",
	grabObject = "Blanket Burrito",
	pedal = "Pedal!",
	wheelObject = "Hamster Wheel",
	unwrap = "Unwrap",
	incubatorObject = "Incubator",
}

Strings.Reveal = {
	dismiss = "Tap to continue",
	incomeFormat = "+%s cash/s",
}

Strings.Hud = {
	cash = "Cash",
	zoomies = "Zoomies",
	speed = "Speed",
}

Strings.Bat = {
	button = "Bat",
	bonk = "BONK",
}

Strings.World = {
	zoneSign = "BACKYARDS",
	vaultSign = "VAULT",
}

return Strings
