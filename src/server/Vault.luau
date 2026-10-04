-- The Vault (spec §10): two incubators unwrap burritos into Chonks that earn cash forever.
-- Safe: nothing here can be stolen. Records live on display pads (state.vault[pad]). Session-only.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShowcaseRules = require(ReplicatedStorage.Shared.ShowcaseRules)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Slots = require(ReplicatedStorage.Shared.Slots)
local Strings = require(ReplicatedStorage.Shared.Strings)
local VaultRules = require(ReplicatedStorage.Shared.VaultRules)
local Carry = require(script.Parent.Carry)
local Models = require(script.Parent.Models)
local Notify = require(script.Parent.Notify)
local PlayerState = require(script.Parent.PlayerState)
local Plots = require(script.Parent.Plots)

type Incubation = {
	burrito: Carry.Item,
	startedAt: number,
	duration: number, -- full unwrap time, before Config.Debug.timeScale
	label: TextLabel,
}

local Vault = {
	MoveRequested = Signal.new(), -- (player, pad): the owner pressed "To Porch" on a Vault display
}

-- Display models by player, keyed by pad.
local displays: { [Player]: { [number]: Model } } = {}

local toast = Notify.toast

local function placeDisplay(player: Player, record: PlayerState.ChonkRecord, pad: number)
	local state = PlayerState.get(player)
	if not (state and state.plot) then
		return
	end
	local part = Plots.part(state.plot, `Display{pad}`)
	local entry = Catalog.byId[record.chonkId]
	local model = Models.chonk(entry, record.size)
	model.Name = `Chonk{record.uid}`
	local d = 4 * Formulas.sizeScale(record.size)
	local facing = Plots.frame(state.plot).Rotation
	model:PivotTo(CFrame.new(part.Position + Vector3.new(0, 0.15 + d / 2, 0)) * facing)

	local card = VaultRules.revealCard(record)
	Models.nameLabel(
		model,
		`{card.displayName}\n{string.format(Strings.Reveal.incomeFormat, Format.rate(card.incomePerSecond))}`,
		Models.rgb(Config.TierColors[record.tier]),
		d / 2 + 1.5,
		Config.Vault.labelDistance
	)

	local move = Instance.new("ProximityPrompt")
	move.Name = "MovePrompt"
	move.ActionText = Strings.Prompts.toPorch
	move.ObjectText = card.displayName
	move.HoldDuration = 0
	move.MaxActivationDistance = Config.Vault.promptDistance
	move.RequiresLineOfSight = false
	Plots.tagPrompt(move, state.plot, "owner")
	move.Parent = model.PrimaryPart
	move.Triggered:Connect(function(who: Player)
		if who == player then
			Vault.MoveRequested:Fire(player, pad)
		end
	end)

	model.Parent = Plots.model(state.plot)
	-- Tagged last, once it is posed and parented, so the client reads the right resting pose.
	-- A Vault display is a plain model rather than a Carry item, so it keeps the tag until it
	-- is destroyed; removeRecord destroys it, which drops the tag with it.
	CollectionService:AddTag(model, Config.Tags.chonkIdle)
	displays[player] = displays[player] or {}
	displays[player][pad] = model
end

-- The display pad a record would land on, or nil when every pad is taken. Callers check this before
-- they let go of an item: `addRecord` cannot refuse once the item has been taken and forgotten, and
-- nothing a player owns may be deleted (spec pillar: nothing owned is lost except by choice).
function Vault.freePad(player: Player): number?
	local state = PlayerState.get(player)
	if not state then
		return nil
	end
	return Slots.firstFree(state.vault, Config.Vault.displaySlots)
end

-- Puts a record on the first free display pad and shows it. Callers check room first
-- (Vault.freePad / VaultRules.hasRoom / canStash / ShowcaseRules.canMoveToVault).
-- Returns the pad, or nil when full.
function Vault.addRecord(player: Player, record: PlayerState.ChonkRecord): number?
	local state = PlayerState.get(player)
	if not state then
		return nil
	end
	local pad = Slots.firstFree(state.vault, Config.Vault.displaySlots)
	if not pad then
		return nil
	end
	state.vault[pad] = record
	placeDisplay(player, record, pad)
	PlayerState.sync(player)
	return pad
end

-- Takes a record off its pad and removes its display. Never yields.
function Vault.removeRecord(player: Player, pad: number): PlayerState.ChonkRecord?
	local state = PlayerState.get(player)
	local record = state and state.vault[pad]
	if not (state and record) then
		return nil
	end
	state.vault[pad] = nil
	local model = displays[player] and displays[player][pad]
	if model then
		model:Destroy()
		displays[player][pad] = nil
	end
	PlayerState.sync(player)
	return record
end

local function incubatingCount(state: PlayerState.State): number
	return Slots.count(state.incubators)
end

local function reveal(player: Player, slot: number, incubation: Incubation)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	-- An incubating burrito always has a pad reserved (VaultRules.hasRoom), so this finds one.
	local pad = Slots.firstFree(state.vault, Config.Vault.displaySlots)
	if not pad then
		state.incubators[slot] = incubation -- try again next tick rather than lose the Chonk
		return
	end
	local roll = incubation.burrito.roll
	local record = { uid = state.nextUid, chonkId = roll.chonkId, tier = roll.tier, size = roll.size }
	state.nextUid += 1
	state.vault[pad] = record
	incubation.label.Parent:Destroy()
	Carry.forget(incubation.burrito)
	placeDisplay(player, record, pad)
	PlayerState.sync(player)
	-- The display model goes along so the card can show the Chonk itself; it is already in the
	-- workspace, so it has replicated by the time the event arrives.
	Remotes.get("Reveal"):FireClient(player, VaultRules.revealCard(record), displays[player][pad])
end

-- Deposit path shared by the incubator prompts and DevHooks. `plotIndex` is where the player stands.
function Vault.deposit(player: Player, plotIndex: number): (boolean, string?)
	local state = PlayerState.get(player)
	if not state then
		return false, "noState"
	end
	-- Prompts are triggered by the client, so the server re-checks that an incubator is in reach (spec §20).
	local root = Carry.rootOf(player)
	local reach = Config.Vault.promptDistance + Config.AntiCheat.reachTolerance
	local inReach = false
	for slot = 1, Config.Vault.incubators do
		local pad = Plots.part(plotIndex, `Incubator{slot}`)
		if root and pad and (root.Position - pad.Position).Magnitude <= reach then
			inReach = true
		end
	end
	if not inReach then
		return false, "tooFar"
	end
	local carried = state.carrying
	local keep, keepReason = ShowcaseRules.canKeep(carried and carried.dummy, state.dummyTaken)
	if not keep then
		toast(player, keepReason :: string)
		return false, keepReason
	end
	local atOwnIncubator = state.plot ~= nil and state.plot == plotIndex

	-- A carried Chonk (stolen or practice) goes straight onto a display pad.
	if carried and carried.kind == "chonk" then
		local ok, reason = VaultRules.canStash({
			carrying = true,
			atOwnIncubator = atOwnIncubator,
			vaultCount = Slots.count(state.vault),
			incubating = incubatingCount(state),
		})
		if not ok then
			toast(player, reason :: string)
			return false, reason
		end
		-- Checked before the Chonk leaves the player's hands: nothing below yields, so the pad is still free.
		if not Vault.freePad(player) then
			toast(player, "vaultFull")
			return false, "vaultFull"
		end
		local item = Carry.take(player) :: Carry.Item
		Carry.adopt(player, item)
		Vault.addRecord(
			player,
			{ uid = item.uid :: number, chonkId = item.roll.chonkId, tier = item.roll.tier, size = item.roll.size }
		)
		Carry.forget(item)
		toast(player, "stashed")
		return true
	end

	local ok, result = VaultRules.canDeposit({
		carrying = carried ~= nil,
		atOwnIncubator = atOwnIncubator,
		incubators = state.incubators,
		vaultCount = Slots.count(state.vault),
	})
	if not ok then
		toast(player, result)
		return false, result
	end
	local burrito = Carry.take(player)
	if not burrito then
		return false, "notCarrying"
	end
	Carry.adopt(player, burrito)
	Vault.startIncubation(player, result :: number, burrito)
	toast(player, "unwrapping")
	return true
end

-- Puts a taken burrito into incubator `slot`, resuming from `burrito.progress` (a stolen porch burrito keeps
-- its unwrap fraction).
function Vault.startIncubation(player: Player, slot: number, burrito: Carry.Item)
	local state = PlayerState.get(player) :: PlayerState.State
	Carry.setStatus(burrito, "incubating")
	local pad = Plots.part(state.plot :: number, `Incubator{slot}`)
	burrito.model:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 2.2, 0)))
	-- A stolen burrito arrives parented wherever it was carried from, so move it under this plot.
	burrito.model.Parent = Plots.model(state.plot :: number)
	state.incubators[slot] = {
		burrito = burrito,
		startedAt = os.clock(),
		duration = Formulas.unwrapSeconds(burrito.roll.tier, burrito.roll.size),
		label = Models.progressLabel(pad),
	}
end

-- `size` is for Studio checks: filling with the largest size is how pad spacing gets tested.
function Vault.fill(player: Player, size: number?)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	-- Leave room for burritos already incubating: they each need a display pad when they hatch.
	while VaultRules.hasRoom(Slots.count(state.vault), incubatingCount(state)) do
		local pad = Slots.firstFree(state.vault, Config.Vault.displaySlots) :: number
		local record = { uid = state.nextUid, chonkId = "cat_beans", tier = "Common", size = size or 1 }
		state.nextUid += 1
		state.vault[pad] = record
		placeDisplay(player, record, pad)
	end
	PlayerState.sync(player)
end

function Vault.start()
	for plotIndex = 1, Plots.count() do
		for slot = 1, Config.Vault.incubators do
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "UnwrapPrompt"
			prompt.ActionText = Strings.Prompts.vaultDeposit
			prompt.ObjectText = Strings.Prompts.incubatorObject
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = Config.Vault.promptDistance
			prompt.RequiresLineOfSight = false
			Plots.tagPrompt(prompt, plotIndex, "owner")
			prompt.Parent = Plots.part(plotIndex, `Incubator{slot}`)
			prompt.Triggered:Connect(function(player: Player)
				Vault.deposit(player, plotIndex)
			end)
		end
	end

	PlayerState.Removing:Connect(function(player: Player)
		local state = PlayerState.get(player)
		if state then
			for _, incubation: Incubation in state.incubators do
				incubation.label.Parent:Destroy()
				Carry.forget(incubation.burrito)
			end
		end
		for _, model in displays[player] or {} do
			model:Destroy()
		end
		displays[player] = nil
	end)

	-- Unwrap timers and progress labels.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now, scale = os.clock(), Config.Debug.timeScale
			for player, state in PlayerState.all() do
				for slot, incubation: Incubation in table.clone(state.incubators) do
					local duration = incubation.duration * scale
					local remaining = ShowcaseRules.remainingSeconds(
						ShowcaseRules.progressAt(incubation.burrito.progress or 0, incubation.startedAt, duration, now),
						duration
					)
					if remaining <= 0 then
						-- Own thread: an error in one reveal must not stop every other incubator.
						state.incubators[slot] = nil
						task.spawn(reveal, player, slot, incubation)
					else
						incubation.label.Text = `{math.ceil(remaining)}s`
					end
				end
			end
		end
	end)

	-- Income: every Vault and porch Chonk earns every second (spec §5 step 6); the porch earns +50 % (§10).
	task.spawn(function()
		local period = Config.Economy.incomeTickSeconds
		while true do
			task.wait(period)
			for player, state in PlayerState.all() do
				local porch = {}
				for slot, item in state.showcase do
					if item.kind == "chonk" then
						porch[slot] = item.roll
					end
				end
				if next(state.vault) or next(porch) then
					state.cash += ShowcaseRules.incomePerSecond(state.vault, porch) * period
					PlayerState.sync(player)
				end
			end
		end
	end)
end

return Vault
