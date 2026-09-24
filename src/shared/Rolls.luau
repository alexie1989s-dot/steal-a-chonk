-- Weighted random picks. Callers pass uniform numbers in [0, 1), so the rules stay pure and testable.
local Config = require("./Config")
local Catalog = require("./Catalog")

local Rolls = {}

export type BurritoRoll = { chonkId: string, tier: string, size: number }

-- Picks a key from `order` in proportion to `weights`; missing or non-positive weights never win.
function Rolls.pickWeighted(order: { string }, weights: { [string]: number }, r: number): string
	local total = 0
	for _, key in order do
		total += math.max(weights[key] or 0, 0)
	end
	if total <= 0 then
		error("pickWeighted: no positive weights", 2)
	end
	local target, acc, last = r * total, 0, nil
	for _, key in order do
		local w = math.max(weights[key] or 0, 0)
		if w > 0 then
			acc += w
			last = key
			if target < acc then
				return key
			end
		end
	end
	return last :: string
end

function Rolls.pickIndexWeighted(weights: { number }, r: number): number
	local total = 0
	for _, w in weights do
		total += math.max(w, 0)
	end
	if total <= 0 then
		error("pickIndexWeighted: no positive weights", 2)
	end
	local target, acc, last = r * total, 0, 1
	for index, w in weights do
		if w > 0 then
			acc += w
			last = index
			if target < acc then
				return index
			end
		end
	end
	return last
end

-- Draws rand() exactly three times: tier, species within the tier, size.
function Rolls.rollBurrito(zone: number, rand: () -> number): BurritoRoll
	local tier = Rolls.pickWeighted(Config.Tiers, Config.Zones[zone].tierWeights, rand())
	local pool = Catalog.byTier[tier]
	local entry = pool[math.clamp(math.floor(rand() * #pool) + 1, 1, #pool)]
	local size = Rolls.pickIndexWeighted(Config.SizeWeights, rand())
	return { chonkId = entry.id, tier = tier, size = size }
end

return Rolls
