local T = require("./TestLib")
local Formulas = require("../src/shared/Formulas")
local Config = require("../src/shared/Config")

T.test("tierIndex orders tiers", function()
	T.expectEqual(Formulas.tierIndex("Common"), 1)
	T.expectEqual(Formulas.tierIndex("Secret"), 7)
end)

T.test("tierIndex rejects unknown tiers", function()
	T.expectTrue(not pcall(Formulas.tierIndex, "Mega"))
end)

T.test("rookie walk speed is the Roblox default", function()
	T.expectNear(Formulas.walkSpeed(0), 16, 1e-9)
end)

T.test("walk speed rises with zoomies and is capped", function()
	T.expectTrue(Formulas.walkSpeed(1000) > Formulas.walkSpeed(100))
	T.expectNear(Formulas.walkSpeed(1e30), Config.Speed.max, 1e-9)
end)

T.test("walk speed at 1000 zoomies matches the curve", function()
	T.expectNear(Formulas.walkSpeed(1000), 16 + 6 * math.log10(101), 1e-9)
end)

T.test("carrying slows you by tier", function()
	T.expectNear(Formulas.carrySpeed(0, "Common"), 16 * 0.8, 1e-9)
	T.expectNear(Formulas.carrySpeed(0, "Rare"), 16 * 0.6, 1e-9)
	T.expectNear(Formulas.carrySpeed(0, "Legendary"), 16 * 0.4, 1e-9)
end)

T.test("a carrying rookie is slower than the Zone 1 guardian", function()
	T.expectTrue(Formulas.carrySpeed(0, "Common") < Config.Zones[1].guardianSpeed)
end)

T.test("a little wheel time lets a Common carrier outrun the Zone 1 guardian", function()
	T.expectTrue(Formulas.carrySpeed(150, "Common") > Config.Zones[1].guardianSpeed)
end)

T.test("income follows section 25", function()
	T.expectNear(Formulas.incomePerSecond("Common", 1), 1, 1e-9)
	T.expectNear(Formulas.incomePerSecond("Uncommon", 1), 5, 1e-9)
	T.expectNear(Formulas.incomePerSecond("Common", 6), 12, 1e-9)
	T.expectNear(Formulas.incomePerSecond("Epic", 4), 125 * 4, 1e-9)
end)

T.test("unwrap time spans 20 s to 20 min times size factor 1 to 3", function()
	T.expectNear(Formulas.unwrapSeconds("Common", 1), 20, 1e-9)
	T.expectNear(Formulas.unwrapSeconds("Secret", 1), 1200, 1e-9)
	T.expectNear(Formulas.unwrapSeconds("Common", 6), 60, 1e-9)
end)

T.test("model scale grows with size", function()
	T.expectNear(Formulas.sizeScale(1), 1, 1e-9)
	T.expectTrue(Formulas.sizeScale(6) > Formulas.sizeScale(5))
end)

T.test("sizes outside 1..6 clamp instead of erroring", function()
	T.expectNear(Formulas.incomePerSecond("Common", 9), 12, 1e-9)
	T.expectNear(Formulas.incomePerSecond("Common", 0), 1, 1e-9)
end)

return {}
