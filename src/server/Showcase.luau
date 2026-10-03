-- The porch Showcase (spec §10, §11): two raidable slots in front of each house. Burritos unwrap here
-- faster, Chonks earn +50 %, and the owner moves Chonks between porch and Vault while standing at home.
-- A theft sets off the victim's alarm and raid cooldown; nothing is ever deleted while its owner is here
-- (dropped items walk home, and an item whose carrier leaves goes straight back).
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
local PlayerState = require(script.Parent.PlayerState)
local Plots = require(script.Parent.Plots)
local Vault = require(script.Parent.Vault)

type Item = Carry.Item

-- Runtime details of an item sitting on a porch slot.
type Seat = {
	owner: Player,
	plot: number,
	slot: number,
	startedAt: number?, -- burritos: when this porch incubation (re)started
	duration: number?, -- burritos: full porch unwrap time, before Config.Debug.timeScale
	label: TextLabel?, -- burritos: countdown above the pad
}

local Showcase = {
	Stolen = Signal.new(), -- (thief: Player?, victim: Player?, item: Item)
}

local seats: { [Item]: Seat } = {}
local alarms: { [number]: number } = {} -- plot -> token of the alarm currently blinking
-- Never reused, so an alarm cancelled by its owner leaving cannot be mistaken for the next one on
-- that plot: a restarted count would hand the new alarm a token an older thread still believes is its own.
local nextAlarmToken = 1

local ALARM_RED = Color3.fromRGB(255, 40, 40)
local ALARM_DARK = Color3.fromRGB(130, 10, 10)

local function toast(player: Player, key: string)
	local text = Strings.Toasts[key]
	if text then
		Remotes.get("Toast"):FireClient(player, text)
	end
end

-- One step of a background loop, isolated: a single bad item must not stop the loop for the session.
local reported: { [string]: true } = {} -- each distinct fault is warned about once, not four times a second
local function guarded(what: string, fn: (...any) -> ...any, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		local line = `[Showcase] {what} failed: {err}`
		if not reported[line] then
			reported[line] = true
			warn(`{line} (reported once)`)
		end
	end
end

local function padOf(plotIndex: number, slot: number): BasePart
	return Plots.part(plotIndex, `Showcase{slot}`)
end

-- Porch slots a plot can really use. Config.Showcase.slots is the design number (§10 grows it to 8);
-- the pads Plots builds are the limit, and asking for more used to error at boot on `Showcase3`.
function Showcase.slots(): number
	return ShowcaseRules.usableSlots(Config.Showcase.slots, Plots.showcasePads())
end

-- The "Put here" prompt exists only on empty pads; audience prompts are created and destroyed, never toggled.
local function setPlacePrompt(plotIndex: number, slot: number, present: boolean)
	local pad = padOf(plotIndex, slot)
	local existing = pad:FindFirstChild("PlacePrompt")
	if not present then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlacePrompt"
	prompt.ActionText = Strings.Prompts.place
	prompt.ObjectText = Strings.Prompts.porchObject
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Showcase.placeDistance
	prompt.RequiresLineOfSight = false
	Plots.tagPrompt(prompt, plotIndex, "owner")
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player: Player)
		Showcase.place(player, plotIndex, slot)
	end)
end

local function record(item: Item): PlayerState.ChonkRecord
	return { uid = item.uid :: number, chonkId = item.roll.chonkId, tier = item.roll.tier, size = item.roll.size }
end

local function porchCard(item: Item)
	local card = VaultRules.revealCard(record(item))
	card.incomePerSecond *= Config.Showcase.incomeMultiplier
	return card
end

-- Seconds of porch unwrap left for a burrito on a porch, scaled by Config.Debug.timeScale.
function Showcase.remaining(item: Item): number?
	local seat = seats[item]
	if not (seat and seat.startedAt and seat.duration) then
		return nil
	end
	local duration = seat.duration * Config.Debug.timeScale
	local progress = ShowcaseRules.progressAt(item.progress or 0, seat.startedAt, duration, os.clock())
	return ShowcaseRules.remainingSeconds(progress, duration)
end

-- Unwrap fraction done so far, for a burrito leaving the porch.
function Showcase.progressOf(item: Item): number
	local seat = seats[item]
	if not (seat and seat.startedAt and seat.duration) then
		return item.progress or 0
	end
	return ShowcaseRules.progressAt(
		item.progress or 0,
		seat.startedAt,
		seat.duration * Config.Debug.timeScale,
		os.clock()
	)
end

-- A Steal prompt (not yet parented). The client enforces the hold, but so does the server (spec §20): the
-- trigger counts only after the server has seen the button held for the full duration.
function Showcase.newStealPrompt(objectText: string, onSteal: (Player) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = Strings.Prompts.steal
	prompt.ObjectText = objectText
	prompt.HoldDuration = Config.Showcase.stealHoldSeconds
	prompt.MaxActivationDistance = Config.Showcase.placeDistance
	prompt.RequiresLineOfSight = false
	local began: { [Player]: number } = {}
	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		began[player] = os.clock()
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player: Player)
		-- Released early: forget the hold. A completed hold is kept whichever event arrives first.
		if not ShowcaseRules.heldLongEnough(began[player], os.clock(), prompt.HoldDuration) then
			began[player] = nil
		end
	end)
	prompt.Triggered:Connect(function(player: Player)
		local at = began[player]
		began[player] = nil
		if ShowcaseRules.heldLongEnough(at, os.clock(), prompt.HoldDuration) then
			onSteal(player)
		end
	end)
	return prompt
end

-- Places an item on a porch slot, positions it and adds its prompts and labels. Never yields.
local function seatItem(owner: Player, plotIndex: number, slot: number, item: Item)
	local state = PlayerState.get(owner) :: PlayerState.State
	local pad = padOf(plotIndex, slot)
	local scale = Formulas.sizeScale(item.roll.size)
	local top = pad.Position.Y + 0.15
	local facing = Plots.frame(plotIndex).Rotation
	local seat: Seat = { owner = owner, plot = plotIndex, slot = slot }
	if item.kind == "burrito" then
		item.model:PivotTo(CFrame.new(pad.Position.X, top + 1.1 * scale, pad.Position.Z) * facing)
		seat.startedAt = os.clock()
		seat.duration = ShowcaseRules.unwrapSeconds(item.roll.tier, item.roll.size, true)
		seat.label = Models.progressLabel(pad)
	else
		local d = 4 * scale
		item.model:PivotTo(CFrame.new(pad.Position.X, top + d / 2, pad.Position.Z) * facing)
		local card = porchCard(item)
		Models.nameLabel(
			item.model,
			`{card.displayName}\n{string.format(Strings.Reveal.incomeFormat, Format.rate(card.incomePerSecond))}`,
			Models.rgb(Config.TierColors[item.roll.tier]),
			d / 2 + 1.5
		)
		local move = Instance.new("ProximityPrompt")
		move.Name = "MovePrompt"
		move.ActionText = Strings.Prompts.toVault
		move.ObjectText = card.displayName
		move.HoldDuration = 0
		move.MaxActivationDistance = Config.Showcase.placeDistance
		move.RequiresLineOfSight = false
		Plots.tagPrompt(move, plotIndex, "owner")
		move.Parent = item.model.PrimaryPart
		move.Triggered:Connect(function(player: Player)
			if player == owner and state.showcase[slot] == item then
				Showcase.toVault(player, slot)
			end
		end)
	end
	local steal = Showcase.newStealPrompt(
		if item.kind == "burrito" then Strings.Prompts.grabObject else Strings.Prompts.chonkObject,
		function(player: Player)
			Showcase.steal(player, plotIndex, slot)
		end
	)
	Plots.tagPrompt(steal, plotIndex, "others")
	steal.Parent = item.model.PrimaryPart

	item.owner = owner
	Carry.setStatus(item, "showcase")
	state.showcase[slot] = item
	seats[item] = seat
	setPlacePrompt(plotIndex, slot, false)
	item.model.Parent = Plots.model(plotIndex)
end

-- Clears a porch slot: labels, prompts and bookkeeping. The item itself is left to the caller. Never yields.
local function unseat(item: Item)
	local seat = seats[item]
	if not seat then
		return
	end
	seats[item] = nil
	if seat.label then
		seat.label.Parent:Destroy()
	end
	local body = item.model.PrimaryPart
	for _, name in { "MovePrompt", "StealPrompt", "NameTag" } do
		local child = body and body:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
	local state = PlayerState.get(seat.owner)
	if state and state.showcase[seat.slot] == item then
		state.showcase[seat.slot] = nil
	end
	-- Always restored, even when the owner is leaving: the plot's next owner needs it.
	setPlacePrompt(seat.plot, seat.slot, true)
end
Showcase.unseat = unseat

-- A registered Chonk item for a record, not yet seated or parented.
local function chonkItem(owner: Player?, rec: PlayerState.ChonkRecord): Item
	return Carry.register({
		kind = "chonk",
		roll = { chonkId = rec.chonkId, tier = rec.tier, size = rec.size },
		model = Models.chonk(Catalog.byId[rec.chonkId], rec.size),
		status = "showcase",
		owner = owner,
		uid = rec.uid,
	})
end
Showcase.chonkItem = chonkItem

local function nearPorch(player: Player, plotIndex: number): boolean
	local root = Carry.rootOf(player)
	if not root then
		return false
	end
	local reach = Config.Showcase.placeDistance + Config.AntiCheat.reachTolerance
	for slot = 1, Showcase.slots() do
		if (root.Position - padOf(plotIndex, slot).Position).Magnitude <= reach then
			return true
		end
	end
	return false
end

-- Puts the carried item on the porch of `plotIndex`: the pad `preferred` when it is free, else the first free
-- slot. Burritos unwrap in place; Chonks go on show.
function Showcase.place(player: Player, plotIndex: number, preferred: number?): (boolean, string?)
	local state = PlayerState.get(player)
	if not state then
		return false, "noState"
	end
	-- Prompts are triggered by the client, so the server re-checks reach (spec §20).
	if not nearPorch(player, plotIndex) then
		return false, "tooFar"
	end
	local keep, keepReason = ShowcaseRules.canKeep(state.carrying and state.carrying.dummy, state.dummyTaken)
	if not keep then
		toast(player, keepReason :: string)
		return false, keepReason
	end
	local ok, result = ShowcaseRules.canPlace({
		carrying = if state.carrying then state.carrying.kind else nil,
		atOwnPlot = state.plot ~= nil and state.plot == plotIndex,
		slots = state.showcase,
		capacity = Showcase.slots(),
	})
	if not ok then
		toast(player, result)
		return false, result
	end
	local slot = result :: number
	if preferred and preferred >= 1 and preferred <= Showcase.slots() and state.showcase[preferred] == nil then
		slot = preferred
	end
	local item = Carry.take(player)
	if not item then
		return false, "notCarrying"
	end
	Carry.adopt(player, item)
	seatItem(player, plotIndex, slot, item)
	toast(player, "onPorch")
	return true
end

-- Moves a porch Chonk into the Vault. Returns (true, pad) or (false, reason). Never yields, so a steal
-- that completes in the same frame sees the slot already empty.
function Showcase.toVault(player: Player, slot: number): (boolean, any)
	local state = PlayerState.get(player)
	if not (state and state.plot) then
		return false, "noPlot"
	end
	local item = state.showcase[slot]
	if not (item and item.kind == "chonk" and item.status == "showcase") then
		return false, "empty"
	end
	local ok, reason = ShowcaseRules.canMoveToVault({
		onOwnPlot = Plots.isOnPlot(player, state.plot),
		vaultCount = Slots.count(state.vault),
		incubating = Slots.count(state.incubators),
	})
	if not ok then
		toast(player, reason :: string)
		return false, reason
	end
	-- Checked before the Chonk leaves the porch: unseating and forgetting it cannot be undone, and
	-- `addRecord` has no way to refuse by then. Nothing below yields, so the pad is still free.
	if not Vault.freePad(player) then
		toast(player, "vaultFull")
		return false, "vaultFull"
	end
	unseat(item)
	local rec = record(item)
	Carry.forget(item)
	local pad = Vault.addRecord(player, rec)
	toast(player, "stashed")
	return true, pad
end

-- Moves a Vault Chonk onto the porch. Returns (true, slot) or (false, reason).
function Showcase.toPorch(player: Player, pad: number): (boolean, any)
	local state = PlayerState.get(player)
	if not (state and state.plot) then
		return false, "noPlot"
	end
	if not state.vault[pad] then
		return false, "empty"
	end
	local ok, result = ShowcaseRules.canMoveToPorch({
		onOwnPlot = Plots.isOnPlot(player, state.plot),
		porchFree = Slots.firstFree(state.showcase, Showcase.slots()),
	})
	if not ok then
		toast(player, result)
		return false, result
	end
	local slot = result :: number
	local rec = Vault.removeRecord(player, pad) :: PlayerState.ChonkRecord
	seatItem(player, state.plot, slot, chonkItem(player, rec))
	toast(player, "onPorch")
	return true, slot
end

-- Steals the item on `slot` of `plotIndex`'s porch (spec §11). Availability is checked first and the pick-up
-- never yields, so of two thieves (or a thief and the owner moving it) finishing in the same frame exactly one wins.
function Showcase.steal(player: Player, plotIndex: number, slot: number): (boolean, string?)
	local state = PlayerState.get(player)
	if not state then
		return false, "noState"
	end
	local owner = Plots.ownerOf(plotIndex)
	local ownerState = owner and PlayerState.get(owner)
	local item = ownerState and ownerState.showcase[slot]
	local ok, reason = ShowcaseRules.canSteal({
		available = item ~= nil and item.status == "showcase",
		isOwner = owner == player,
		carrying = state.carrying ~= nil,
		now = os.clock(),
		immuneUntil = if ownerState then ownerState.immuneUntil else 0,
		isDummy = false,
		dummyTaken = state.dummyTaken,
	})
	if not ok then
		toast(player, reason :: string)
		return false, reason
	end
	local taken = item :: Item
	local progress = if taken.kind == "burrito" then Showcase.progressOf(taken) else nil
	ok, reason = Carry.pickUp(player, taken)
	if not ok then
		toast(player, reason :: string)
		return false, reason
	end
	unseat(taken)
	taken.progress = progress
	Showcase.Stolen:Fire(player, owner, taken)
	return true
end

-- The name theft toasts use: the Catalog name for a Chonk. A burrito keeps its surprise.
local function itemName(item: Item): string
	if item.kind == "chonk" then
		return Catalog.byId[item.roll.chonkId].name
	end
	return Strings.Prompts.grabObject
end

local function toastText(player: Player, text: string)
	Remotes.get("Toast"):FireClient(player, text)
end

local function setPorchLights(plotIndex: number, color: Color3)
	for _, part in Plots.model(plotIndex):GetChildren() do
		if part.Name == "PorchLight" and part:IsA("BasePart") then
			part.Color = color
			local glow = part:FindFirstChildOfClass("PointLight")
			if glow then
				glow.Color = color
			end
		end
	end
end

-- Blinks the porch lights red for Config.Showcase.alarmSeconds (real seconds), then restores them.
local function soundAlarm(plotIndex: number)
	local token = nextAlarmToken
	nextAlarmToken += 1
	alarms[plotIndex] = token
	task.spawn(function()
		local stopAt = os.clock() + Config.Showcase.alarmSeconds
		local bright = true
		while os.clock() < stopAt and alarms[plotIndex] == token do
			setPorchLights(plotIndex, if bright then ALARM_RED else ALARM_DARK)
			bright = not bright
			task.wait(0.25)
		end
		if alarms[plotIndex] == token then
			setPorchLights(plotIndex, Plots.PORCH_LIGHT)
		end
	end)
end

-- The victim's side of a theft (§11, §18): raid cooldown, alarm lights and both theft toasts.
local function onStolen(thief: Player?, victim: Player?, item: Item)
	local victimText, thiefText = ShowcaseRules.theftMessages(itemName(item))
	if victim then
		local state = PlayerState.get(victim)
		if state then
			state.immuneUntil = os.clock() + Config.Showcase.raidCooldownSeconds * Config.Debug.timeScale
			if state.plot then
				soundAlarm(state.plot)
			end
		end
		toastText(victim, victimText)
	end
	if thief then
		toastText(thief, thiefText)
	end
end

-- Sends a loose owned item home: the porch first, then the Vault (a pad for a Chonk, an incubator for a
-- burrito, which resumes its unwrap). Returns false when there is no room yet; the caller retries later.
function Showcase.returnToOwner(item: Item): boolean
	local owner = item.owner
	local state = owner and PlayerState.get(owner)
	if not (owner and state and state.plot and item.status == "loose") then
		return false
	end
	local porchFree = Slots.firstFree(state.showcase, Showcase.slots())
	local vaultFree = nil
	if VaultRules.hasRoom(Slots.count(state.vault), Slots.count(state.incubators)) then
		vaultFree = if item.kind == "chonk"
			then Vault.freePad(owner)
			else Slots.firstFree(state.incubators, Config.Vault.incubators)
	end
	local where, slot = ShowcaseRules.returnPlan(porchFree, vaultFree)
	if not (where and slot) then
		return false
	end
	if where == "showcase" then
		seatItem(owner, state.plot, slot, item)
	elseif item.kind == "chonk" then
		-- On its pad before it is forgotten: a Vault that filled up leaves the Chonk lying there to
		-- try again, rather than deleting it.
		if not Vault.addRecord(owner, record(item)) then
			return false
		end
		Carry.forget(item)
	else
		Vault.startIncubation(owner, slot, item)
	end
	item.looseAt = nil
	toastText(owner, string.format(Strings.Theft.cameBack, itemName(item)))
	return true
end

-- The owner is leaving: the prototype is session-only, so their items leave with them (spec §11
-- "returns to the victim's inventory"). A thief carrying one loses it and is told why.
local function ownerLeaves(player: Player)
	local state = PlayerState.get(player)
	if state then
		for _, item in table.clone(state.showcase) do
			unseat(item)
			Carry.forget(item)
		end
	end
	for _, item in table.clone(Carry.items()) do
		if item.owner == player then
			local carrier = item.carrier
			if item.status == "carried" and carrier and carrier ~= player then
				Carry.take(carrier)
				local name = itemName(item)
				toastText(carrier, string.format(Strings.Theft.wentHome, name, name))
			end
			Carry.forget(item)
		end
	end
	if state and state.plot then
		alarms[state.plot] = nil
		setPorchLights(state.plot, Plots.PORCH_LIGHT)
	end
end

-- A porch burrito finished: it becomes a Chonk on the same slot and the owner gets the reveal card.
local function reveal(item: Item)
	local seat = seats[item]
	local state = seat and PlayerState.get(seat.owner)
	if not (seat and state) then
		return
	end
	unseat(item)
	Carry.forget(item)
	local rec = {
		uid = state.nextUid,
		chonkId = item.roll.chonkId,
		tier = item.roll.tier,
		size = item.roll.size,
	}
	state.nextUid += 1
	local chonk = chonkItem(seat.owner, rec)
	seatItem(seat.owner, seat.plot, seat.slot, chonk)
	Remotes.get("Reveal"):FireClient(seat.owner, porchCard(chonk))
end

-- The raid-cooldown sign above a porch, counting down while its owner is immune.
local function updateCooldownSign(plotIndex: number, now: number)
	local owner = Plots.ownerOf(plotIndex)
	local state = owner and PlayerState.get(owner)
	local left = if state then state.immuneUntil - now else 0
	local gui = Plots.part(plotIndex, "CooldownSign"):FindFirstChildOfClass("BillboardGui")
	local text = gui and gui:FindFirstChild("Text") :: TextLabel?
	if gui and text then
		gui.Enabled = left > 0
		if left > 0 then
			text.Text = string.format(Strings.Showcase.raidCooldown, Format.clock(left))
		end
	end
end

-- One porch burrito's countdown label, or its reveal once the unwrap is done.
local function tickPorchUnwrap(item: Item, seat: Seat)
	local left = Showcase.remaining(item) :: number
	if left <= 0 then
		reveal(item)
	else
		(seat.label :: TextLabel).Text = `{math.ceil(left)}s`
	end
end

function Showcase.start()
	if Config.Showcase.slots > Plots.showcasePads() then
		warn(
			`[Showcase] Config.Showcase.slots is {Config.Showcase.slots} but Plots builds `
				.. `{Plots.showcasePads()} porch pads; using {Showcase.slots()}.`
		)
	end
	for plotIndex = 1, Plots.count() do
		for slot = 1, Showcase.slots() do
			setPlacePrompt(plotIndex, slot, true)
		end
	end

	Vault.MoveRequested:Connect(function(player: Player, pad: number)
		Showcase.toPorch(player, pad)
	end)
	Showcase.Stolen:Connect(onStolen)
	PlayerState.Removing:Connect(ownerLeaves)

	-- A carrier who leaves hands an owned item straight back (the practice Chonk is DummyBase's).
	Carry.Dropped:Connect(function(item: Item, carrier: Player, reason: string)
		if reason == "left" and item.owner and item.owner ~= carrier and not item.dummy then
			Showcase.returnToOwner(item)
		end
	end)

	-- Owned items left untouched walk home; with no room they wait and try again every tick.
	-- The raid-cooldown sign above each porch counts down while its owner is immune.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now, scale = os.clock(), Config.Debug.timeScale
			for _, item in table.clone(Carry.items()) do
				if
					item.owner
					and not item.dummy
					and item.status == "loose"
					and item.looseAt
					and now - item.looseAt >= Config.Nest.looseReturnSeconds * scale
				then
					guarded("return", Showcase.returnToOwner, item)
				end
			end
			for index = 1, Plots.count() do
				guarded("cooldown sign", updateCooldownSign, index, now)
			end
		end
	end)

	-- Porch unwrap timers and countdown labels.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for item, seat in table.clone(seats) do
				if item.kind == "burrito" and seat.label then
					guarded("porch unwrap", tickPorchUnwrap, item, seat)
				end
			end
		end
	end)
end

return Showcase
