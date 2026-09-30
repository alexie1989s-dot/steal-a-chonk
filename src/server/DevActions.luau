-- Registers the Studio-only DevHooks actions used by MCP verification (see the plan's DevHooks list).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Slots = require(ReplicatedStorage.Shared.Slots)
local Bat = require(script.Parent.Bat)
local Carry = require(script.Parent.Carry)
local DevHooks = require(script.Parent.DevHooks)
local DummyBase = require(script.Parent.DummyBase)
local Guardians = require(script.Parent.Guardians)
local Movement = require(script.Parent.Movement)
local Nests = require(script.Parent.Nests)
local PlayerState = require(script.Parent.PlayerState)
local Plots = require(script.Parent.Plots)
local Showcase = require(script.Parent.Showcase)
local Vault = require(script.Parent.Vault)

local DevActions = {}

local function playerNamed(name: string): Player
	local player = Players:FindFirstChild(name)
	if not (player and player:IsA("Player")) then
		error(`no player named {name}`)
	end
	return player
end
DevActions.playerNamed = playerNamed

-- Extra sections other services add to the "state" snapshot (nests, guardians).
local stateSections: { [string]: () -> any } = {}
function DevActions.addStateSection(name: string, fn: () -> any)
	stateSections[name] = fn
end

function DevActions.start()
	DevHooks.register("state", function()
		local players = {}
		for player, state in PlayerState.all() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local incubating = Slots.count(state.incubators)
			local showcase = {}
			for slot, item in state.showcase do
				showcase[tostring(slot)] = {
					kind = item.kind,
					status = item.status,
					tier = item.roll.tier,
					size = item.roll.size,
					remaining = Showcase.remaining(item) or false,
				}
			end
			players[player.Name] = {
				cash = state.cash,
				zoomies = state.zoomies,
				plot = state.plot,
				carrying = if state.carrying then state.carrying.roll.tier else false,
				inBase = state.inBase,
				vault = Slots.count(state.vault),
				incubating = incubating,
				showcase = showcase,
				immuneFor = math.max(state.immuneUntil - os.clock(), 0),
				dummyTaken = state.dummyTaken,
				walkSpeed = humanoid and humanoid.WalkSpeed or -1,
				position = root and { root.Position.X, root.Position.Y, root.Position.Z } or false,
			}
		end
		local snapshot: { [string]: any } = { players = players, timeScale = Config.Debug.timeScale }
		for name, fn in stateSections do
			snapshot[name] = fn()
		end
		return snapshot
	end)

	DevHooks.register("setZoomies", function(name: string, amount: number)
		local player = playerNamed(name)
		local state = PlayerState.get(player)
		if state then
			state.zoomies = amount
			PlayerState.sync(player)
			Movement.refresh(player)
		end
		return true
	end)

	DevHooks.register("teleport", function(name: string, x: number, z: number)
		local character = playerNamed(name).Character
		if character then
			character:PivotTo(CFrame.new(x, 4, z))
		end
		return true
	end)

	DevHooks.register("setTimeScale", function(scale: number)
		Config.Debug.timeScale = scale
		return true
	end)

	DevActions.addStateSection("nests", function()
		local list = {}
		for _, nest in Nests.all() do
			table.insert(list, {
				index = nest.index,
				status = if nest.burrito then nest.burrito.status else "empty",
				tier = if nest.burrito then nest.burrito.roll.tier else false,
			})
		end
		return list
	end)
	DevActions.addStateSection("items", function()
		local list = {}
		for _, item in Carry.items() do
			local p = item.model:GetPivot().Position
			table.insert(list, {
				id = item.id,
				kind = item.kind,
				status = item.status,
				tier = item.roll.tier,
				nest = item.nest or false,
				owner = if item.owner then item.owner.Name else false,
				carrier = if item.carrier then item.carrier.Name else false,
				dummy = item.dummy == true,
				position = { p.X, p.Y, p.Z },
			})
		end
		return list
	end)
	DevActions.addStateSection("dummy", function()
		local item = DummyBase.item()
		return if item then { id = item.id, status = item.status } else false
	end)
	DevActions.addStateSection("snapBacks", function()
		return Movement.snapBacks
	end)
	DevActions.addStateSection("batSwings", function()
		return Bat.swingsProcessed
	end)
	DevActions.addStateSection("guardians", function()
		local list = {}
		for _, guardian in Guardians.all() do
			local brain = guardian.brain
			table.insert(list, {
				index = guardian.index,
				mode = brain.mode,
				x = brain.x,
				z = brain.z,
				fromCentre = math.sqrt(brain.x * brain.x + brain.z * brain.z),
				speed = brain.speed,
			})
		end
		return list
	end)

	-- Teleports next to the nest (3 studs toward the district centre), then runs the real grab path.
	-- `stayPut` skips the teleport, to test that the server rejects out-of-reach grabs.
	DevHooks.register("grab", function(name: string, index: number, stayPut: boolean?)
		local player = playerNamed(name)
		local nest = Nests.all()[index]
		local character = player.Character
		if nest and character and not stayPut then
			local toCentre = Vector3.new(-nest.position.X, 0, -nest.position.Z).Unit
			character:PivotTo(CFrame.new(nest.position + toCentre * 3 + Vector3.new(0, 3, 0)))
		end
		return Nests.grab(player, index)
	end)

	-- Teleports beside a registered item (by id), then runs the real Grab prompt path.
	DevHooks.register("grabItem", function(name: string, id: number, stayPut: boolean?)
		local player = playerNamed(name)
		local item = Carry.items()[id]
		if not item then
			return false, "noItem"
		end
		local character = player.Character
		if character and not stayPut then
			character:PivotTo(CFrame.new(item.model:GetPivot().Position + Vector3.new(3, 3, 0)))
		end
		return Carry.grab(player, item)
	end)

	DevHooks.register("drop", function(name: string)
		return Carry.drop(playerNamed(name), "dev") ~= nil
	end)

	-- Teleports to an incubator on `plotIndex` (default: the player's own plot), then runs the real deposit path.
	DevHooks.register("deposit", function(name: string, plotIndex: number?, stayPut: boolean?)
		local player = playerNamed(name)
		local state = PlayerState.get(player)
		local target = plotIndex or (state and state.plot)
		if not target then
			return false, "noPlot"
		end
		local pad = Plots.part(target, "Incubator1")
		local character = player.Character
		if character and not stayPut then
			character:PivotTo(CFrame.new(pad.Position + Plots.frame(target).LookVector * 3 + Vector3.new(0, 3, 0)))
		end
		return Vault.deposit(player, target)
	end)

	-- Teleports beside the player's first free porch pad (Showcase1 when full), then runs the real place path.
	DevHooks.register("porch", function(name: string, stayPut: boolean?)
		local player = playerNamed(name)
		local state = PlayerState.get(player)
		if not (state and state.plot) then
			return false, "noPlot"
		end
		local slot = Slots.firstFree(state.showcase, Config.Showcase.slots) or 1
		local pad = Plots.part(state.plot, `Showcase{slot}`)
		local character = player.Character
		if character and not stayPut then
			character:PivotTo(CFrame.new(pad.Position + Plots.frame(state.plot).LookVector * -3 + Vector3.new(0, 3, 0)))
		end
		return Showcase.place(player, state.plot)
	end)

	-- Both move hooks teleport onto the player's porch first (the spawn point), unless `stayPut`.
	local function goHome(player: Player, stayPut: boolean?)
		local state = PlayerState.get(player)
		if player.Character and state and state.plot and not stayPut then
			player.Character:PivotTo(Plots.spawnCFrame(state.plot))
		end
	end
	DevHooks.register("toVault", function(name: string, slot: number, stayPut: boolean?)
		local player = playerNamed(name)
		goHome(player, stayPut)
		return Showcase.toVault(player, slot)
	end)
	DevHooks.register("toPorch", function(name: string, pad: number, stayPut: boolean?)
		local player = playerNamed(name)
		goHome(player, stayPut)
		return Showcase.toPorch(player, pad)
	end)

	-- Teleports to the lawn 3 studs in front of the porch pad (`plotIndex` 0 = the practice house), then runs
	-- the real steal path.
	DevHooks.register("steal", function(name: string, plotIndex: number, slot: number?, stayPut: boolean?)
		local player = playerNamed(name)
		local character = player.Character
		if plotIndex == 0 then
			if character and not stayPut then
				local pad = DummyBase.pad()
				character:PivotTo(CFrame.new(pad.Position + DummyBase.frame().LookVector * 3 + Vector3.new(0, 3, 0)))
			end
			return DummyBase.steal(player)
		end
		if character and not stayPut then
			local pad = Plots.part(plotIndex, `Showcase{slot or 1}`)
			character:PivotTo(CFrame.new(pad.Position + Plots.frame(plotIndex).LookVector * 3 + Vector3.new(0, 3, 0)))
		end
		return Showcase.steal(player, plotIndex, slot or 1)
	end)

	-- Studio-only victim seam: robs porch `slot` with no thief. Runs the real Stolen effects, then leaves the
	-- item loose on the lawn 6 studs in front of the porch (a burrito keeps its unwrap fraction).
	DevHooks.register("robMe", function(name: string, slot: number)
		local player = playerNamed(name)
		local state = PlayerState.get(player)
		local item = state and state.showcase[slot]
		if not (state and state.plot and item and item.status == "showcase") then
			return false, "empty"
		end
		local progress = if item.kind == "burrito" then Showcase.progressOf(item) else nil
		Showcase.unseat(item)
		item.progress = progress
		Showcase.Stolen:Fire(nil, player, item)
		local pad = Plots.part(state.plot, `Showcase{slot}`)
		local spot = pad.Position + Plots.frame(state.plot).LookVector * 6
		Carry.placeOnGround(item, spot.X, spot.Z)
		Carry.setStatus(item, "loose")
		item.looseAt = os.clock()
		return true
	end)

	DevHooks.register("fillVault", function(name: string)
		Vault.fill(playerNamed(name))
		return true
	end)
end

return DevActions
