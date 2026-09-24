-- Vault rules (spec §5, §10): who may deposit, what the Vault earns, what the reveal card shows. Pure.
local Catalog = require("./Catalog")
local Config = require("./Config")
local Formulas = require("./Formulas")
local Naming = require("./Naming")

local VaultRules = {}

export type DepositContext = {
	carrying: boolean,
	atOwnIncubator: boolean,
	incubators: { [number]: any }, -- slot -> incubation in progress
	vaultCount: number,
}

-- Returns (true, slot) or (false, reason). Reasons match Strings.Toasts keys.
function VaultRules.canDeposit(ctx: DepositContext): (boolean, any)
	if not ctx.carrying then
		return false, "notCarrying"
	end
	if not ctx.atOwnIncubator then
		return false, "notYourBase"
	end
	local incubating, freeSlot = 0, nil
	for slot = 1, Config.Vault.incubators do
		if ctx.incubators[slot] then
			incubating += 1
		elseif not freeSlot then
			freeSlot = slot
		end
	end
	if ctx.vaultCount + incubating >= Config.Vault.displaySlots then
		return false, "vaultFull"
	end
	if not freeSlot then
		return false, "slotsBusy"
	end
	return true, freeSlot
end

function VaultRules.incomePerSecond(records: { { tier: string, size: number } }): number
	local total = 0
	for _, record in records do
		total += Formulas.incomePerSecond(record.tier, record.size)
	end
	return total
end

export type RevealCard = {
	displayName: string,
	species: string,
	tier: string,
	sizeStamp: string,
	size: number,
	bio: string,
	incomePerSecond: number,
}

function VaultRules.revealCard(record: { chonkId: string, tier: string, size: number }): RevealCard
	local entry = Catalog.byId[record.chonkId]
	return {
		displayName = Naming.displayName(entry, record.size, nil),
		species = entry.species,
		tier = record.tier,
		sizeStamp = Naming.sizeStamp(record.size),
		size = record.size,
		bio = entry.bio,
		incomePerSecond = Formulas.incomePerSecond(record.tier, record.size),
	}
end

return VaultRules
