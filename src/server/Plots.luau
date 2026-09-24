-- Player houses in a ring inside the curb (spec §6, §10). Each plot has a porch facing the curb,
-- a hamster wheel, two Vault incubators and ten Vault display pads. Players spawn on their porch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Models = require(script.Parent.Models)
local PlayerState = require(script.Parent.PlayerState)

local Plots = {}

local frames: { CFrame } = {}
local models: { Model } = {}
local owners: { [number]: Player } = {}

-- Plot-local layout: -Z faces outward (porch side), +Z faces the district centre (Vault side).
local LOCAL = {
	spawn = CFrame.new(0, 4, -14),
	wheel = Vector3.new(-12, 1.1, -8),
	incubators = { Vector3.new(8, 1.6, -8), Vector3.new(14, 1.6, -8) },
	displayXs = { -14, -7, 0, 7, 14 },
	displayZs = { 6, 14 },
}

local function ownerLabel(index: number)
	local sign = models[index]:FindFirstChild("OwnerSign")
	local label = sign and sign:FindFirstChildWhichIsA("BillboardGui")
	local text = label and label:FindFirstChild("Text") :: TextLabel?
	if text then
		local owner = owners[index]
		text.Text = if owner then `{owner.DisplayName}'s house` else "Empty lot"
	end
end

local function buildPlot(index: number, frame: CFrame, parent: Instance): Model
	local size = Config.Base.plotSize
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)

	local function at(localPos: Vector3): CFrame
		return frame * CFrame.new(localPos)
	end

	model.PrimaryPart = Models.part({
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		CFrame = at(Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(222, 206, 178),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	Models.part({
		Name = "Porch",
		Size = Vector3.new(size, 0.2, 8),
		CFrame = at(Vector3.new(0, 1.1, -size / 2 + 4)),
		Color = Color3.fromRGB(245, 232, 205),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	-- Low walls on the back and sides; the porch side stays open.
	for _, wall in
		{
			{ Vector3.new(0, 2.5, size / 2 - 0.5), Vector3.new(size, 3, 1) },
			{ Vector3.new(-size / 2 + 0.5, 2.5, 0), Vector3.new(1, 3, size) },
			{ Vector3.new(size / 2 - 0.5, 2.5, 0), Vector3.new(1, 3, size) },
		}
	do
		Models.part({
			Name = "Wall",
			Size = wall[2],
			CFrame = at(wall[1]),
			Color = Color3.fromRGB(240, 170, 150),
			Parent = model,
		})
	end

	local wheel = Models.part({
		Name = "Wheel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, Config.Wheel.radius * 2, Config.Wheel.radius * 2),
		CFrame = at(LOCAL.wheel) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 214, 64),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	Models.part({
		Name = "WheelRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 11, 11),
		CFrame = at(LOCAL.wheel + Vector3.new(0, 5.5, 4)) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(255, 120, 100),
		Transparency = 0.35,
		CanCollide = false,
		Parent = model,
	})
	local pedal = Instance.new("ProximityPrompt")
	pedal.Name = "PedalPrompt"
	pedal.ActionText = Strings.Prompts.pedal
	pedal.ObjectText = Strings.Prompts.wheelObject
	pedal.HoldDuration = 0
	pedal.MaxActivationDistance = Config.Wheel.promptDistance
	pedal.RequiresLineOfSight = false
	pedal.Parent = wheel

	for slot, pos in LOCAL.incubators do
		Models.part({
			Name = `Incubator{slot}`,
			Size = Vector3.new(4, 1.2, 4),
			CFrame = at(pos),
			Color = Color3.fromRGB(150, 220, 255),
			Material = Enum.Material.Glass,
			Parent = model,
		})
	end
	local display = 0
	for _, z in LOCAL.displayZs do
		for _, x in LOCAL.displayXs do
			display += 1
			Models.part({
				Name = `Display{display}`,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 5, 5),
				CFrame = at(Vector3.new(x, 1.15, z)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(200, 185, 160),
				Parent = model,
			})
		end
	end

	local sign = Models.part({
		Name = "OwnerSign",
		Size = Vector3.one,
		CFrame = at(Vector3.new(0, 12, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 44)
	gui.MaxDistance = 250
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = "Empty lot"
	text.Parent = gui

	model.Parent = parent
	return model
end

function Plots.frame(index: number): CFrame
	return frames[index]
end

function Plots.part(index: number, name: string): BasePart
	return models[index]:FindFirstChild(name) :: BasePart
end

function Plots.model(index: number): Model
	return models[index]
end

function Plots.ownerOf(index: number): Player?
	return owners[index]
end

function Plots.count(): number
	return #models
end

function Plots.spawnCFrame(index: number): CFrame
	return frames[index] * LOCAL.spawn
end

local function sendToPorch(player: Player, character: Model)
	local state = PlayerState.get(player)
	if not (state and state.plot) then
		return
	end
	-- CharacterAdded fires before the character is parented and placed at a SpawnLocation;
	-- wait for both, or the default spawn placement overrides the porch teleport.
	local deadline = os.clock() + 5
	while not character.Parent and os.clock() < deadline do
		task.wait()
	end
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait()
	if character.Parent and state.plot then
		character:PivotTo(Plots.spawnCFrame(state.plot))
	end
end

function Plots.start()
	local root = workspace:WaitForChild("World")
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = root
	for index, p in Layout.plotFrames() do
		local center = Vector3.new(p.x, 0, p.z)
		local outward = Vector3.new(math.cos(p.yaw), 0, math.sin(p.yaw))
		frames[index] = CFrame.lookAt(center, center + outward)
		models[index] = buildPlot(index, frames[index], folder)
	end

	PlayerState.Added:Connect(function(player: Player)
		local state = PlayerState.get(player)
		for index = 1, #models do
			if not owners[index] then
				owners[index] = player
				if state then
					state.plot = index
				end
				ownerLabel(index)
				break
			end
		end
		if state and not state.plot then
			task.delay(2, function()
				Remotes.get("Toast"):FireClient(player, Strings.Toasts.noPlot)
			end)
		end
		player.CharacterAdded:Connect(function(character)
			sendToPorch(player, character)
		end)
		if player.Character then
			task.spawn(sendToPorch, player, player.Character)
		end
	end)

	PlayerState.Removing:Connect(function(player: Player)
		for index, owner in owners do
			if owner == player then
				owners[index] = nil
				ownerLabel(index)
			end
		end
	end)
end

return Plots
