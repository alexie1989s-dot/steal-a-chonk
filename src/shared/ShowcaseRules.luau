-- Porch Showcase rules (spec §10, §11, §18): placing, stealing, porch unwrap and income, returns, moves. Pure.
-- Refusal reasons match Strings.Toasts keys.
local Config = require("./Config")
local Formulas = require("./Formulas")
local Slots = require("./Slots")
local Strings = require("./Strings")
local VaultRules = require("./VaultRules")

local ShowcaseRules = {}

-- The porch slots a plot can actually use: never more than the pads that were built for it.
-- Spec 10 grows the porch to 8 slots, so Config may ask for more than the prototype builds.
function ShowcaseRules.usableSlots(configured: number, built: number): number
	return math.max(math.min(configured, built), 0)
end

export type PlaceContext = {
	carrying: string?, -- the carried item's kind, nil when empty-handed
	atOwnPlot: boolean,
	slots: { [number]: any }, -- porch slot -> occupant
	capacity: number, -- usable slots, from ShowcaseRules.usableSlots
}

-- Returns (true, slot) or (false, reason).
function ShowcaseRules.canPlace(ctx: PlaceContext): (boolean, any)
	if not ctx.carrying then
		return false, "notCarrying"
	end
	if not ctx.atOwnPlot then
		return false, "notYourBase"
	end
	local slot = Slots.firstFree(ctx.slots, ctx.capacity)
	if not slot then
		return false, "porchFull"
	end
	return true, slot
end

export type StealContext = {
	available: boolean, -- still on that porch slot and not already lifted
	isOwner: boolean,
	carrying: boolean,
	now: number,
	immuneUntil: number,
	isDummy: boolean,
	dummyTaken: boolean,
}

-- Availability first, so a lost race always reads "taken".
function ShowcaseRules.canSteal(ctx: StealContext): (boolean, string?)
	if not ctx.available then
		return false, "taken"
	end
	if ctx.isOwner then
		return false, "yours"
	end
	if ctx.carrying then
		return false, "alreadyCarrying"
	end
	if ctx.now < ctx.immuneUntil then
		return false, "immune"
	end
	if ctx.isDummy and ctx.dummyTaken then
		return false, "dummyDone"
	end
	return true
end

-- Server authority (§20): a Steal counts only if the server saw the hold last `holdSeconds`, less some jitter.
function ShowcaseRules.heldLongEnough(beganAt: number?, now: number, holdSeconds: number): boolean
	return beganAt ~= nil and now - beganAt >= holdSeconds - Config.Showcase.holdToleranceSeconds
end

-- Each player may keep one dummy-house Chonk per session.
function ShowcaseRules.canKeep(isDummy: boolean?, dummyTaken: boolean): (boolean, string?)
	if isDummy and dummyTaken then
		return false, "dummyDone"
	end
	return true
end

function ShowcaseRules.unwrapSeconds(tier: string, size: number, onPorch: boolean): number
	local seconds = Formulas.unwrapSeconds(tier, size)
	return if onPorch then seconds * Config.Showcase.unwrapFactor else seconds
end

-- Unwrap fraction done: what was done before, plus the time since this incubation started.
function ShowcaseRules.progressAt(progress: number, startedAt: number, duration: number, now: number): number
	return math.clamp(progress + math.max(now - startedAt, 0) / duration, 0, 1)
end

function ShowcaseRules.remainingSeconds(progress: number, duration: number): number
	return (1 - progress) * duration
end

-- Both maps may have holes. Porch Chonks earn Config.Showcase.incomeMultiplier times their Vault rate.
function ShowcaseRules.incomePerSecond(
	vault: { [number]: { tier: string, size: number } },
	porch: { [number]: { tier: string, size: number } }
): number
	return VaultRules.incomePerSecond(vault) + VaultRules.incomePerSecond(porch) * Config.Showcase.incomeMultiplier
end

-- Where a returning item goes: the porch first, then the Vault, else nowhere yet.
function ShowcaseRules.returnPlan(porchFree: number?, vaultFree: number?): (string?, number?)
	if porchFree then
		return "showcase", porchFree
	end
	if vaultFree then
		return "vault", vaultFree
	end
	return nil
end

-- Returns (true, slot) or (false, reason).
function ShowcaseRules.canMoveToPorch(ctx: { onOwnPlot: boolean, porchFree: number? }): (boolean, any)
	if not ctx.onOwnPlot then
		return false, "awayFromHome"
	end
	if not ctx.porchFree then
		return false, "porchFull"
	end
	return true, ctx.porchFree
end

function ShowcaseRules.canMoveToVault(
	ctx: { onOwnPlot: boolean, vaultCount: number, incubating: number }
): (boolean, string?)
	if not ctx.onOwnPlot then
		return false, "awayFromHome"
	end
	if not VaultRules.hasRoom(ctx.vaultCount, ctx.incubating) then
		return false, "vaultFull"
	end
	return true
end

-- (victim toast, thief toast) for a Chonk with this display name.
function ShowcaseRules.theftMessages(name: string): (string, string)
	return string.format(Strings.Theft.stolen, name, name), string.format(Strings.Theft.youStole, name)
end

return ShowcaseRules
