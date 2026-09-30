-- Pure game formulas. No Roblox APIs, so Lune can test them (tests/Formulas.spec.luau).
local Config = require("./Config")

local Formulas = {}

local tierIndexByName: { [string]: number } = {}
for index, name in Config.Tiers do
	tierIndexByName[name] = index
end

local function clampSize(size: number): number
	return math.clamp(math.floor(size), 1, #Config.SizeIncome)
end

function Formulas.tierIndex(tier: string): number
	local index = tierIndexByName[tier]
	if not index then
		error(`unknown tier "{tier}"`, 2)
	end
	return index
end

function Formulas.walkSpeed(zoomies: number): number
	local s = Config.Speed
	local speed = s.base + s.perDecade * math.log10(1 + math.max(zoomies, 0) / s.scale)
	return math.min(speed, s.max)
end

function Formulas.carrySpeed(zoomies: number, tier: string): number
	Formulas.tierIndex(tier)
	return Formulas.walkSpeed(zoomies) * Config.CarryMultiplier[tier]
end

function Formulas.incomePerSecond(tier: string, size: number): number
	local e = Config.Economy
	return e.commonIncome * e.tierMultiplier ^ (Formulas.tierIndex(tier) - 1) * Config.SizeIncome[clampSize(size)]
end

function Formulas.unwrapSeconds(tier: string, size: number): number
	Formulas.tierIndex(tier)
	return Config.UnwrapSeconds[tier] * Config.SizeUnwrap[clampSize(size)]
end

function Formulas.sizeScale(size: number): number
	return Config.SizeScale[clampSize(size)]
end

return Formulas
