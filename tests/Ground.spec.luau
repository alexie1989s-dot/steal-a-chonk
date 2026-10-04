local T = require("./TestLib")
local Config = require("../src/shared/Config")
local Ground = require("../src/shared/Ground")
local Layout = require("../src/shared/Layout")

local map = Config.Map
local TAU = 2 * math.pi

-- True when a bearing falls in the dip cut into the rim for the pond.
local function inPondGap(angle: number): boolean
	local spec = map.pond
	if not spec then
		return false
	end
	return math.abs((angle - spec.angle + math.pi) % TAU - math.pi) < spec.gapHalfAngle
end

-- Calls fn(x, z) on a 4-stud grid over every point at least `margin` inside the field's edge.
local function eachFieldPoint(margin: number, fn: (number, number) -> ())
	local far = map.outline.mean * 1.3
	for x = -far, far, 4 do
		for z = -far, far, 4 do
			if Layout.isInsideField(x, z, margin) then
				fn(x, z)
			end
		end
	end
end

T.test("everything inside the wall is dead flat at y = 0", function()
	eachFieldPoint(0, function(x, z)
		T.expectEqual(Ground.height(x, z), 0, `at {x}, {z}`)
	end)
	T.expectEqual(Ground.height(0, 0), 0, "the centre")
end)

T.test("the land has no steps: half-stud neighbours stay close everywhere", function()
	local far = map.outline.mean * 1.3 + map.extent
	for x = -far, far, 7.3 do
		for z = -far, far, 6.1 do
			local h = Ground.height(x, z)
			T.expectTrue(math.abs(Ground.height(x + 0.5, z) - h) <= 1.5, `step along x at {x}, {z}`)
			T.expectTrue(math.abs(Ground.height(x, z + 0.5) - h) <= 1.5, `step along z at {x}, {z}`)
		end
	end
end)

T.test("hills rise just past the wall, and a taller ridge closes the horizon", function()
	for i = 0, 359 do
		local a = TAU * i / 360
		local edge = Layout.outlineRadius(a)
		local function at(u: number): number
			return Ground.height((edge + u) * math.cos(a), (edge + u) * math.sin(a))
		end
		T.expectEqual(at(0), 0, `the field is flat right up to the wall at {i}`)
		T.expectTrue(at(3) < 0.5, `the ground is still low 3 studs past the wall at {i}`)
		local rim, ridge = -math.huge, -math.huge
		for u = 0, 2 * map.rim.crest, 5 do
			rim = math.max(rim, at(u))
		end
		for u = map.ridge.start, map.extent, 5 do
			ridge = math.max(ridge, at(u))
		end
		if not inPondGap(a) then
			T.expectTrue(rim >= 20, `rim only {rim} high at {i}`)
		end
		T.expectTrue(ridge >= 90, `ridge only {ridge} high at {i}`)
	end
end)

T.test("materials: paving in the district, dirt at nests, rock only on steep faces", function()
	T.expectEqual(Ground.material(0, 0, 0), "Pavement")
	T.expectEqual(Ground.material(Config.Base.curbRadius - 3, 0, 0), "Pavement")
	for i, n in Layout.nestPositions() do
		T.expectEqual(Ground.material(n.x, n.z, 0), "Ground", "nest " .. i)
	end
	T.expectEqual(Ground.material(0, Config.Base.curbRadius + 20, 1.2), "Rock")
	local water = Ground.pond() :: Ground.Pond
	T.expectEqual(Ground.material(water.x, water.z, 0), "Mud", "the pond bed")
	T.expectEqual(Ground.material(water.x + water.radius + 2, water.z, 0), "Sand", "the pond's bank")
	local plain = Ground.material(0, Config.Base.curbRadius + 20, 0)
	T.expectTrue(plain == "Grass" or plain == "LeafyGrass", plain)
	local leafy = 0
	eachFieldPoint(2, function(x, z)
		local m = Ground.material(x, z, Ground.slope(x, z))
		T.expectTrue(m == "Grass" or m == "LeafyGrass" or m == "Ground" or m == "Pavement", `{m} in the field`)
		if m == "LeafyGrass" then
			leafy += 1
		end
	end)
	T.expectTrue(leafy > 0, "leafy patches")
end)

return {}
