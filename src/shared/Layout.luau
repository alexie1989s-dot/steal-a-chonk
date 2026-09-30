-- Map geometry in plain numbers on the ground plane (x, z). The base district is centred on the
-- origin, and the curb circle separates it from the field (spec §6). Deterministic and pure.
local Config = require("./Config")

local Layout = {}

local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

function Layout.planarDistance(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

function Layout.isInBase(x: number, z: number): boolean
	return Layout.planarDistance(0, 0, x, z) < Config.Base.curbRadius
end

-- Moves a point that is inside curb + margin out to that ring, keeping its direction from the centre.
function Layout.clampOutsideCurb(x: number, z: number, margin: number): (number, number)
	local ring = Config.Base.curbRadius + margin
	local d = Layout.planarDistance(0, 0, x, z)
	if d >= ring then
		return x, z
	end
	if d < 1e-6 then
		return ring, 0
	end
	return x / d * ring, z / d * ring
end

-- Plot centres on a ring; yaw is the outward direction's angle (cos yaw, sin yaw) on the ground plane.
function Layout.plotFrames(): { { x: number, z: number, yaw: number } }
	local base = Config.Base
	local plots = {}
	for i = 1, base.plotCount do
		local yaw = 2 * math.pi * (i - 1) / base.plotCount
		table.insert(
			plots,
			{ x = base.plotRingRadius * math.cos(yaw), z = base.plotRingRadius * math.sin(yaw), yaw = yaw }
		)
	end
	return plots
end

-- Sunflower spread over the nest band: even coverage without a visible grid.
function Layout.nestPositions(): { { x: number, z: number } }
	local base, count = Config.Base, Config.Zones[1].nestCount
	local inner2, outer2 = base.nestInner ^ 2, base.nestOuter ^ 2
	local nests = {}
	for i = 1, count do
		local t = (i - 0.5) / count
		local r = math.sqrt(inner2 + t * (outer2 - inner2))
		local angle = i * GOLDEN_ANGLE
		table.insert(nests, { x = r * math.cos(angle), z = r * math.sin(angle) })
	end
	return nests
end

-- Hedges to juke around (spec §6). Candidates are generated on a second spiral and skipped when
-- they would crowd a nest's patrol circle.
function Layout.obstaclePositions(): { { x: number, z: number } }
	local base = Config.Base
	local nests = Layout.nestPositions()
	local clearance = Config.Guardian.patrolRadius + 6
	local inner, outer = base.curbRadius + 20, base.fieldOuterRadius - 20
	local obstacles = {}
	local candidate = 0
	while #obstacles < base.obstacleCount and candidate < 1000 do
		candidate += 1
		local t = (candidate % 7 + 0.5) / 7
		local r = inner + t * (outer - inner)
		local angle = candidate * GOLDEN_ANGLE + GOLDEN_ANGLE / 2
		local x, z = r * math.cos(angle), r * math.sin(angle)
		local clear = true
		for _, n in nests do
			if Layout.planarDistance(x, z, n.x, n.z) <= clearance then
				clear = false
				break
			end
		end
		if clear then
			table.insert(obstacles, { x = x, z = z })
		end
	end
	return obstacles
end

return Layout
