-- Player houses in a ring inside the curb (spec §6, §10). Each plot has a porch facing the curb with
-- two Showcase pads and porch lights, a hamster wheel, two Vault incubators and ten Vault display pads.
-- Players spawn on their porch. Owner-only prompts carry the `Plot` and `Audience` attributes that the
-- client PromptFilter reads.
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
	-- The porch strip is z -20..-12; x = 0 is the spawn, so the slots sit either side of it.
	showcase = { Vector3.new(-8, 1.3, -16), Vector3.new(8, 1.3, -16) },
	porchLights = { Vector3.new(-19, 3, -19.5), Vector3.new(19, 3, -19.5) },
	cooldownSign = Vector3.new(0, 10.5, -16),
}

local PORCH_LIGHT = Color3.fromRGB(255, 226, 160)
Plots.PORCH_LIGHT = PORCH_LIGHT

-- Marks a prompt for the client PromptFilter: shown to the plot's owner ("owner") or everyone else ("others").
function Plots.tagPrompt(prompt: ProximityPrompt, plotIndex: number, audience: "owner" | "others")
	prompt:SetAttribute("Plot", plotIndex)
	prompt:SetAttribute("Audience", audience)
end

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
	-- Walls on the back and sides; the porch side stays open. The house is deliberately left
	-- open at the top: the Vault display pads are inside it, and a roof over them would fight
	-- the player's camera every time they walked in to sort their Chonks.
	local WALL = Color3.fromRGB(240, 170, 150)
	local TRIM = Color3.fromRGB(255, 244, 228)
	local wallTop = 8
	for _, wall in
		{
			{ Vector3.new(0, 4.5, size / 2 - 0.5), Vector3.new(size, 7, 1) },
			{ Vector3.new(-size / 2 + 0.5, 4.5, 4), Vector3.new(1, 7, size - 8) },
			{ Vector3.new(size / 2 - 0.5, 4.5, 4), Vector3.new(1, 7, size - 8) },
		}
	do
		Models.part({
			Name = "Wall",
			Size = wall[2],
			CFrame = at(wall[1]),
			Color = WALL,
			Parent = model,
		})
	end
	-- Knee walls either side of the porch bay, low enough to leave the Showcase in plain sight.
	for _, side in { -1, 1 } do
		Models.part({
			Name = "Wall",
			Size = Vector3.new(1, 2.5, 8),
			CFrame = at(Vector3.new(side * (size / 2 - 0.5), 2.25, -16)),
			Color = WALL,
			Parent = model,
		})
	end

	-- Scenery from here down: never collides, never blocks a prompt raycast.
	local function decor(props: { [string]: any }): BasePart
		props.CanCollide = false
		props.CanQuery = false
		props.Parent = model
		return Models.part(props)
	end

	-- A capping trim all round the wall tops, and a shallow gable over the back wall so the
	-- house reads as a house from out in the field.
	for _, trim in
		{
			{ Vector3.new(0, wallTop, size / 2 - 0.5), Vector3.new(size + 1.4, 0.8, 2) },
			{ Vector3.new(-size / 2 + 0.5, wallTop, 4), Vector3.new(2, 0.8, size - 8 + 1.4) },
			{ Vector3.new(size / 2 - 0.5, wallTop, 4), Vector3.new(2, 0.8, size - 8 + 1.4) },
		}
	do
		decor({ Name = "Trim", Size = trim[2], CFrame = at(trim[1]), Color = TRIM })
	end
	-- Rotating about Z lifts the +X end, so the slab on the -X side needs a positive angle and
	-- the one on the +X side a negative one. Matching the sign to `side` builds a valley, which
	-- is what this did at first: two red beams sagging in the middle instead of a roof.
	for _, side in { -1, 1 } do
		decor({
			Name = "Gable",
			Size = Vector3.new(size / 2 + 2, 1.4, 9),
			CFrame = at(Vector3.new(side * size / 4, wallTop + 1.6, size / 2 - 2.5))
				* CFrame.Angles(0, 0, -side * 0.28),
			Color = Color3.fromRGB(198, 92, 84),
		})
	end
	decor({
		Name = "Ridge",
		Size = Vector3.new(3, 1.5, 9.4),
		CFrame = at(Vector3.new(0, wallTop + 4.4, size / 2 - 2.5)),
		Color = Color3.fromRGB(176, 76, 70),
	})
	decor({
		Name = "GableFace",
		Size = Vector3.new(size - 16, 4.2, 0.6),
		CFrame = at(Vector3.new(0, wallTop + 1.9, size / 2 - 0.9)),
		Color = WALL,
	})

	-- A door and two windows on the inside face of the back wall.
	decor({
		Name = "Door",
		Size = Vector3.new(7, 7, 0.5),
		CFrame = at(Vector3.new(0, 4.5, size / 2 - 1.2)),
		Color = Color3.fromRGB(150, 98, 74),
		Material = Enum.Material.WoodPlanks,
	})
	decor({
		Name = "Knob",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.7,
		CFrame = at(Vector3.new(2.4, 4.4, size / 2 - 1.6)),
		Color = Color3.fromRGB(255, 214, 64),
		Material = Enum.Material.Metal,
	})
	for _, side in { -1, 1 } do
		decor({
			Name = "Window",
			Size = Vector3.new(6, 4, 0.5),
			CFrame = at(Vector3.new(side * 12, 5.4, size / 2 - 1.2)),
			Color = Color3.fromRGB(168, 224, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
		})
		decor({
			Name = "WindowFrame",
			Size = Vector3.new(7, 5, 0.3),
			CFrame = at(Vector3.new(side * 12, 5.4, size / 2 - 1.45)),
			Color = TRIM,
		})
	end

	-- A porch pergola: posts and a beam, with no deck above them, so a raider coming in off
	-- the field can still see what is sitting on the Showcase pads.
	for _, side in { -1, 1 } do
		decor({
			Name = "PorchPost",
			Size = Vector3.new(1.4, 7, 1.4),
			CFrame = at(Vector3.new(side * 16, 4.5, -19.5)),
			Color = TRIM,
			Material = Enum.Material.WoodPlanks,
		})
	end
	decor({
		Name = "PorchBeam",
		Size = Vector3.new(34, 1.2, 1.6),
		CFrame = at(Vector3.new(0, 8.4, -19.5)),
		Color = TRIM,
		Material = Enum.Material.WoodPlanks,
	})
	-- A step down off the porch, so the front edge is not a cliff.
	decor({
		Name = "Step",
		Size = Vector3.new(16, 0.6, 3),
		CFrame = at(Vector3.new(0, 0.9, -21.5)),
		Color = Color3.fromRGB(230, 216, 190),
		Material = Enum.Material.WoodPlanks,
	})

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
	-- The upright ring is the part that reads as the wheel; the flat disc is the treadle the
	-- player stands on. The stand therefore belongs under the ring, not under the disc.
	local ringAt = LOCAL.wheel + Vector3.new(0, 5.5, 4)
	for _, side in { -1, 1 } do
		decor({
			Name = "WheelStand",
			Size = Vector3.new(0.9, ringAt.Y - 1.3, 0.9),
			CFrame = at(Vector3.new(ringAt.X + side * 6, (ringAt.Y + 1) / 2, ringAt.Z)),
			Color = Color3.fromRGB(96, 86, 120),
			Material = Enum.Material.Metal,
		})
	end
	decor({
		Name = "WheelHub",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8,
		CFrame = at(ringAt),
		Color = Color3.fromRGB(96, 86, 120),
		Material = Enum.Material.Metal,
	})

	local pedal = Instance.new("ProximityPrompt")
	pedal.Name = "PedalPrompt"
	pedal.ActionText = Strings.Prompts.pedal
	pedal.ObjectText = Strings.Prompts.wheelObject
	pedal.HoldDuration = 0
	pedal.MaxActivationDistance = Config.Wheel.promptDistance
	pedal.RequiresLineOfSight = false
	Plots.tagPrompt(pedal, index, "owner")
	pedal.Parent = wheel

	for slot, pos in LOCAL.showcase do
		Models.part({
			Name = `Showcase{slot}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 6, 6),
			CFrame = at(pos) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(255, 196, 120),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		-- A ring under the pad and a light over it: this is the shop window of the whole game
		-- (spec §12), so it should look like something is meant to stand there.
		decor({
			Name = "ShowcaseRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 7.6, 7.6),
			CFrame = at(pos - Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(255, 214, 64),
			Material = Enum.Material.Neon,
		})
		local spot = decor({
			Name = "ShowcaseSpot",
			Size = Vector3.new(1.6, 0.8, 1.6),
			CFrame = at(Vector3.new(pos.X, 7.6, pos.Z)),
			Color = Color3.fromRGB(60, 54, 74),
		})
		local beamLight = Instance.new("SpotLight")
		beamLight.Face = Enum.NormalId.Bottom
		beamLight.Angle = 70
		beamLight.Range = 16
		beamLight.Brightness = 2
		beamLight.Color = Color3.fromRGB(255, 240, 210)
		beamLight.Parent = spot
	end
	for _, pos in LOCAL.porchLights do
		local light = Models.part({
			Name = "PorchLight",
			Size = Vector3.new(1, 1.4, 1),
			CFrame = at(pos),
			Color = PORCH_LIGHT,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
		local glow = Instance.new("PointLight")
		glow.Color = PORCH_LIGHT
		glow.Range = 12
		glow.Parent = light
	end
	local cooldown = Models.part({
		Name = "CooldownSign",
		Size = Vector3.one,
		CFrame = at(LOCAL.cooldownSign),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local cooldownGui = Instance.new("BillboardGui")
	cooldownGui.Enabled = false
	cooldownGui.Size = UDim2.fromOffset(220, 40)
	cooldownGui.MaxDistance = 150
	cooldownGui.Parent = cooldown
	local cooldownText = Instance.new("TextLabel")
	cooldownText.Name = "Text"
	cooldownText.Size = UDim2.fromScale(1, 1)
	cooldownText.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	cooldownText.BackgroundTransparency = 0.15
	cooldownText.Font = Enum.Font.FredokaOne
	cooldownText.TextScaled = true
	cooldownText.TextColor3 = Color3.new(1, 1, 1)
	cooldownText.Parent = cooldownGui

	for slot, pos in LOCAL.incubators do
		Models.part({
			Name = `Incubator{slot}`,
			Size = Vector3.new(4, 1.2, 4),
			CFrame = at(pos),
			Color = Color3.fromRGB(150, 220, 255),
			Material = Enum.Material.Glass,
			Parent = model,
		})
		decor({
			Name = "IncubatorBase",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.1, 5.6, 5.6),
			CFrame = at(pos - Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(96, 86, 120),
		})
		decor({
			Name = "IncubatorDome",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4.6, 5.4, 4.6),
			CFrame = at(pos + Vector3.new(0, 1.2, 0)),
			Color = Color3.fromRGB(180, 232, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.6,
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
			decor({
				Name = "DisplayRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 6.2, 6.2),
				CFrame = at(Vector3.new(x, 1.0, z)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(176, 158, 130),
			})
		end
	end

	local sign = Models.part({
		Name = "OwnerSign",
		Size = Vector3.one,
		CFrame = at(Vector3.new(0, 15, -6)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 44)
	-- Eight houses stand in a ring, so a long range stacks every label into one smear.
	gui.MaxDistance = 140
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

-- True when the player's root is over the plot square, plus a 2-stud margin.
function Plots.isOnPlot(player: Player, index: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local frame = frames[index]
	if not (root and frame) then
		return false
	end
	local p = frame:PointToObjectSpace(root.Position)
	local half = Config.Base.plotSize / 2 + 2
	return math.abs(p.X) <= half and math.abs(p.Z) <= half
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
