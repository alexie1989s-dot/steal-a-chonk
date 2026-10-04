local T = require("./TestLib")
local Config = require("../src/shared/Config")
local Ground = require("../src/shared/Ground")
local LandGrid = require("../src/shared/LandGrid")
local Layout = require("../src/shared/Layout")

local map = Config.Map
local TAU = 2 * math.pi
local SPAN = LandGrid.VOXEL * LandGrid.CHUNK

local function named(name: string): string
	return name
end

T.test("the pond lies wholly past the wall, in a hollow that holds its water", function()
	local water = Ground.pond() :: Ground.Pond
	T.expectTrue(water ~= nil, "a pond")
	local spec = map.pond
	local outer = spec.radius + spec.shore + spec.blend
	for i = 0, 179 do
		local a = TAU * i / 180
		local x, z = water.x + outer * math.cos(a), water.z + outer * math.sin(a)
		T.expectTrue(not Layout.isInsideField(x, z, -8), `the hollow reaches the field at {i}`)
		for d = spec.radius, outer + 6, 1 do
			local h = Ground.height(water.x + d * math.cos(a), water.z + d * math.sin(a))
			T.expectTrue(h >= water.level - 1e-6, `land under the waterline at {i}, {d} out`)
		end
	end
	T.expectTrue(Ground.height(water.x, water.z) <= water.level - 2, "deep enough to read as water")
end)

T.test("the rim dips where the pond is, so it can be seen from the field", function()
	local water = Ground.pond() :: Ground.Pond
	local spec = map.pond
	local edge = Layout.outlineRadius(spec.angle)
	for u = 0, spec.beyond - spec.radius, 2 do
		local h = Ground.height((edge + u) * math.cos(spec.angle), (edge + u) * math.sin(spec.angle))
		T.expectTrue(h <= 8, `the rim blocks the view {u} past the wall: {h}`)
	end
	T.expectTrue(water.level <= 0, "the water lies below the field")
end)

T.test("the pond's chunk carries water to the waterline, and only in the pond", function()
	local water = Ground.pond() :: Ground.Pond
	local c = { x = math.floor(water.x / SPAN) * SPAN, z = math.floor(water.z / SPAN) * SPAN }
	local v = LandGrid.voxels(c, named)
	T.expectTrue(v.liquid ~= nil, "the pond's chunk has a water channel")
	local liquid = v.liquid :: { { { number } } }
	for i = 1, LandGrid.CHUNK do
		for k = 1, LandGrid.CHUNK do
			local x, z = c.x + (i - 0.5) * LandGrid.VOXEL, c.z + (k - 0.5) * LandGrid.VOXEL
			local depth = 0
			for j = 1, v.layers do
				depth += liquid[i][j][k] * LandGrid.VOXEL
			end
			if Layout.planarDistance(x, z, water.x, water.z) < water.radius then
				T.expectNear(map.floor + depth, water.level, 1e-6, `water column at {x}, {z}`)
			else
				T.expectEqual(depth, 0, `water outside the pond at {x}, {z}`)
			end
		end
	end
	T.expectTrue(LandGrid.voxels({ x = 128, z = 0 }, named).liquid == nil, "no water in the field")
end)

return {}
