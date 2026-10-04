-- Cuts the land into Terrain chunks and fills each chunk's voxel arrays from Ground. Pure, so Lune
-- checks exactly what the server writes; Landscape only turns the names into Enum.Material and
-- writes them with Terrain:WriteVoxelChannels.
--
-- A voxel is 4 studs. Each column is a stack of voxels from Config.Map.floor up: full voxels, then
-- one part-filled voxel, then air. Roblox draws a column's surface half a voxel above the top of what
-- is filled (measured in Studio on 2026-10-04: +2.00 studs at every fill level, on every smooth
-- material), so each column is filled to LIFT below Ground.height and drawn exactly at it. Water is
-- drawn exactly at its filled height, so the pond is filled to its waterline with no lift.
local Config = require("./Config")
local Ground = require("./Ground")
local Layout = require("./Layout")

local LandGrid = {}

LandGrid.VOXEL = 4
LandGrid.CHUNK = 16 -- columns along each side of a chunk: 64 studs
LandGrid.LIFT = 2 -- how far above the filled height Roblox draws the surface

local VOXEL, CHUNK, LIFT = LandGrid.VOXEL, LandGrid.CHUNK, LandGrid.LIFT
local SPAN = VOXEL * CHUNK

export type Chunk = { x: number, z: number } -- the chunk's lower corner, in studs

export type ChunkVoxels = {
	layers: number, -- voxel layers from Config.Map.floor up
	material: { { { any } } }, -- [x][y][z], from toMaterial
	solid: { { { number } } }, -- [x][y][z], 0 to 1
	liquid: { { { number } } }?, -- [x][y][z], 0 to 1; only when the chunk holds water
}

-- True when the column centred on (x, z) holds land: inside the field's edge, or in the hills past it.
function LandGrid.hasLand(x: number, z: number): boolean
	return Layout.planarDistance(0, 0, x, z) <= Layout.outlineRadius(math.atan2(z, x)) + Config.Map.extent
end

-- Half the side of the square the land is written in, rounded up to whole chunks.
function LandGrid.halfSide(): number
	local far = 0
	for i = 0, 719 do
		far = math.max(far, Layout.outlineRadius(2 * math.pi * i / 720))
	end
	return math.ceil((far + Config.Map.extent) / SPAN) * SPAN
end

-- How close a chunk comes to the centre of the map.
local function nearest(chunk: Chunk): number
	local x = math.clamp(0, chunk.x, chunk.x + SPAN)
	local z = math.clamp(0, chunk.z, chunk.z + SPAN)
	return Layout.planarDistance(0, 0, x, z)
end

-- Every chunk with land in it, nearest the centre first, so the district is written before the
-- field and the field before the hills.
function LandGrid.chunks(): { Chunk }
	local half = LandGrid.halfSide()
	local list = {}
	for x = -half, half - SPAN, SPAN do
		for z = -half, half - SPAN, SPAN do
			local chunk = { x = x, z = z }
			local any = false
			-- The land never reaches `half` from the centre, so the square's far corners are skipped.
			if nearest(chunk) <= half then
				for i = 1, CHUNK do
					for k = 1, CHUNK do
						if LandGrid.hasLand(x + (i - 0.5) * VOXEL, z + (k - 0.5) * VOXEL) then
							any = true
							break
						end
					end
					if any then
						break
					end
				end
			end
			if any then
				table.insert(list, chunk)
			end
		end
	end
	table.sort(list, function(a: Chunk, b: Chunk): boolean
		local da, db = nearest(a), nearest(b)
		if da ~= db then
			return da < db
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.z < b.z
	end)
	return list
end

-- The voxel arrays for one chunk. `toMaterial` turns Ground's material names, and "Air", into what
-- is written: Enum.Material on the server, the names themselves in tests.
function LandGrid.voxels(chunk: Chunk, toMaterial: (string) -> any): ChunkVoxels
	local floor = Config.Map.floor
	local function centre(i: number, k: number): (number, number)
		return chunk.x + (i - 0.5) * VOXEL, chunk.z + (k - 0.5) * VOXEL
	end
	-- Heights on the chunk's columns and a one-column border round them, for each column's slope.
	local heights = {}
	for i = 0, CHUNK + 1 do
		local row = {}
		for k = 0, CHUNK + 1 do
			row[k] = Ground.height(centre(i, k))
		end
		heights[i] = row
	end
	local water = Ground.pond()
	local top = floor + VOXEL
	local land, wet = {}, {}
	local anyWet = false
	for i = 1, CHUNK do
		land[i], wet[i] = {}, {}
		for k = 1, CHUNK do
			local x, z = centre(i, k)
			land[i][k] = LandGrid.hasLand(x, z)
			if land[i][k] then
				top = math.max(top, heights[i][k] - LIFT)
			end
			wet[i][k] = land[i][k] and water ~= nil and Layout.planarDistance(x, z, water.x, water.z) < water.radius
			if wet[i][k] then
				anyWet = true
				top = math.max(top, (water :: Ground.Pond).level)
			end
		end
	end
	local layers = math.ceil((top - floor) / VOXEL)

	local air = toMaterial("Air")
	local material, solid = table.create(CHUNK), table.create(CHUNK)
	local liquid = if anyWet then table.create(CHUNK) else nil
	for i = 1, CHUNK do
		local mi, si = table.create(layers), table.create(layers)
		local li = if liquid then table.create(layers) else nil
		for j = 1, layers do
			mi[j], si[j] = table.create(CHUNK), table.create(CHUNK)
			if li then
				li[j] = table.create(CHUNK)
			end
		end
		for k = 1, CHUNK do
			local columnMaterial = air
			if land[i][k] then
				local dx = (heights[i + 1][k] - heights[i - 1][k]) / (2 * VOXEL)
				local dz = (heights[i][k + 1] - heights[i][k - 1]) / (2 * VOXEL)
				local x, z = centre(i, k)
				columnMaterial = toMaterial(Ground.material(x, z, math.sqrt(dx * dx + dz * dz)))
			end
			for j = 1, layers do
				local bottom = floor + (j - 1) * VOXEL
				local fill = if land[i][k] then math.clamp((heights[i][k] - LIFT - bottom) / VOXEL, 0, 1) else 0
				mi[j][k] = if fill > 0 then columnMaterial else air
				si[j][k] = fill
				if li then
					local level = if wet[i][k] then (water :: Ground.Pond).level else bottom
					li[j][k] = math.clamp((level - bottom) / VOXEL, 0, 1)
				end
			end
		end
		material[i], solid[i] = mi, si
		if liquid then
			liquid[i] = li
		end
	end
	return { layers = layers, material = material, solid = solid, liquid = liquid }
end

return LandGrid
