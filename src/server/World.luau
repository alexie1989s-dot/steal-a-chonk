-- Generates the greybox map at server start so nothing depends on hand edits in Studio:
-- base district paving, the painted curb (spec §6), Zone 1 nest bowls, hedges and a zone sign.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Models = require(script.Parent.Models)

local World = {}

local CURB_SEGMENTS = 64

local function flatDisc(name: string, radius: number, height: number, y: number, color: Color3, parent: Instance)
	return Models.part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
end

local function billboardSign(text: string, position: Vector3, parent: Instance)
	local anchor = Models.part({
		Name = "Sign",
		Size = Vector3.one,
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(420, 90)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 600
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 244, 214)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
end

export type WorldInfo = { nests: { Vector3 }, curbRadius: number }

function World.build(): WorldInfo
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "World"

	local base = Config.Base
	flatDisc("BaseDistrict", base.curbRadius, 0.4, 0.2, Color3.fromRGB(196, 190, 176), root)

	local curb = Instance.new("Folder")
	curb.Name = "Curb"
	curb.Parent = root
	local segmentLength = 2 * math.pi * base.curbRadius / CURB_SEGMENTS + 0.6
	for i = 1, CURB_SEGMENTS do
		local angle = 2 * math.pi * (i - 0.5) / CURB_SEGMENTS
		local position = Vector3.new(base.curbRadius * math.cos(angle), 0.6, base.curbRadius * math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		Models.part({
			Name = "Segment",
			Size = Vector3.new(3, 1, segmentLength),
			CFrame = CFrame.lookAt(position, position + tangent),
			Color = Color3.fromRGB(255, 214, 64),
			Material = Enum.Material.SmoothPlastic,
			Parent = curb,
		})
	end

	local nestsFolder = Instance.new("Folder")
	nestsFolder.Name = "Nests"
	nestsFolder.Parent = root
	local nests = {}
	for index, p in Layout.nestPositions() do
		local nest = Instance.new("Model")
		nest.Name = `Nest{index}`
		nest:SetAttribute("NestIndex", index)
		local bowl = Models.part({
			Name = "Bowl",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 9, 9),
			CFrame = CFrame.new(p.x, 0.5, p.z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(150, 110, 70),
			Material = Enum.Material.WoodPlanks,
			Parent = nest,
		})
		nest.PrimaryPart = bowl
		nest.Parent = nestsFolder
		table.insert(nests, Vector3.new(p.x, 1, p.z))
	end

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = root
	for index, o in Layout.obstaclePositions() do
		Models.part({
			Name = "Hedge",
			Size = Vector3.new(14, 6, 4),
			CFrame = CFrame.new(o.x, 3, o.z) * CFrame.Angles(0, index * 1.3, 0),
			Color = Color3.fromRGB(58, 120, 52),
			Material = Enum.Material.Grass,
			Parent = obstacles,
		})
	end

	billboardSign(Strings.World.zoneSign, Vector3.new(0, 30, base.curbRadius + 60), root)

	root.Parent = workspace
	return { nests = nests, curbRadius = base.curbRadius }
end

return World
