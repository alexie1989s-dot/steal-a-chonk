-- Registers the Studio-only DevHooks actions used by MCP verification (see the plan's DevHooks list).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bat = require(script.Parent.Bat)
local Carry = require(script.Parent.Carry)
local DevHooks = require(script.Parent.DevHooks)
local Guardians = require(script.Parent.Guardians)
local Movement = require(script.Parent.Movement)
local Nests = require(script.Parent.Nests)
local PlayerState = require(script.Parent.PlayerState)
local Plots = require(script.Parent.Plots)
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
			local incubating = 0
			for _ in state.incubators do
				incubating += 1
			end
			players[player.Name] = {
				cash = state.cash,
				zoomies = state.zoomies,
				plot = state.plot,
				carrying = if state.carrying then state.carrying.roll.tier else false,
				inBase = state.inBase,
				vault = #state.vault,
				incubating = incubating,
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
	DevActions.addStateSection("burritos", function()
		local list = {}
		for _, burrito in Nests.burritos() do
			local p = burrito.model:GetPivot().Position
			table.insert(list, {
				id = burrito.id,
				nest = burrito.nest,
				status = burrito.status,
				tier = burrito.roll.tier,
				carrier = if burrito.carrier then burrito.carrier.Name else false,
				position = { p.X, p.Y, p.Z },
			})
		end
		return list
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

	DevHooks.register("fillVault", function(name: string)
		Vault.fill(playerNamed(name))
		return true
	end)
end

return DevActions
