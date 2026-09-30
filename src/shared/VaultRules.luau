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

-- Incubating burritos reserve a display pad, so they count against the Vault's capacity.
function VaultRules.hasRoom(vaultCount: number, incubating: number): boolean
	return vaultCount + incubating < Config.Vault.displaySlots
end

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
	if not VaultRules.hasRoom(ctx.vaultCount, incubating) then
		return false, "vaultFull"
	end
	if not freeSlot then
		return false, "slotsBusy"
	end
	return true, freeSlot
end

export type StashContext = {
	carrying: boolean,
	atOwnIncubator: boolean,
	vaultCount: number,
	incubating: number,
}

-- A carried Chonk goes straight onto a display pad: it needs room, not a free incubator.
function VaultRules.canStash(ctx: StashContext): (boolean, string?)
	if not ctx.carrying then
		return false, "notCarrying"
	end
	if not ctx.atOwnIncubator then
		return false, "notYourBase"
	end
	if not VaultRules.hasRoom(ctx.vaultCount, ctx.incubating) then
		return false, "vaultFull"
	end
	return true
end

-- Records may be a list or a pad map with holes.
function VaultRules.incomePerSecond(records: { [number]: { tier: string, size: number } }): number
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
