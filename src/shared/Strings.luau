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
	porchFull = "The porch is full. Somebody has to sit in the Vault.",
	yours = "That one's already yours. Stealing from yourself is just moving.",
	immune = "This porch was just robbed. Give them a minute.",
	dummyDone = "You already took the practice Chonk. The dummy is out of Chonks for you.",
	awayFromHome = "Go home first. Chonks don't do long distance.",
	stashed = "Stashed in the Vault. Safe and snug.",
	onPorch = "On the porch. Everyone can see how round it is.",
}

Strings.Theft = {
	stolen = "%s has been stolen. %s is not surprised.",
	youStole = "You borrowed %s. Run!",
	wentHome = "%s's owner went home. So did %s.",
	cameBack = "%s wandered back home.",
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
	incubatorObject = "Incubator",
	vaultDeposit = "Put in Vault",
	place = "Put here",
	porchObject = "Porch",
	steal = "Steal",
	toVault = "To Vault",
	toPorch = "To Porch",
	chonkObject = "Chonk",
}

Strings.Showcase = {
	raidCooldown = "Raid cooldown %s",
	-- The sign shows dummyHouse as its heading, so the body no longer repeats the name.
	dummySign = "Steal the Chonk, carry it home. Nobody minds.",
	dummyHouse = "Practice House",
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
