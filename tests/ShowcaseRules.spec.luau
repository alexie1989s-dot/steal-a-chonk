local T = require("./TestLib")
local Config = require("../src/shared/Config")
local Formulas = require("../src/shared/Formulas")
local ShowcaseRules = require("../src/shared/ShowcaseRules")

local function steal(overrides)
	local c = {
		available = true,
		isOwner = false,
		carrying = false,
		now = 100,
		immuneUntil = 0,
		isDummy = false,
		dummyTaken = false,
	}
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end

T.test("a free-handed neighbour may steal an available porch item", function()
	T.expectEqual(ShowcaseRules.canSteal(steal()), true)
end)

T.test("steal refusals name their reason, availability first", function()
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ available = false, isOwner = true }))), "taken")
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ isOwner = true }))), "yours")
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ carrying = true }))), "alreadyCarrying")
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ immuneUntil = 100.5 }))), "immune")
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ isDummy = true, dummyTaken = true }))), "dummyDone")
end)

T.test("immunity ends exactly at immuneUntil", function()
	T.expectEqual(ShowcaseRules.canSteal(steal({ now = 220, immuneUntil = 220 })), true)
end)

T.test("placing on your porch takes the first free slot", function()
	T.expectEqual(select(2, ShowcaseRules.canPlace({ carrying = "burrito", atOwnPlot = true, slots = {} })), 1)
	T.expectEqual(
		select(2, ShowcaseRules.canPlace({ carrying = "chonk", atOwnPlot = true, slots = { [1] = true } })),
		2
	)
end)

T.test("placing refusals", function()
	local full = {}
	for slot = 1, Config.Showcase.slots do
		full[slot] = true
	end
	T.expectEqual(select(2, ShowcaseRules.canPlace({ carrying = nil, atOwnPlot = true, slots = {} })), "notCarrying")
	T.expectEqual(
		select(2, ShowcaseRules.canPlace({ carrying = "burrito", atOwnPlot = false, slots = {} })),
		"notYourBase"
	)
	T.expectEqual(
		select(2, ShowcaseRules.canPlace({ carrying = "burrito", atOwnPlot = true, slots = full })),
		"porchFull"
	)
end)

T.test("a second dummy Chonk cannot be kept", function()
	T.expectEqual(ShowcaseRules.canKeep(false, true), true)
	T.expectEqual(ShowcaseRules.canKeep(true, false), true)
	T.expectEqual(select(2, ShowcaseRules.canKeep(true, true)), "dummyDone")
end)

T.test("the porch unwraps faster than the Vault", function()
	local vault = Formulas.unwrapSeconds("Rare", 3)
	T.expectNear(ShowcaseRules.unwrapSeconds("Rare", 3, true), vault * Config.Showcase.unwrapFactor, 1e-9)
	T.expectNear(ShowcaseRules.unwrapSeconds("Rare", 3, false), vault, 1e-9)
end)

T.test("unwrap progress carries over and is clamped", function()
	T.expectNear(ShowcaseRules.progressAt(0, 10, 40, 30), 0.5, 1e-9)
	T.expectNear(ShowcaseRules.progressAt(0.5, 10, 40, 60), 1, 1e-9)
	T.expectNear(ShowcaseRules.progressAt(0.25, 10, 40, 5), 0.25, 1e-9)
	T.expectNear(ShowcaseRules.remainingSeconds(0.25, 80), 60, 1e-9)
end)

T.test("porch Chonks earn half again", function()
	local vault = { [1] = { tier = "Common", size = 1 } }
	local porch = { [2] = { tier = "Uncommon", size = 1 } }
	T.expectNear(ShowcaseRules.incomePerSecond(vault, porch), 1 + 5 * Config.Showcase.incomeMultiplier, 1e-9)
	T.expectNear(ShowcaseRules.incomePerSecond({}, {}), 0, 1e-9)
end)

T.test("a returning item goes to the porch first, then the Vault", function()
	local where, slot = ShowcaseRules.returnPlan(2, 5)
	T.expectEqual(where, "showcase")
	T.expectEqual(slot, 2)
	where, slot = ShowcaseRules.returnPlan(nil, 5)
	T.expectEqual(where, "vault")
	T.expectEqual(slot, 5)
	T.expectEqual(ShowcaseRules.returnPlan(nil, nil), nil)
end)

T.test("moving between Vault and porch only works at home and with room", function()
	T.expectEqual(select(2, ShowcaseRules.canMoveToPorch({ onOwnPlot = true, porchFree = 2 })), 2)
	T.expectEqual(select(2, ShowcaseRules.canMoveToPorch({ onOwnPlot = false, porchFree = 2 })), "awayFromHome")
	T.expectEqual(select(2, ShowcaseRules.canMoveToPorch({ onOwnPlot = true, porchFree = nil })), "porchFull")
	T.expectEqual(ShowcaseRules.canMoveToVault({ onOwnPlot = true, vaultCount = 0, incubating = 0 }), true)
	T.expectEqual(
		select(2, ShowcaseRules.canMoveToVault({ onOwnPlot = false, vaultCount = 0, incubating = 0 })),
		"awayFromHome"
	)
	T.expectEqual(
		select(
			2,
			ShowcaseRules.canMoveToVault({
				onOwnPlot = true,
				vaultCount = Config.Vault.displaySlots - 1,
				incubating = 1,
			})
		),
		"vaultFull"
	)
end)

T.test("a steal counts only after the full hold, as the server saw it", function()
	local hold = Config.Showcase.stealHoldSeconds
	local slack = Config.Showcase.holdToleranceSeconds
	T.expectEqual(ShowcaseRules.heldLongEnough(nil, 10, hold), false) -- the server never saw the hold begin
	T.expectEqual(ShowcaseRules.heldLongEnough(10, 10.05, hold), false) -- an instant trigger
	T.expectEqual(ShowcaseRules.heldLongEnough(10, 10 + hold, hold), true)
	T.expectEqual(ShowcaseRules.heldLongEnough(10, 10 + hold - slack, hold), true) -- network jitter
	T.expectEqual(ShowcaseRules.heldLongEnough(10, 10 + hold - slack - 0.01, hold), false)
end)

T.test("theft messages follow the comedy voice", function()
	local victim, thief = ShowcaseRules.theftMessages("Greg")
	T.expectEqual(victim, "Greg has been stolen. Greg is not surprised.")
	T.expectTrue(string.find(thief, "Greg", 1, true) ~= nil)
end)

return {}
