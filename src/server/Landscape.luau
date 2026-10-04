-- Writes the land as Terrain when the server starts, from the pure height map in Ground (spec §6).
-- Nothing about the land is saved in the place: every server builds the same land from the same
-- numbers, so the repository stays the one source of truth, as it is for the rest of the map.
--
-- LandGrid cuts the land into chunks, nearest the district first, and fills their voxel arrays;
-- this module names the materials and writes them. It yields between chunks so the server keeps
-- running, and Main lets nobody in until the last chunk is down.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LandGrid = require(ReplicatedStorage.Shared.LandGrid)

local Landscape = {}

-- How long the writer works before it lets a frame pass, in seconds.
local BUDGET = 1 / 60

local MATERIALS: { [string]: Enum.Material } = {
	Air = Enum.Material.Air,
	Grass = Enum.Material.Grass,
	LeafyGrass = Enum.Material.LeafyGrass,
	Ground = Enum.Material.Ground,
	Rock = Enum.Material.Rock,
	Pavement = Enum.Material.Pavement,
	Mud = Enum.Material.Mud,
	Sand = Enum.Material.Sand,
}

-- The colours of the materials Ground uses, set before anything is written. Close to the old
-- Baseplate's grass, so the district's surroundings keep their look.
local COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(104, 166, 74),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(92, 148, 64),
	[Enum.Material.Ground] = Color3.fromRGB(150, 114, 80),
	[Enum.Material.Rock] = Color3.fromRGB(140, 136, 128),
	[Enum.Material.Pavement] = Color3.fromRGB(206, 188, 160),
	[Enum.Material.Mud] = Color3.fromRGB(112, 88, 64),
	[Enum.Material.Sand] = Color3.fromRGB(226, 204, 156),
}

local function toMaterial(name: string): Enum.Material
	local material = MATERIALS[name]
	if not material then
		error(`[Landscape] no terrain material for "{name}"`)
	end
	return material
end

function Landscape.build()
	local started = os.clock()
	local terrain = workspace.Terrain
	terrain:Clear()
	-- A place built before the land existed still has the old flat Baseplate. Left in, its top would
	-- show through every hollow in the field.
	local stale = workspace:FindFirstChild("Baseplate")
	if stale then
		stale:Destroy()
	end
	for material, color in COLORS do
		terrain:SetMaterialColor(material, color)
	end
	-- A clear, calm pond.
	terrain.WaterColor = Color3.fromRGB(64, 156, 178)
	terrain.WaterTransparency = 0.45
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.06
	terrain.WaterWaveSpeed = 6

	local VOXEL, CHUNK, floor = LandGrid.VOXEL, LandGrid.CHUNK, Config.Map.floor
	local chunks = LandGrid.chunks()
	local written, slice = 0, os.clock()
	for _, chunk in chunks do
		local v = LandGrid.voxels(chunk, toMaterial)
		local region = Region3.new(
			Vector3.new(chunk.x, floor, chunk.z),
			Vector3.new(chunk.x + CHUNK * VOXEL, floor + v.layers * VOXEL, chunk.z + CHUNK * VOXEL)
		)
		local channels: { [string]: any } = { SolidMaterial = v.material, SolidOccupancy = v.solid }
		if v.liquid then
			channels.LiquidOccupancy = v.liquid
		end
		terrain:WriteVoxelChannels(region, VOXEL, channels)
		written += CHUNK * CHUNK * v.layers
		if os.clock() - slice > BUDGET then
			task.wait()
			slice = os.clock()
		end
	end

	local seconds = os.clock() - started
	workspace:SetAttribute("LandSeconds", math.round(seconds * 100) / 100)
	workspace:SetAttribute("LandReadyAt", os.clock())
	workspace:SetAttribute("LandReady", true)
	print(`[Landscape] {#chunks} chunks, {written} voxels written in {string.format("%.2f", seconds)} s`)
end

return Landscape
