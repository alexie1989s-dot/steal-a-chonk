local T = require("./TestLib")
local Catalog = require("../src/shared/Catalog")
local Config = require("../src/shared/Config")

T.test("slice ships exactly ten Chonks", function()
	T.expectEqual(#Catalog.entries, 10)
end)

T.test("every entry is complete and uses a real tier", function()
	local tiers = {}
	for _, t in Config.Tiers do
		tiers[t] = true
	end
	local ids = {}
	for _, e in Catalog.entries do
		T.expectTrue(tiers[e.tier], e.id .. " tier")
		T.expectTrue(#e.name > 0 and #e.bio > 0 and #e.species > 0, e.id .. " text")
		T.expectEqual(#e.color, 3, e.id .. " color")
		T.expectTrue(not ids[e.id], "duplicate id " .. e.id)
		ids[e.id] = true
	end
end)

T.test("byId and byTier index every entry", function()
	local count = 0
	for _, list in Catalog.byTier do
		count += #list
	end
	T.expectEqual(count, #Catalog.entries)
	for _, e in Catalog.entries do
		T.expectEqual(Catalog.byId[e.id], e)
	end
end)

T.test("every tier Zone 1 can roll has at least one Chonk", function()
	for tier, w in Config.Zones[1].tierWeights do
		if w > 0 then
			T.expectTrue(Catalog.byTier[tier] and #Catalog.byTier[tier] > 0, tier)
		end
	end
end)

return {}
