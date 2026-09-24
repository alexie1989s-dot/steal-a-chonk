local T = require("./TestLib")
local Layout = require("../src/shared/Layout")
local Config = require("../src/shared/Config")

T.test("inside/outside the curb", function()
	T.expectTrue(Layout.isInBase(0, 0))
	T.expectTrue(Layout.isInBase(Config.Base.curbRadius - 1, 0))
	T.expectTrue(not Layout.isInBase(Config.Base.curbRadius + 1, 0))
end)

T.test("clampOutsideCurb pushes points out and leaves field points alone", function()
	local x, z = Layout.clampOutsideCurb(10, 0, 4)
	T.expectNear(Layout.planarDistance(0, 0, x, z), Config.Base.curbRadius + 4, 1e-6)
	T.expectTrue(x > 0 and math.abs(z) < 1e-9, "keeps the direction")
	local fx, fz = Layout.clampOutsideCurb(200, 50, 4)
	T.expectEqual(fx, 200)
	T.expectEqual(fz, 50)
	local cx, cz = Layout.clampOutsideCurb(0, 0, 4) -- the exact centre still lands on the ring
	T.expectNear(Layout.planarDistance(0, 0, cx, cz), Config.Base.curbRadius + 4, 1e-6)
end)

T.test("plots: count, inside the curb, far enough apart, facing outward", function()
	local plots = Layout.plotFrames()
	T.expectEqual(#plots, Config.Base.plotCount)
	local half = Config.Base.plotSize / 2
	for i, p in plots do
		-- the whole plot, including its outer edge, stays inside the curb
		T.expectTrue(Layout.planarDistance(0, 0, p.x, p.z) + half * math.sqrt(2) < Config.Base.curbRadius, "plot " .. i)
		local q = plots[i % #plots + 1]
		T.expectTrue(Layout.planarDistance(p.x, p.z, q.x, q.z) > Config.Base.plotSize + 5, "spacing " .. i)
		local dx, dz = math.cos(p.yaw), math.sin(p.yaw)
		T.expectTrue(dx * p.x + dz * p.z > 0, "faces outward " .. i)
	end
end)

T.test("nests: zone count, all in the field band, not overlapping", function()
	local nests = Layout.nestPositions()
	T.expectEqual(#nests, Config.Zones[1].nestCount)
	for i, n in nests do
		local d = Layout.planarDistance(0, 0, n.x, n.z)
		T.expectTrue(d >= Config.Base.nestInner - 1e-6 and d <= Config.Base.nestOuter + 1e-6, "band " .. i)
		for j = i + 1, #nests do
			local gap = Layout.planarDistance(n.x, n.z, nests[j].x, nests[j].z)
			T.expectTrue(gap > 2 * Config.Guardian.patrolRadius + 8, `gap {i}-{j} = {gap}`)
		end
	end
end)

T.test("layout is deterministic", function()
	local a, b = Layout.nestPositions(), Layout.nestPositions()
	for i = 1, #a do
		T.expectEqual(a[i].x, b[i].x)
		T.expectEqual(a[i].z, b[i].z)
	end
end)

T.test("obstacles: requested count, in the field, clear of nests", function()
	local obstacles = Layout.obstaclePositions()
	T.expectEqual(#obstacles, Config.Base.obstacleCount)
	for i, o in obstacles do
		local d = Layout.planarDistance(0, 0, o.x, o.z)
		T.expectTrue(d > Config.Base.curbRadius + 10 and d < Config.Base.fieldOuterRadius, "obstacle band " .. i)
		for _, n in Layout.nestPositions() do
			T.expectTrue(
				Layout.planarDistance(o.x, o.z, n.x, n.z) > Config.Guardian.patrolRadius + 6,
				"obstacle near nest " .. i
			)
		end
	end
end)

return {}
