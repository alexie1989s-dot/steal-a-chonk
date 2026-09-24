-- Hamster wheel (spec §9): standing on your own wheel raises Zoomies; the Pedal prompt adds a bonus.
-- No cash from the wheel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Movement = require(script.Parent.Movement)
local PlayerState = require(script.Parent.PlayerState)
local Plots = require(script.Parent.Plots)

local Wheel = {}

local lastPedal: { [Player]: number } = {}

local function addZoomies(player: Player, amount: number)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	state.zoomies += amount
	PlayerState.sync(player)
	Movement.refresh(player)
end
Wheel.addZoomies = addZoomies

local function isOnOwnWheel(player: Player): boolean
	local state = PlayerState.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (state and state.plot and root) then
		return false
	end
	local wheel = Plots.part(state.plot, "Wheel")
	local p, w = root.Position, wheel.Position
	return Layout.planarDistance(p.X, p.Z, w.X, w.Z) <= Config.Wheel.radius and math.abs(p.Y - w.Y) < 6
end
Wheel.isOnOwnWheel = isOnOwnWheel

function Wheel.start()
	for index = 1, Plots.count() do
		local prompt = Plots.part(index, "Wheel"):FindFirstChild("PedalPrompt") :: ProximityPrompt
		prompt.Triggered:Connect(function(player: Player)
			if Plots.ownerOf(index) ~= player then
				return
			end
			-- Prompts are triggered by the client, so the server re-checks reach (spec §20).
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local wheel = Plots.part(index, "Wheel")
			if
				not root
				or (root.Position - wheel.Position).Magnitude
					> Config.Wheel.promptDistance + Config.AntiCheat.reachTolerance
			then
				return
			end
			local now = os.clock()
			if now - (lastPedal[player] or 0) < 1 / Config.Wheel.pedalMaxPerSecond then
				return
			end
			lastPedal[player] = now
			addZoomies(player, Config.Wheel.pedalBonus)
		end)
	end

	PlayerState.Removing:Connect(function(player: Player)
		lastPedal[player] = nil
	end)

	task.spawn(function()
		local tick = Config.Wheel.tickSeconds
		while true do
			task.wait(tick)
			for player in PlayerState.all() do
				if isOnOwnWheel(player) then
					addZoomies(player, Config.Wheel.passivePerSecond * tick)
				end
			end
		end
	end)
end

return Wheel
