-- Spins each plot's hamster wheel while somebody stands on its treadle, spinning up and coasting
-- down rather than snapping. Decoration only: the server builds the wheel and never moves it again,
-- so turning it here is local and never fought over.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Wheels = {}

local TAG = "SpinWheel" -- Plots tags the turning part of each wheel
local SPEED = 3 -- radians per second with somebody running in it
local EASE = 2.5 -- how quickly it spins up and coasts down

type Rig = { base: CFrame, treadle: BasePart, angle: number, speed: number }

local rigs: { [Model]: Rig } = {}

-- The tag can replicate before PrimaryPart does (the same race Idle handles), so wait for it.
local function track(instance: Instance)
	if not instance:IsA("Model") or rigs[instance] then
		return
	end
	local model = instance :: Model
	task.spawn(function()
		while model.Parent and not model.PrimaryPart do
			model:GetPropertyChangedSignal("PrimaryPart"):Wait()
		end
		local plot = model.Parent
		local treadle = plot and plot:WaitForChild("Wheel", 10)
		if model.PrimaryPart and treadle and treadle:IsA("BasePart") then
			rigs[model] = { base = model:GetPivot(), treadle = treadle, angle = 0, speed = 0 }
		end
	end)
end

-- Anybody standing on the treadle, by the same test the server uses for Zoomies (Wheel).
local function occupied(treadle: BasePart): boolean
	local centre = treadle.Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = root.Position - centre
			if Vector2.new(offset.X, offset.Z).Magnitude <= Config.Wheel.radius and math.abs(offset.Y) < 6 then
				return true
			end
		end
	end
	return false
end

function Wheels.start()
	for _, model in CollectionService:GetTagged(TAG) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		rigs[model :: Model] = nil
	end)
	RunService.RenderStepped:Connect(function(dt)
		for model, rig in rigs do
			if not model.Parent then
				rigs[model] = nil
				continue
			end
			local target = if occupied(rig.treadle) then SPEED else 0
			rig.speed += (target - rig.speed) * math.min(dt * EASE, 1)
			if rig.speed > 0.01 then
				rig.angle = (rig.angle + rig.speed * dt) % (2 * math.pi)
				-- The hub is a cylinder, so its own X axis is the axle.
				model:PivotTo(rig.base * CFrame.Angles(rig.angle, 0, 0))
			end
		end
	end)
end

return Wheels
