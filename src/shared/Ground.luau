-- The height of the land everywhere on the map (spec §6). Pure and deterministic: the server writes
-- Terrain from it, and the scenery planted on the hills asks it for a Y.
--
-- Everything inside the boundary wall (Layout.outlineRadius) is dead flat at y = 0: the district,
-- the field, the nests (user ruling 2026-10-04: a flat surface, so nothing floats). The land only
-- rises past the wall, where nothing is carried or dropped:
--   rim    hills climbing from the wall to a crest and falling away behind it
--   ridge  taller hills further out that close the horizon
--   pond   a small lake in a hollow past the wall, seen through a dip in the rim (Map.pond)
local Config = require("./Config")
local Layout = require("./Layout")

local Ground = {}

local TAU = 2 * math.pi

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- A raised-cosine hump: 1 at offset 0, easing to 0 at |offset| = half and flat beyond.
local function hump(offset: number, half: number): number
	if math.abs(offset) >= half then
		return 0
	end
	return 0.5 + 0.5 * math.cos(math.pi * offset / half)
end

-- The signed difference between two bearings, in -pi..pi.
local function bearingDiff(a: number, b: number): number
	return (a - b + math.pi) % TAU - math.pi
end

type Harmonic = { k: number, amplitude: number, phase: number }

local function harmonics(list: { Harmonic }, angle: number): number
	local v = 0
	for _, h in list do
		v += h.amplitude * math.sin(h.k * angle + h.phase)
	end
	return v
end

-- The rim and the ridge, `u` studs past the wall at this bearing.
local function beyond(angle: number, u: number): number
	local map = Config.Map
	local rim = map.rim.height + harmonics(map.rim.vary, angle)
	-- The rim dips where the pond is, so the water can be seen from the field.
	local spec = map.pond
	if spec then
		rim *= 1 - spec.gapDepth * hump(bearingDiff(angle, spec.angle), spec.gapHalfAngle)
	end
	local ridge = map.ridge.height + harmonics(map.ridge.vary, angle)
	return rim * hump(u - map.rim.crest, map.rim.crest) + ridge * smoothstep((u - map.ridge.start) / map.ridge.rise)
end

-- The land before the pond's hollow is cut into it.
local function natural(x: number, z: number): number
	local angle = math.atan2(z, x)
	local u = math.sqrt(x * x + z * z) - Layout.outlineRadius(angle)
	if u <= 0 then
		return 0
	end
	return beyond(angle, u)
end

export type Pond = { x: number, z: number, radius: number, level: number, plateau: number }
local pond: Pond? = nil

-- The lake past the wall, or nil when Config.Map.pond is not set. It lies in a hollow: the land
-- round it eases down to a flat bank at `plateau`, just under the lowest natural height on the
-- hollow's rim, and the water lies `bankRise` below the bank.
function Ground.pond(): Pond?
	local spec = Config.Map.pond
	if not spec then
		return nil
	end
	if pond == nil then
		local r = Layout.outlineRadius(spec.angle) + spec.beyond
		local x, z = r * math.cos(spec.angle), r * math.sin(spec.angle)
		local outer = spec.radius + spec.shore + spec.blend
		local lowest = math.huge
		for i = 1, 180 do
			local a = TAU * i / 180
			lowest = math.min(lowest, natural(x + outer * math.cos(a), z + outer * math.sin(a)))
		end
		local plateau = lowest - 0.25
		pond = { x = x, z = z, radius = spec.radius, level = plateau - spec.bankRise, plateau = plateau }
	end
	return pond
end

-- The surface height at (x, z).
function Ground.height(x: number, z: number): number
	local h = natural(x, z)
	local water = Ground.pond()
	if water then
		local spec = Config.Map.pond
		local d = Layout.planarDistance(x, z, water.x, water.z)
		if d < water.radius then
			local t = d / water.radius
			return water.level - spec.depth * (1 - t * t)
		elseif d < water.radius + spec.shore then
			return water.level + spec.bankRise * smoothstep((d - water.radius) / spec.shore)
		elseif d < water.radius + spec.shore + spec.blend then
			local t = smoothstep((d - water.radius - spec.shore) / spec.blend)
			return water.plateau + math.max(h - water.plateau, 0) * t
		end
	end
	return h
end

-- How steep the ground is at (x, z), as rise over run: 0 is flat, 1 is 45 degrees.
function Ground.slope(x: number, z: number): number
	local dx = (Ground.height(x + 1, z) - Ground.height(x - 1, z)) / 2
	local dz = (Ground.height(x, z + 1) - Ground.height(x, z - 1)) / 2
	return math.sqrt(dx * dx + dz * dz)
end

local nestSpots: { { x: number, z: number } }? = nil

-- The terrain material for the column at (x, z), given its slope there. A name rather than an
-- Enum.Material keeps this pure; the server maps the names.
function Ground.material(x: number, z: number, slope: number): string
	local map = Config.Map
	-- Under the district's paving. Not grass, so no grass blades poke up through the plaza.
	if Layout.isInBase(x, z) then
		return "Pavement"
	end
	local water = Ground.pond()
	if water then
		local d = Layout.planarDistance(x, z, water.x, water.z)
		if d < water.radius then
			return "Mud"
		elseif d < water.radius + map.pond.shore then
			return "Sand"
		end
	end
	if nestSpots == nil then
		nestSpots = Layout.nestPositions()
	end
	for _, n in nestSpots :: { { x: number, z: number } } do
		if Layout.planarDistance(x, z, n.x, n.z) < map.nestDirt then
			return "Ground"
		end
	end
	if slope > map.rockSlope then
		return "Rock"
	end
	-- Loose patches of a deeper, leafier grass, so the field is not one flat green.
	local patch = math.sin(x / 41 + 1.7) * math.sin(z / 53 + 0.4) + 0.5 * math.sin((x + z) / 29)
	if patch > 0.55 then
		return "LeafyGrass"
	end
	return "Grass"
end

return Ground
