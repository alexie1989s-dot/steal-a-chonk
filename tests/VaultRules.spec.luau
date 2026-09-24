local T = require("./TestLib")
local VaultRules = require("../src/shared/VaultRules")
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")

local function ctx(overrides)
	local c = {
		carrying = true,
		atOwnIncubator = true,
		incubators = {}, -- slot -> anything when busy
		vaultCount = 0,
	}
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end

T.test("a carrier at their own free incubator may deposit into the first free slot", function()
	local ok, slot = VaultRules.canDeposit(ctx())
	T.expectEqual(ok, true)
	T.expectEqual(slot, 1)
	local ok2, slot2 = VaultRules.canDeposit(ctx({ incubators = { [1] = true } }))
	T.expectEqual(ok2, true)
	T.expectEqual(slot2, 2)
end)

T.test("refusals name their reason", function()
	T.expectEqual(select(2, VaultRules.canDeposit(ctx({ carrying = false }))), "notCarrying")
	T.expectEqual(select(2, VaultRules.canDeposit(ctx({ atOwnIncubator = false }))), "notYourBase")
	T.expectEqual(select(2, VaultRules.canDeposit(ctx({ incubators = { [1] = true, [2] = true } }))), "slotsBusy")
	T.expectEqual(select(2, VaultRules.canDeposit(ctx({ vaultCount = Config.Vault.displaySlots }))), "vaultFull")
end)

T.test("incubating Chonks count toward Vault capacity", function()
	local ok, reason =
		VaultRules.canDeposit(ctx({ vaultCount = Config.Vault.displaySlots - 1, incubators = { [1] = true } }))
	T.expectEqual(ok, false)
	T.expectEqual(reason, "vaultFull")
end)

T.test("vault income sums every Chonk", function()
	local records = {
		{ uid = 1, chonkId = "cat_beans", tier = "Common", size = 1 },
		{ uid = 2, chonkId = "corgi_loaf", tier = "Uncommon", size = 6 },
	}
	T.expectNear(VaultRules.incomePerSecond(records), 1 + 5 * 12, 1e-9)
	T.expectNear(VaultRules.incomePerSecond({}), 0, 1e-9)
end)

T.test("reveal card carries the naming grammar and the catalog bio", function()
	local entry = Catalog.byId.corgi_loaf
	local card = VaultRules.revealCard({ uid = 1, chonkId = "corgi_loaf", tier = "Uncommon", size = 4 })
	T.expectEqual(card.displayName, "Loaf the HEFTYCHONK")
	T.expectEqual(card.species, entry.species)
	T.expectEqual(card.tier, "Uncommon")
	T.expectEqual(card.sizeStamp, "HEFTYCHONK")
	T.expectEqual(card.size, 4)
	T.expectEqual(card.bio, entry.bio)
	T.expectNear(card.incomePerSecond, 5 * 4, 1e-9)
end)

return {}
