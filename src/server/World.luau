-- Generates the greybox map at server start so nothing depends on hand edits in Studio:
-- base district paving, the painted curb (spec §6), Zone 1 nest bowls, hedges, scattered
-- field dressing and the zone signpost.
--
-- Everything built here is scenery. Only the curb and the nests carry meaning, so all of the
-- dressing is CanCollide false: it must never block a chase or a juke (spec §11).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Models = require(script.Parent.Models)

local World = {}

local CURB_SEGMENTS = 64
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
local SCATTER_SEED = 20260929

local GRASS_DARK = Color3.fromRGB(78, 128, 62)
local LEAF = Color3.fromRGB(86, 158, 74)
local LEAF_LIGHT = Color3.fromRGB(118, 190, 96)
local BARK = Color3.fromRGB(122, 90, 62)
local STONE = Color3.fromRGB(150, 150, 156)
local PAVE = Color3.fromRGB(214, 206, 190)
local PAVE_ALT = Color3.fromRGB(198, 189, 172)
local CURB_YELLOW = Color3.fromRGB(255, 214, 64)
local CURB_DARK = Color3.fromRGB(64, 58, 78)
local PETALS = {
	Color3.fromRGB(255, 150, 170),
	Color3.fromRGB(255, 214, 96),
	Color3.fromRGB(170, 170, 255),
	Color3.fromRGB(255, 250, 240),
}

-- Scenery helper: never collides, never eats a ProximityPrompt raycast.
local function prop(props: { [string]: any }): BasePart
	props.CanCollide = false
	props.CanQuery = false
	return Models.part(props)
end

local function flatDisc(name: string, radius: number, height: number, y: number, color: Color3, parent: Instance)
	return prop({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
end

-- A signpost with a board, rather than text floating in mid air.
local function signpost(text: string, position: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "ZoneSign"
	prop({
		Name = "Post",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(24, 1.6, 1.6),
		CFrame = CFrame.new(position - Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = BARK,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local board = prop({
		Name = "Board",
		Size = Vector3.new(44, 12, 1.2),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(96, 74, 56),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	prop({
		Name = "Trim",
		Size = Vector3.new(46, 1.2, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 6.2, 0)),
		Color = CURB_YELLOW,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(420, 90)
	gui.StudsOffset = Vector3.new(0, 0, 1)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 600
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 244, 214)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 28, 20)
	stroke.Thickness = 3
	stroke.Parent = label
	model.Parent = parent
end

-- A rounded shrub: a squat core with a few blobs on top to break the silhouette, plus flowers.
local function bush(position: Vector3, yaw: number, scale: number, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Hedge"
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	prop({
		Name = "Core",
		Size = Vector3.new(13, 5, 4) * scale,
		CFrame = base,
		Color = GRASS_DARK,
		Material = Enum.Material.Grass,
		Parent = model,
	})
	for i = -2, 2 do
		prop({
			Name = "Tuft",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (5.2 + rng:NextNumber() * 1.6) * scale,
			CFrame = base * CFrame.new(i * 3.1 * scale, 1.6 * scale + rng:NextNumber() * scale, 0),
			Color = if i % 2 == 0 then LEAF else GRASS_DARK,
			Material = Enum.Material.Grass,
			Parent = model,
		})
	end
	for _ = 1, 3 do
		prop({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7 * scale,
			CFrame = base
				* CFrame.new((rng:NextNumber() - 0.5) * 12 * scale, 3.4 * scale, (rng:NextNumber() - 0.5) * 3),
			Color = PETALS[rng:NextInteger(1, #PETALS)],
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function tree(position: Vector3, scale: number, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = (16 + rng:NextNumber() * 8) * scale
	prop({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2.4 * scale, 2.4 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = BARK,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local crown = position + Vector3.new(0, height, 0)
	for i = 1, 3 do
		local spread = (i - 2) * 3.4 * scale
		prop({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (11 - math.abs(i - 2) * 2.5 + rng:NextNumber() * 2) * scale,
			CFrame = CFrame.new(crown + Vector3.new(spread, (2 - math.abs(i - 2) * 1.6) * scale, spread * 0.4)),
			Color = if i == 2 then LEAF_LIGHT else LEAF,
			Material = Enum.Material.Grass,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function rock(position: Vector3, scale: number, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Rock"
	for i = 1, rng:NextInteger(2, 3) do
		local size = (3.5 + rng:NextNumber() * 2.5) * scale / i
		prop({
			Name = "Stone",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size * 1.4, size, size * 1.2),
			CFrame = CFrame.new(position + Vector3.new((i - 1.5) * size, size * 0.3, (rng:NextNumber() - 0.5) * size))
				* CFrame.Angles(0, rng:NextNumber() * 6, 0),
			Color = Models.shade(STONE, (rng:NextNumber() - 0.5) * 0.3),
			Material = Enum.Material.Slate,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function flowerPatch(position: Vector3, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Flowers"
	for _ = 1, rng:NextInteger(4, 7) do
		local at = position + Vector3.new((rng:NextNumber() - 0.5) * 9, 0, (rng:NextNumber() - 0.5) * 9)
		local height = 1.4 + rng:NextNumber() * 1.2
		prop({
			Name = "Stem",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 0.22, 0.22),
			CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = GRASS_DARK,
			Parent = model,
		})
		prop({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.8 + rng:NextNumber() * 0.4),
			CFrame = CFrame.new(at + Vector3.new(0, height, 0)),
			Color = PETALS[rng:NextInteger(1, #PETALS)],
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	model.Parent = parent
end

-- Wild burrito nests: a woven bowl with a twig rim and a straw lining, so a nest reads as a
-- nest from across the field rather than as a wooden coin.
local function nestBowl(index: number, x: number, z: number, parent: Instance): Model
	local nest = Instance.new("Model")
	nest.Name = `Nest{index}`
	nest:SetAttribute("NestIndex", index)
	local bowl = Models.part({
		Name = "Bowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 9, 9),
		CFrame = CFrame.new(x, 0.5, z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(150, 110, 70),
		Material = Enum.Material.WoodPlanks,
		Parent = nest,
	})
	nest.PrimaryPart = bowl
	prop({
		Name = "Straw",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 7.4, 7.4),
		CFrame = CFrame.new(x, 1.0, z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(226, 196, 132),
		Material = Enum.Material.Fabric,
		Parent = nest,
	})
	-- A rim of twigs laid round the edge.
	for i = 1, 12 do
		local angle = 2 * math.pi * i / 12
		local at = Vector3.new(x + 4.3 * math.cos(angle), 1.0, z + 4.3 * math.sin(angle))
		prop({
			Name = "Twig",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.8, 0.7, 0.7),
			CFrame = CFrame.new(at) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(132, 96, 58),
			Material = Enum.Material.Wood,
			Parent = nest,
		})
	end
	nest.Parent = parent
	return nest
end

export type WorldInfo = { nests: { Vector3 }, curbRadius: number }

function World.build(): WorldInfo
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "World"
	local rng = Random.new(SCATTER_SEED)

	local base = Config.Base

	-- Paving in three concentric tones, so the district reads as laid rather than poured.
	flatDisc("BaseApron", base.curbRadius + 10, 0.3, 0.12, Color3.fromRGB(122, 168, 96), root)
	flatDisc("BaseDistrict", base.curbRadius, 0.4, 0.2, PAVE, root)
	flatDisc("BaseRingOuter", base.curbRadius - 16, 0.42, 0.24, PAVE_ALT, root)
	flatDisc("BaseRingInner", base.plotRingRadius - 24, 0.44, 0.28, PAVE, root)
	flatDisc("Medallion", 16, 0.5, 0.32, CURB_YELLOW, root)
	flatDisc("MedallionEye", 9, 0.52, 0.36, PAVE, root)

	-- The painted curb: alternating blocks with a glowing inner line and corner posts.
	local curb = Instance.new("Folder")
	curb.Name = "Curb"
	curb.Parent = root
	local segmentLength = 2 * math.pi * base.curbRadius / CURB_SEGMENTS + 0.6
	for i = 1, CURB_SEGMENTS do
		local angle = 2 * math.pi * (i - 0.5) / CURB_SEGMENTS
		local position = Vector3.new(base.curbRadius * math.cos(angle), 0.6, base.curbRadius * math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local frame = CFrame.lookAt(position, position + tangent)
		Models.part({
			Name = "Segment",
			Size = Vector3.new(3, 1, segmentLength),
			CFrame = frame,
			Color = if i % 2 == 0 then CURB_YELLOW else CURB_DARK,
			Material = Enum.Material.SmoothPlastic,
			Parent = curb,
		})
		-- A rounded cap so the kerb is not a row of bricks.
		prop({
			Name = "Cap",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segmentLength, 1.5, 1.5),
			-- One turn onto the tangent is enough; a second stood every cap up like a bollard.
			CFrame = frame * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color = if i % 2 == 0 then CURB_YELLOW else CURB_DARK,
			Material = Enum.Material.SmoothPlastic,
			Parent = curb,
		})
		-- The safe-side glow line, the thing a player actually runs for (spec §6).
		prop({
			Name = "Glow",
			Size = Vector3.new(0.5, 0.25, segmentLength),
			-- A kerb frame's local -X faces away from the centre, so the safe side is +X.
			CFrame = frame * CFrame.new(1.6, 0.5, 0),
			Color = CURB_YELLOW,
			Material = Enum.Material.Neon,
			Parent = curb,
		})
	end
	-- Lamp posts round the kerb, one every eighth segment.
	for i = 1, 8 do
		local angle = 2 * math.pi * (i - 0.5) / 8
		local at = Vector3.new((base.curbRadius - 5) * math.cos(angle), 0, (base.curbRadius - 5) * math.sin(angle))
		prop({
			Name = "LampPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(16, 1.1, 1.1),
			CFrame = CFrame.new(at + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = CURB_DARK,
			Material = Enum.Material.Metal,
			Parent = curb,
		})
		local lamp = prop({
			Name = "Lamp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3,
			CFrame = CFrame.new(at + Vector3.new(0, 16.5, 0)),
			Color = Color3.fromRGB(255, 236, 180),
			Material = Enum.Material.Neon,
			Parent = curb,
		})
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 226, 160)
		glow.Range = 26
		glow.Brightness = 1.2
		glow.Parent = lamp
	end

	local nestsFolder = Instance.new("Folder")
	nestsFolder.Name = "Nests"
	nestsFolder.Parent = root
	local nests = {}
	for index, p in Layout.nestPositions() do
		nestBowl(index, p.x, p.z, nestsFolder)
		table.insert(nests, Vector3.new(p.x, 1, p.z))
	end

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = root
	for index, o in Layout.obstaclePositions() do
		bush(Vector3.new(o.x, 3, o.z), index * 1.3, 1, rng, obstacles)
	end

	-- Field dressing on its own spiral, kept clear of the nests so it never hides a guardian
	-- or a burrito. Deterministic, so both developers see the same field.
	local dressing = Instance.new("Folder")
	dressing.Name = "Dressing"
	dressing.Parent = root
	local nestPoints = Layout.nestPositions()
	local clearance = Config.Guardian.patrolRadius + 10
	local inner, outer = base.curbRadius + 14, base.fieldOuterRadius - 6
	local placed = 0
	for candidate = 1, 320 do
		local t = (candidate % 11 + 0.5) / 11
		local r = inner + t * (outer - inner)
		local angle = candidate * GOLDEN_ANGLE
		local x, z = r * math.cos(angle), r * math.sin(angle)
		local clear = true
		for _, n in nestPoints do
			if Layout.planarDistance(x, z, n.x, n.z) <= clearance then
				clear = false
				break
			end
		end
		if clear then
			placed += 1
			local at = Vector3.new(x, 0, z)
			local kind = placed % 5
			if kind == 0 or kind == 1 then
				tree(at, 0.8 + rng:NextNumber() * 0.5, rng, dressing)
			elseif kind == 2 then
				rock(at, 0.9 + rng:NextNumber() * 0.7, rng, dressing)
			elseif kind == 3 then
				flowerPatch(at, rng, dressing)
			else
				bush(at + Vector3.new(0, 2, 0), rng:NextNumber() * 6, 0.55, rng, dressing)
			end
			-- A darker grass patch under the prop, to break up the flat ground.
			prop({
				Name = "Patch",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 16 + rng:NextNumber() * 14, 16 + rng:NextNumber() * 14),
				CFrame = CFrame.new(at + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Models.shade(GRASS_DARK, (rng:NextNumber() - 0.4) * 0.2),
				Material = Enum.Material.Grass,
				Parent = dressing,
			})
		end
	end

	signpost(Strings.World.zoneSign, Vector3.new(0, 26, base.curbRadius + 60), root)

	root.Parent = workspace
	return { nests = nests, curbRadius = base.curbRadius }
end

return World
