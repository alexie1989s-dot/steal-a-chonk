-- Server-owned WalkSpeed (spec §9, §20): Zoomies set the speed, carrying scales it by tier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local PlayerState = require(script.Parent.PlayerState)

local Movement = {}

-- The speed the server allows this player right now.
function Movement.allowedSpeed(player: Player): number
	local state = PlayerState.get(player)
	if not state then
		return Formulas.walkSpeed(0)
	end
	if state.carrying then
		return Formulas.carrySpeed(state.zoomies, state.carrying.roll.tier)
	end
	return Formulas.walkSpeed(state.zoomies)
end

function Movement.refresh(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Movement.allowedSpeed(player)
	end
end

-- Carry anti-cheat baseline (spec §20): a carrier who covers more ground than their carry speed
-- allows is snapped back to the last sample. Only carriers are checked, so knockback after a
-- drop and server teleports of empty-handed players are never punished.
local lastSample: { [Player]: { position: Vector3, at: number } } = {}
Movement.snapBacks = 0

local function checkCarriers()
	local rules = Config.AntiCheat
	local now = os.clock()
	for player, state in PlayerState.all() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (state.carrying and root) then
			lastSample[player] = nil
			continue
		end
		local sample = lastSample[player]
		if sample then
			local dt = math.max(now - sample.at, 1e-3)
			local moved = Vector3.new(root.Position.X - sample.position.X, 0, root.Position.Z - sample.position.Z)
			local limit = Movement.allowedSpeed(player) * rules.toleranceFactor * dt + rules.toleranceStuds
			if moved.Magnitude > limit then
				Movement.snapBacks += 1
				root.CFrame = CFrame.new(sample.position) * root.CFrame.Rotation
				lastSample[player] = { position = sample.position, at = now }
				continue
			end
		end
		lastSample[player] = { position = root.Position, at = now }
	end
end

function Movement.start()
	PlayerState.Removing:Connect(function(player: Player)
		lastSample[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AntiCheat.sampleSeconds)
			checkCarriers()
		end
	end)

	PlayerState.Added:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			Movement.refresh(player)
		end)
		if player.Character then
			Movement.refresh(player)
		end
	end)
end

return Movement
