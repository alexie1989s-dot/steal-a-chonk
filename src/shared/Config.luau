-- Every tunable number in the game (spec §25). Systems read from here and never hard-code values.
-- Values marked "slice proposal" are prototype choices the spec leaves open; see
-- docs/superpowers/plans/2026-09-24-vertical-slice-prototype.md for the reasoning.
local Config = {}

Config.Tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Config.Economy = {
	commonIncome = 1, -- cash per second for a Common at A Fine Boi (§25)
	tierMultiplier = 5, -- income ×5 per tier (§25)
	incomeTickSeconds = 1,
}

-- Indexed by size 1..6: A Fine Boi .. OH LAWD HE COMIN
Config.SizeIncome = { 1, 1.5, 2.5, 4, 7, 12 } -- §25
Config.SizeUnwrap = { 1, 1.4, 1.8, 2.2, 2.6, 3 } -- §25 gives 1 to 3; fill is a slice proposal
-- Model scale, slice proposal. Capped so that ten Chonks on the Vault display pads never
-- interpenetrate: the widest body a plot can hold is `4 * max(SizeScale) * WidestBodyProfile`, and
-- that has to stay under Vault.displaySpacing. Raising the top of this list needs one of the pad
-- spacing, the plot size or the slot count to move with it (user ruling, 2026-10-01).
Config.SizeScale = { 1, 1.07, 1.14, 1.21, 1.28, 1.35 }
-- The largest `wide` in Models' SPECIES table. Kept here so the fit can be checked by a pure test
-- without loading a server module; raise it if a new Chonk is built wider.
Config.WidestBodyProfile = 1.24
Config.SizeWeights = { 50, 25, 13, 7, 4, 1 } -- slice proposal

-- §25 gives Common 20 s and Secret 20 min; the geometric fill is a slice proposal.
Config.UnwrapSeconds = {
	Common = 20,
	Uncommon = 40,
	Rare = 80,
	Epic = 160,
	Legendary = 320,
	Mythic = 640,
	Secret = 1200,
}

-- §9 gives Common 0.8, Rare 0.6, Legendary 0.4 and a Secret waddle; the rest are slice proposals.
Config.CarryMultiplier = {
	Common = 0.8,
	Uncommon = 0.7,
	Rare = 0.6,
	Epic = 0.5,
	Legendary = 0.4,
	Mythic = 0.3,
	Secret = 0.2,
}

-- WalkSpeed = base + perDecade * log10(1 + zoomies / scale), capped at max. Slice proposal.
Config.Speed = { base = 16, perDecade = 6, scale = 10, max = 60 }

Config.Zones = {
	{
		name = "Backyards",
		zoomiesRequired = 0, -- §9
		guardianSpeed = 17, -- "slightly faster than a rookie's base Zoomies" (§7)
		nestCount = 10, -- §7 allows 8 to 14
		tierWeights = { Common = 70, Uncommon = 22, Rare = 7, Epic = 1 }, -- slice proposal
	},
}

Config.Nest = {
	-- §7: 3 to 6 minutes, longer for higher-value nests
	respawnSeconds = {
		Common = 180,
		Uncommon = 240,
		Rare = 300,
		Epic = 360,
		Legendary = 360,
		Mythic = 360,
		Secret = 360,
	},
	looseReturnSeconds = 60, -- an untouched dropped burrito walks itself home. Slice proposal.
	grabDistance = 8,
}

Config.Wheel = {
	radius = 5,
	promptDistance = 10,
	passivePerSecond = 1,
	pedalBonus = 2,
	pedalMaxPerSecond = 5,
	tickSeconds = 0.25,
}

Config.Vault = {
	labelDistance = 30, -- ten display pads sit close together; tags only read one or two at a time
	incubators = 2, -- §10
	displaySlots = 10, -- slice proposal
	promptDistance = 8,
	-- How far apart Plots sets the display pads. The house interior is 38 studs across, so five
	-- columns cannot be spaced wider than this without pushing a Chonk through a wall.
	displaySpacing = { x = 7, z = 11 },
}

-- The porch Showcase (§10, §11). Heist proposals: docs/superpowers/plans/2026-09-25-showcase-heist.md.
Config.Showcase = {
	slots = 2, -- §10: starts at 2, grows to 8 by Legend stage (growth is a later plan)
	unwrapFactor = 0.5, -- "faster unwrap" (§10); the number is a heist proposal
	incomeMultiplier = 1.5, -- "+50 percent income" (§10)
	placeDistance = 8,
	stealHoldSeconds = 1.5, -- heist proposal
	holdToleranceSeconds = 0.25, -- network jitter allowed when the server times a Steal hold
	raidCooldownSeconds = 120, -- §11: two minutes of Showcase immunity
	alarmSeconds = 6, -- heist proposal
}

-- The practice house near spawn (§11). Heist proposals.
Config.DummyBase = {
	x = 0,
	z = 24,
	respawnSeconds = 45,
}

Config.Carry = {
	-- How far above the HumanoidRootPart a carried model's underside sits. The avatar's head tops
	-- out about 2.5 studs above the root, so anything less clips through the hair.
	liftAboveRoot = 2.9,
	knockbackSpeed = 60,
	knockbackLift = 30,
	crossingCheckSeconds = 0.2,
}

Config.Bat = {
	range = 8,
	arcDot = 0.2,
	pointBlank = 3,
	cooldownSeconds = 1,
}

Config.Guardian = {
	radius = 3.5,
	patrolRadius = 14,
	patrolSpeed = 6,
	wakeDelay = 0.8, -- the "MRRP" pause (§18)
	rampSeconds = 1.5, -- "a comically slow first roll before she accelerates" (§18)
	rampStartFactor = 0.3,
	catchDistance = 5.5,
	returnSpeed = 12, -- heading back to her patrol circle after a chase. Slice proposal.
}

Config.AntiCheat = {
	sampleSeconds = 0.5,
	toleranceFactor = 1.5,
	toleranceStuds = 4,
	-- Prompt handlers re-check range on the server: prompt distance plus this slack.
	reachTolerance = 4,
}

Config.Base = {
	plotCount = 8,
	plotRingRadius = 70,
	plotSize = 40,
	curbRadius = 105,
	nestInner = 135,
	nestOuter = 230,
	fieldOuterRadius = 320,
	obstacleCount = 12,
}

-- Burrito glow and card band colours by tier (RGB 0..255). Slice proposal.
Config.TierColors = {
	Common = { 210, 210, 210 },
	Uncommon = { 110, 205, 110 },
	Rare = { 90, 150, 255 },
	Epic = { 190, 100, 255 },
	Legendary = { 255, 190, 60 },
	Mythic = { 255, 90, 90 },
	Secret = { 255, 255, 255 },
}

Config.Camera = {
	baseFov = 70,
	fovPerSpeed = 0.6,
	maxExtraFov = 20,
	-- Zoom is bounded on purpose. Roblox's default 0.5 to 400 lets a player sit inside their own
	-- avatar and the Chonk they are carrying, or pull back until the district is a dot and the
	-- camera is out past the boundary hills. These keep the game framed like a game.
	minZoom = 8,
	maxZoom = 36,
	-- What Debug.freeCamera opens the range back up to: Roblox's own defaults.
	debugMinZoom = 0.5,
	debugMaxZoom = 400,
}

Config.Idle = {
	-- The idle bob re-pivots a whole Chonk model every frame, and a model is 13 to 32 welded parts.
	-- Eight filled plots is around 96 of them, so animating the ones you cannot see was most of the
	-- cost for none of the benefit. Past this distance from the camera they just sit still.
	maxDistance = 70,
}

-- CollectionService tags. The client watches these; the server is the only thing that sets them.
Config.Tags = {
	chonkIdle = "ChonkIdle",
}

-- Studio testing only: DevHooks can scale unwrap, respawn and loose-return timers.
Config.Debug = {
	timeScale = 1,
	-- Studio only, off by default: lifts the camera zoom limits so the whole map can be inspected.
	-- DevHooks "freeCamera" toggles it; players never get it.
	freeCamera = false,
}

return Config
