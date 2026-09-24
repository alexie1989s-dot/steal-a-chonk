local T = require("./TestLib")
local Rolls = require("../src/shared/Rolls")
local Catalog = require("../src/shared/Catalog")

T.test("pickWeighted respects cumulative bands", function()
	local order, w = { "A", "B" }, { A = 3, B = 1 }
	T.expectEqual(Rolls.pickWeighted(order, w, 0.0), "A")
	T.expectEqual(Rolls.pickWeighted(order, w, 0.74), "A")
	T.expectEqual(Rolls.pickWeighted(order, w, 0.76), "B")
	T.expectEqual(Rolls.pickWeighted(order, w, 0.999999), "B")
end)

T.test("zero-weight and missing entries are never picked", function()
	T.expectEqual(Rolls.pickWeighted({ "A", "B", "C" }, { A = 0, B = 1 }, 0.0), "B")
	T.expectEqual(Rolls.pickWeighted({ "A", "B", "C" }, { A = 0, B = 1 }, 0.99), "B")
end)

T.test("pickIndexWeighted", function()
	T.expectEqual(Rolls.pickIndexWeighted({ 1, 1 }, 0.49), 1)
	T.expectEqual(Rolls.pickIndexWeighted({ 1, 1 }, 0.51), 2)
	T.expectEqual(Rolls.pickIndexWeighted({ 0, 5, 0 }, 0.999), 2)
end)

T.test("rollBurrito returns a consistent catalog Chonk", function()
	local seq, i = { 0.1, 0.5, 0.2 }, 0
	local roll = Rolls.rollBurrito(1, function()
		i += 1
		return seq[i]
	end)
	local entry = Catalog.byId[roll.chonkId]
	T.expectTrue(entry ~= nil)
	T.expectEqual(entry.tier, roll.tier)
	T.expectTrue(roll.size >= 1 and roll.size <= 6)
	T.expectEqual(i, 3, "draws exactly three numbers")
end)

T.test("1000 random rolls stay inside Zone 1's tiers", function()
	local rng = 12345
	local function rand()
		rng = (rng * 1103515245 + 12345) % 2147483648
		return rng / 2147483648
	end
	local seen = {}
	for _ = 1, 1000 do
		local r = Rolls.rollBurrito(1, rand)
		T.expectTrue(r.tier == "Common" or r.tier == "Uncommon" or r.tier == "Rare" or r.tier == "Epic", r.tier)
		seen[r.tier] = true
	end
	T.expectTrue(seen.Common and seen.Uncommon, "common tiers appear")
end)

return {}
