-- Carrying a burrito home (spec §5, §7, §11). The server decides every pickup, drop and hand-off.
-- A dropped burrito lies where it fell and anyone may pick it up, the dropper included.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Movement = require(script.Parent.Movement)
local PlayerState = require(script.Parent.PlayerState)

export type Burrito = {
	id: number,
	nest: number,
	roll: { chonkId: string, tier: string, size: number },
	model: Model,
	status: "ready" | "carried" | "loose" | "incubating",
	carrier: Player?,
	looseAt: number?,
}

local Carry = {
	PickedUp = Signal.new(), -- (player, burrito)
	Dropped = Signal.new(), -- (burrito, player, reason)
	CrossedHome = Signal.new(), -- (player, burrito)
}

local CARRY_WELD = "CarryWeld"

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end
Carry.rootOf = rootOf

local function setPhysics(model: Model, anchored: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
			part.CanCollide = false
			part.Massless = not anchored
		end
	end
end

local function detach(burrito: Burrito)
	local body = burrito.model.PrimaryPart
	local weld = body and body:FindFirstChild(CARRY_WELD)
	if weld then
		weld:Destroy()
	end
	setPhysics(burrito.model, true)
end

-- Rests a burrito on the ground at (x, z).
function Carry.placeOnGround(burrito: Burrito, x: number, z: number)
	local height = 0.5 + 1.1 * Formulas.sizeScale(burrito.roll.size)
	burrito.model:PivotTo(CFrame.new(x, height, z))
end

function Carry.pickUp(player: Player, burrito: Burrito): (boolean, string?)
	local state = PlayerState.get(player)
	if not state then
		return false, "noState"
	end
	-- Status first: the check and the claim below never yield, so two simultaneous grabs cannot both win.
	if burrito.status ~= "ready" and burrito.status ~= "loose" then
		return false, "taken"
	end
	if state.carrying then
		return false, "alreadyCarrying"
	end
	local root = rootOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid and humanoid.Health > 0) then
		return false, "noCharacter"
	end
	-- Prompts are triggered by the client, so the server re-checks reach (spec §20).
	local at = burrito.model:GetPivot().Position
	if
		Layout.planarDistance(root.Position.X, root.Position.Z, at.X, at.Z)
		> Config.Nest.grabDistance + Config.AntiCheat.reachTolerance
	then
		return false, "tooFar"
	end

	burrito.status = "carried"
	burrito.carrier = player
	burrito.looseAt = nil
	state.carrying = burrito

	local model = burrito.model
	model:PivotTo(root.CFrame * CFrame.new(0, 3.6, 0))
	setPhysics(model, false)
	local weld = Instance.new("WeldConstraint")
	weld.Name = CARRY_WELD
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart

	Movement.refresh(player)
	PlayerState.sync(player)
	Carry.PickedUp:Fire(player, burrito)
	return true
end

-- Drops the carried burrito at the carrier's feet. Returns it, or nil if nothing was carried.
function Carry.drop(player: Player, reason: string): Burrito?
	local state = PlayerState.get(player)
	local burrito = state and state.carrying
	if not (state and burrito) then
		return nil
	end
	local root = rootOf(player)
	local position = if root then root.Position else burrito.model:GetPivot().Position
	state.carrying = nil
	detach(burrito)
	Carry.placeOnGround(burrito, position.X, position.Z)
	burrito.status = "loose"
	burrito.carrier = nil
	burrito.looseAt = os.clock()

	Movement.refresh(player)
	PlayerState.sync(player)
	Carry.Dropped:Fire(burrito, player, reason)
	return burrito
end

-- Removes the carried burrito from the player without dropping it (the Vault takes it).
function Carry.take(player: Player): Burrito?
	local state = PlayerState.get(player)
	local burrito = state and state.carrying
	if not (state and burrito) then
		return nil
	end
	state.carrying = nil
	detach(burrito)
	burrito.carrier = nil
	Movement.refresh(player)
	PlayerState.sync(player)
	return burrito
end

function Carry.inField(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	return not Layout.isInBase(root.Position.X, root.Position.Z)
end

-- Tells a client to fly back from `from` (spec §7: "knocked back").
function Carry.knockback(player: Player, from: Vector3)
	local root = rootOf(player)
	if not root then
		return
	end
	local away = root.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 1e-3 then
		away = Vector3.new(1, 0, 0)
	end
	away = away.Unit
	Remotes.get("Knockback"):FireClient(player, away.X, away.Z)
end

function Carry.start()
	PlayerState.Added:Connect(function(player: Player)
		local function watch(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					Carry.drop(player, "died")
				end)
			end
		end
		player.CharacterAdded:Connect(watch)
		if player.Character then
			task.spawn(watch, player.Character)
		end
	end)
	PlayerState.Removing:Connect(function(player: Player)
		Carry.drop(player, "left")
	end)

	-- Curb crossing: the finish line of every heist (spec §6).
	task.spawn(function()
		while true do
			task.wait(Config.Carry.crossingCheckSeconds)
			for player, state in PlayerState.all() do
				local root = rootOf(player)
				if root then
					local inBase = Layout.isInBase(root.Position.X, root.Position.Z)
					if inBase ~= state.inBase then
						state.inBase = inBase
						PlayerState.sync(player)
						if inBase and state.carrying then
							Carry.CrossedHome:Fire(player, state.carrying)
							Remotes.get("Celebrate"):FireClient(player)
							Remotes.get("Toast"):FireClient(player, Strings.Toasts.madeItHome)
						end
					end
				end
			end
		end
	end)
end

return Carry
