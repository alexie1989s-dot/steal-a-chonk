local T = require("./TestLib")
local Config = require("../src/shared/Config")
local Ground = require("../src/shared/Ground")
local LandGrid = require("../src/shared/LandGrid")
local Layout = require("../src/shared/Layout")

local VOXEL, CHUNK = LandGrid.VOXEL, LandGrid.CHUNK
local SPAN = VOXEL * CHUNK

local function named(name: string): string
	return name
end

local function nearestToCentre(c: LandGrid.Chunk): number
	local x, z = math.clamp(0, c.x, c.x + SPAN), math.clamp(0, c.z, c.z + SPAN)
	return math.sqrt(x * x + z * z)
end

-- The chunk holding the point (x, z).
local function chunkAt(x: number, z: number): LandGrid.Chunk
	return { x = math.floor(x / SPAN) * SPAN, z = math.floor(z / SPAN) * SPAN }
end

T.test("chunks sit on the voxel grid, once each, nearest the centre first", function()
	local seen, last = {}, -1
	for i, c in LandGrid.chunks() do
		T.expectEqual(c.x % SPAN, 0, `x off the grid at {i}`)
		T.expectEqual(c.z % SPAN, 0, `z off the grid at {i}`)
		local key = `{c.x},{c.z}`
		T.expectTrue(not seen[key], "twice: " .. key)
		seen[key] = true
		local d = nearestToCentre(c)
		T.expectTrue(d >= last, `out of order at {i}`)
		last = d
	end
	-- the land reaches every bearing's far edge, and a chunk is there to hold it
	for i = 0, 359 do
		local a = 2 * math.pi * i / 360
		local r = Layout.outlineRadius(a) + Config.Map.extent - 3
		local c = chunkAt(r * math.cos(a), r * math.sin(a))
		T.expectTrue(seen[`{c.x},{c.z}`], `no chunk at the far edge, bearing {i}`)
	end
end)

T.test("each column is filled to LIFT under the surface: full, then part-filled, then empty", function()
	local chunks = LandGrid.chunks()
	for _, c in { chunks[1], chunkAt(200, -40), chunkAt(-120, 260), chunkAt(560, 300), chunks[#chunks] } do
		local v = LandGrid.voxels(c, named)
		for i = 1, CHUNK do
			for k = 1, CHUNK do
				local x, z = c.x + (i - 0.5) * VOXEL, c.z + (k - 0.5) * VOXEL
				local filled, settled = 0, true
				for j = 1, v.layers do
					local s = v.solid[i][j][k]
					filled += s * VOXEL
					T.expectTrue((v.material[i][j][k] == "Air") == (s == 0), `material without land at {x}, {z}`)
					if j > 1 and s > v.solid[i][j - 1][k] then
						settled = false
					end
				end
				T.expectTrue(settled, `a gap in the column at {x}, {z}`)
				if LandGrid.hasLand(x, z) then
					T.expectNear(
						Config.Map.floor + filled + LandGrid.LIFT,
						Ground.height(x, z),
						1e-6,
						`column at {x}, {z}`
					)
				else
					T.expectEqual(filled, 0, `land outside the land at {x}, {z}`)
				end
			end
		end
	end
end)

T.test("the district is paving filled to half a voxel under y = 0, so it is drawn at y = 0", function()
	local v = LandGrid.voxels({ x = 0, z = 0 }, named)
	local full = (-LandGrid.LIFT - Config.Map.floor) // VOXEL
	T.expectEqual(v.layers, full + 1)
	for i = 1, CHUNK do
		for k = 1, CHUNK do
			for j = 1, full do
				T.expectEqual(v.solid[i][j][k], 1)
				T.expectEqual(v.material[i][j][k], "Pavement")
			end
			T.expectNear(v.solid[i][full + 1][k], 0.5, 1e-9)
		end
	end
end)

T.test("there is a full voxel of land under every column, however low", function()
	local half = LandGrid.halfSide()
	for x = -half, half, 9 do
		for z = -half, half, 9 do
			if LandGrid.hasLand(x, z) then
				T.expectTrue(Ground.height(x, z) - LandGrid.LIFT >= Config.Map.floor + VOXEL, `too low at {x}, {z}`)
			end
		end
	end
end)

return {}
