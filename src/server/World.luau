-- Generates the greybox map at server start so nothing depends on hand edits in Studio:
-- base district paving, the painted curb (spec §6), Zone 1 nest bowls, hedges, scattered
-- field dressing and the zone signpost.
--
-- Everything built here is scenery. Only the curb and the nests carry meaning, so all of the
-- dressing is CanCollide false: it must never block a chase or a juke (spec §11).
--
-- Trees, rocks, bushes, flowers, clouds and the district benches use the licensed Synty meshes
-- when Props loaded them, and fall back to the part-built versions below when it did not.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Models = require(script.Parent.Models)
local Props = require(script.Parent.Props)

local World = {}

local CURB_SEGMENTS = 64
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
local SCATTER_SEED = 20260929

local GRASS_DARK = Color3.fromRGB(78, 128, 62)
local LEAF = Color3.fromRGB(86, 158, 74)
local LEAF_LIGHT = Color3.fromRGB(118, 190, 96)
local BARK = Color3.fromRGB(122, 90, 62)
local STONE = Color3.fromRGB(150, 150, 156)
-- Warm sand rather than the near-white it was: at this size the district is most of the screen,
-- and a pale grey disc drained the colour out of everything standing on it.
local PAVE = Color3.fromRGB(226, 188, 136)
local PAVE_ALT = Color3.fromRGB(206, 162, 108)
local PAVE_RING = Color3.fromRGB(242, 212, 160)
-- The boundary hills keep their own greens. GRASS_DARK was too dark for a face this big: the side
-- turned away from the sun went almost black and the rim read as a wall rather than as hills.
local HILL = Color3.fromRGB(136, 190, 108)
local RIDGE = Color3.fromRGB(120, 166, 124)
local WALL_HEIGHT = 70
local CURB_YELLOW = Color3.fromRGB(255, 214, 64)
local CURB_DARK = Color3.fromRGB(64, 58, 78)
local PETALS = {
	Color3.fromRGB(255, 150, 170),
	Color3.fromRGB(255, 214, 96),
	Color3.fromRGB(170, 170, 255),
	Color3.fromRGB(255, 250, 240),
}

-- Synty Nature and City pack meshes, by the name Props indexes them under. Green ones only: half
-- the pack is in autumn colours, and yellow and orange trees scattered through a spring field read
-- as a mess. Picked by lining every tree up in the field and looking.
local TREES = {
	"PolygonNature_Tree_Round_02",
	"PolygonNature_Tree_Round_03",
	"PolygonNature_Tree_Round_04",
	"PolygonNature_Tree_03",
	"PolygonCity_Env_SM_Env_Tree_03",
}
-- The boundary woods mix pines in, so the rim reads as forest rather than as a park.
local WOODS = table.clone(TREES)
for _, pine in
	{
		"PolygonNature_Tree_PolyPine_02",
		"PolygonNature_Tree_PolyPine_03",
		"PolygonNature_Tree_PolyPine_Sparse_02",
		"PolygonNature_Tree_PolyPine_Sparse_03",
	}
do
	table.insert(WOODS, pine)
end
local ROCKS = {
	"PolygonNature_Rock_Boulder_01",
	"PolygonNature_Rock_Rounded_01",
	"PolygonNature_Rock_Small_01",
	"PolygonNature_Rock_Pile_04",
}
local BUSHES = {
	"PolygonNature_Plant_Bush_01",
	"PolygonNature_Plant_Bush_02",
	"PolygonNature_Plant_Bush_03",
	"PolygonNature_Plant_Hedge_Bush_01",
	"PolygonNature_Plant_Hedge_Bush_02",
}
local FLOWERS = {
	"PolygonNature_Plant_Flowers_01",
	"PolygonNature_Plant_04",
	"PolygonNature_Plant_02",
	"PolygonNature_Plant_03",
	"PolygonNature_Plant_Fern_03",
	"PolygonNature_Plant_Mushrooms_01",
	"PolygonNature_Plant_Mushrooms_03",
}
local CLOUDS = { "PolygonNature_Prop_Cloud_01", "PolygonNature_Prop_Cloud_02", "PolygonNature_Prop_Cloud_03" }
local BENCH = "PolygonCity_Props_SM_Prop_ParkBench_01"
local BIN = "PolygonCity_Props_SM_Prop_Trashbin_01"
local PLANTER = "PolygonCity_Props_SM_Prop_Planter_02"

local function pick(list: { string }, rng: Random): string
	return list[rng:NextInteger(1, #list)]
end

-- A mesh standing on the ground at (x, z), turned to a random yaw.
local function grounded(x: number, z: number, rng: Random, sink: number?): CFrame
	return CFrame.new(x, -(sink or 0), z) * CFrame.Angles(0, rng:NextNumber() * 2 * math.pi, 0)
end

-- Scenery helper: never collides, never eats a ProximityPrompt raycast.
local function prop(props: { [string]: any }): BasePart
	props.CanCollide = false
	props.CanQuery = false
	return Models.part(props)
end

local function flatDisc(name: string, radius: number, height: number, y: number, color: Color3, parent: Instance)
	return prop({
		-- Lying flat on the ground, so its shadow is hidden underneath it: pure cost, no picture.
		CastShadow = false,
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
	-- The post is cut to reach the ground from wherever the board hangs, so the board can be raised
	-- over the tree line without the sign ending up on stilts.
	local postLength = math.max(position.Y - 6, 4)
	prop({
		Name = "Post",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(postLength, 1.6, 1.6),
		CFrame = CFrame.new(position - Vector3.new(0, 6 + postLength / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
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
	-- Printed on both faces of the board. It used to be a billboard hung in front of it, which turned
	-- to face the camera while the board did not, so from an angle the board cut the letters in half.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local panel = Models.signFace(board, face)
		panel.BackgroundColor3 = Color3.fromRGB(70, 52, 40)
		local line = Models.signText(
			panel,
			"Zone",
			string.upper(text),
			Color3.fromRGB(255, 244, 214),
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1)
		)
		line.Font = Enum.Font.LuckiestGuy
	end
	model.Parent = parent
end

-- A rounded shrub: a squat core with a few blobs on top to break the silhouette, plus flowers.
local function bush(position: Vector3, yaw: number, scale: number, rng: Random, parent: Instance)
	if Props.has(BUSHES[1]) then
		-- Three shrubs along the hedge's length, overlapping into one row.
		local model = Instance.new("Model")
		model.Name = "Hedge"
		local base = CFrame.new(position.X, -0.2, position.Z) * CFrame.Angles(0, yaw, 0)
		for i = -1, 1 do
			Props.place(
				pick(BUSHES, rng),
				base * CFrame.new(i * 4.2 * scale, 0, 0) * CFrame.Angles(0, rng:NextNumber() * 2 * math.pi, 0),
				model,
				{ height = (4.6 + rng:NextNumber() * 1.2) * scale }
			)
		end
		model.Parent = parent
		return
	end
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

local function tree(position: Vector3, scale: number, rng: Random, parent: Instance, kinds: { string }?)
	local at = grounded(position.X, position.Z, rng, 0.4 - position.Y)
	if Props.place(pick(kinds or TREES, rng), at, parent, { height = (24 + rng:NextNumber() * 8) * scale }) then
		return
	end
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
	local at = grounded(position.X, position.Z, rng, 0.3)
	if Props.place(pick(ROCKS, rng), at, parent, { height = (3.5 + rng:NextNumber() * 2.5) * scale }) then
		return
	end
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
	if Props.has(FLOWERS[1]) then
		for _ = 1, rng:NextInteger(4, 7) do
			local x = position.X + (rng:NextNumber() - 0.5) * 9
			local z = position.Z + (rng:NextNumber() - 0.5) * 9
			Props.place(pick(FLOWERS, rng), grounded(x, z, rng), model, { height = 1.6 + rng:NextNumber() * 1.4 })
		end
		model.Parent = parent
		return
	end
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

-- The plaza fountain: a stone basin of water with a column and a bowl, all scenery (players walk
-- through it, as they do every other decoration). It stands on the join spawn, which nobody sees:
-- a joining player is moved to their porch as soon as their character exists.
local function fountain(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Fountain"
	local stone = Color3.fromRGB(214, 206, 196)
	local water = Color3.fromRGB(110, 196, 236)
	local function ring(
		name: string,
		radius: number,
		height: number,
		y: number,
		color: Color3,
		material: Enum.Material?
	)
		return prop({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, radius * 2, radius * 2),
			CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	ring("Basin", 7.2, 1.8, 1.2, stone)
	ring("Water", 6.4, 0.3, 2.0, water, Enum.Material.Glass).Transparency = 0.2
	ring("Column", 1.1, 4.6, 3.5, stone)
	ring("Bowl", 2.8, 0.7, 5.8, stone)
	ring("BowlWater", 2.4, 0.3, 6.1, water, Enum.Material.Glass).Transparency = 0.2
	ring("Top", 0.7, 1.4, 6.9, stone)
	model.Parent = parent
end

export type WorldInfo = { nests: { Vector3 }, curbRadius: number }

-- The field edge. Without this the map ran out into an open plain with a hard horizon line, which
-- reads as "the level stopped here". A ring of wooded hills closes it off.
--
-- One invisible wall does all of the containing, and every visible piece stays CanCollide false,
-- so the hills can overlap the boundary freely without a player ever being wedged between two of
-- them, and a prompt raycast can never catch the wall.
local function boundary(root: Instance, rng: Random)
	local base = Config.Base
	local wall = base.fieldOuterRadius + 4
	local fence = Instance.new("Folder")
	fence.Name = "Boundary"
	fence.Parent = root

	local segments = 72
	local segmentLength = 2 * math.pi * wall / segments + 2
	for i = 1, segments do
		local angle = 2 * math.pi * (i - 0.5) / segments
		local position = Vector3.new(wall * math.cos(angle), WALL_HEIGHT / 2, wall * math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		Models.part({
			Name = "FieldWall",
			Size = Vector3.new(4, WALL_HEIGHT, segmentLength),
			CFrame = CFrame.lookAt(position, position + tangent),
			Transparency = 1,
			CanQuery = false, -- solid to a player, invisible to every raycast
			Parent = fence,
		})
	end

	-- A dome half buried in the ground: `height` is how far it stands above the grass, `width` how
	-- far it spreads. Returns the surface height at a given distance from its centre, so trees can
	-- be planted up the slope instead of floating or sinking into it.
	local function hill(centreRadius: number, angle: number, width: number, height: number, color: Color3)
		local x, z = centreRadius * math.cos(angle), centreRadius * math.sin(angle)
		prop({
			Name = "Hill",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(width, height * 2, width * (0.78 + rng:NextNumber() * 0.3)),
			CFrame = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber() * 6, 0),
			Color = color,
			Material = Enum.Material.Grass,
			-- Overlapping domes this size threw hard black pockets onto each other, which read as
			-- holes in the landscape. They are lit by the sun and the sky, and cast nothing.
			CastShadow = false,
			Parent = fence,
		})
		-- Surface height at a planar distance from the hill's centre. Measured against the dome's
		-- narrower axis, so anything planted on it sinks slightly rather than floating.
		return function(distance: number): number
			local t = math.clamp(distance / (width * 0.39), 0, 1)
			return height * math.sqrt(math.max(1 - t * t, 0))
		end,
			x,
			z
	end

	-- The near rim: each hill is pushed out far enough that its foot lands just outside the wall,
	-- so a player running at the boundary stops where the ground starts to rise.
	local rimCount = 44
	for i = 1, rimCount do
		local angle = 2 * math.pi * (i - 0.5) / rimCount + (rng:NextNumber() - 0.5) * 0.04
		local width = 132 + rng:NextNumber() * 54
		local height = 30 + rng:NextNumber() * 16
		local centreRadius = wall + width / 2 + 4
		local surfaceAt, hx, hz =
			hill(centreRadius, angle, width, height, Models.shade(HILL, (rng:NextNumber() - 0.45) * 0.16))
		-- Trees up the slope and along the foot, so the rim reads as woods rather than as a berm.
		for _ = 1, rng:NextInteger(2, 4) do
			local r = centreRadius + (rng:NextNumber() - 0.35) * width * 0.6
			local treeAngle = angle + (rng:NextNumber() - 0.5) * 0.08
			local tx, tz = r * math.cos(treeAngle), r * math.sin(treeAngle)
			tree(
				Vector3.new(tx, surfaceAt(Layout.planarDistance(tx, tz, hx, hz)) - 1.5, tz),
				1 + rng:NextNumber() * 0.6,
				rng,
				fence,
				WOODS
			)
		end
	end

	-- The far ridge: taller, cooler and bluer, so it reads as distance. This is what closes the
	-- horizon once the camera lifts above the near rim.
	-- One radius for the whole band, so the hills always overlap. Letting it vary left gaps you
	-- could see the open horizon through from a raised camera.
	local ridgeCount = 48
	local ridgeRadius = wall + 190
	for i = 1, ridgeCount do
		local angle = 2 * math.pi * (i - 0.5) / ridgeCount + (rng:NextNumber() - 0.5) * 0.05
		hill(
			ridgeRadius,
			angle,
			230 + rng:NextNumber() * 70,
			118 + rng:NextNumber() * 40,
			RIDGE:Lerp(Color3.new(0.58, 0.7, 0.8), 0.18 + rng:NextNumber() * 0.22)
		)
	end

	-- The whole boundary sits 350 to 520 studs out, past the shadow map's useful range, so nothing
	-- in it casts. That is 684 parts taken out of the shadow pass for no visible change.
	for _, d in fence:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
end

-- A loose ring of clouds above the far ridge, so the sky is not one flat colour. Mesh only: with
-- no pack there is no part version, the sky just stays clear.
local function clouds(root: Instance, rng: Random)
	if not Props.has(CLOUDS[1]) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Clouds"
	folder.Parent = root
	local count = 18
	for i = 1, count do
		local angle = 2 * math.pi * (i - 0.5) / count + (rng:NextNumber() - 0.5) * 0.25
		local r = 380 + rng:NextNumber() * 260
		local at = CFrame.new(r * math.cos(angle), 180 + rng:NextNumber() * 70, r * math.sin(angle))
			* CFrame.Angles(0, rng:NextNumber() * 2 * math.pi, 0)
		Props.place(pick(CLOUDS, rng), at, folder, { scale = 3.5 + rng:NextNumber() * 2.5, castShadow = false })
	end
end

-- A bench, a bin and a planter in each gap between two houses, under the gap's lamp post, so the
-- district reads as a street people live on. Mesh only, like the clouds.
local function streetFurniture(root: Instance)
	if not Props.has(BENCH) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "StreetFurniture"
	folder.Parent = root
	local base = Config.Base
	for i = 1, base.plotCount do
		local angle = 2 * math.pi * (i - 0.5) / base.plotCount
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = outward * (base.curbRadius - 12)
		-- The bench looks in towards the middle of the district. The Synty bench's seat faces its
		-- local +Z, so its -Z (lookAt's forward) has to point outward.
		local facing = CFrame.lookAt(at, at + outward)
		Props.place(BENCH, facing, folder, { scale = 1.25 })
		Props.place(BIN, facing * CFrame.new(5.8, 0, 0), folder, { scale = 1.2 })
		Props.place(PLANTER, facing * CFrame.new(-6.4, 0, 0.4), folder, { scale = 1.3 })
	end
end

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
	flatDisc("BaseApron", base.curbRadius + 10, 0.3, 0.12, Color3.fromRGB(108, 172, 80), root)
	flatDisc("BaseDistrict", base.curbRadius, 0.4, 0.2, PAVE, root)
	flatDisc("BaseRingOuter", base.curbRadius - 16, 0.42, 0.24, PAVE_RING, root)
	flatDisc("BaseRingInner", base.plotRingRadius - 24, 0.44, 0.28, PAVE_ALT, root)
	-- A stone ring and a fountain at the centre, where a yellow target used to be.
	flatDisc("Medallion", 16, 0.5, 0.32, Color3.fromRGB(232, 214, 178), root)
	flatDisc("MedallionEye", 10, 0.52, 0.36, PAVE_ALT, root)
	fountain(root)

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
		-- A lantern under a shade, lit but not glowing: a Neon globe crossed the bloom threshold and
		-- blew out into a white smear at every distance.
		local lamp = prop({
			Name = "Lamp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4,
			CFrame = CFrame.new(at + Vector3.new(0, 16.6, 0)),
			Color = Color3.fromRGB(255, 240, 200),
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
			Parent = curb,
		})
		prop({
			Name = "LampShade",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 3.4, 3.4),
			CFrame = CFrame.new(at + Vector3.new(0, 17.9, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = CURB_DARK,
			Material = Enum.Material.SmoothPlastic,
			Parent = curb,
		})
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 226, 160)
		glow.Range = 22
		glow.Brightness = 0.9
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
		end
	end

	boundary(root, rng)
	clouds(root, rng)
	streetFurniture(root)

	-- Raised clear of the tree line: this is the one landmark that tells a new player where the
	-- district is from anywhere in the field.
	signpost(Strings.World.zoneSign, Vector3.new(0, 44, base.curbRadius + 60), root)

	root.Parent = workspace
	return { nests = nests, curbRadius = base.curbRadius }
end

return World
