local T = require("./TestLib")
local GuardianBrain = require("../src/shared/GuardianBrain")
local Config = require("../src/shared/Config")
local Layout = require("../src/shared/Layout")

local G = Config.Guardian
local ZONE_SPEED = Config.Zones[1].guardianSpeed
local DT = 1 / 30
local NEST_X, NEST_Z = 180, 0

local function idle()
	return { carrierX = nil, carrierZ = nil, carrierInField = false, dt = DT, zoneSpeed = ZONE_SPEED }
end

local function carrierAt(x, z, inField)
	return { carrierX = x, carrierZ = z, carrierInField = inField, dt = DT, zoneSpeed = ZONE_SPEED }
end

local function run(brain, input, seconds)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		GuardianBrain.step(brain, input)
	end
end

-- Steps until `wanted` is reported (true) or the time runs out (false).
local function runUntil(brain, input, seconds, wanted)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		if GuardianBrain.step(brain, input) == wanted then
			return true
		end
	end
	return false
end

T.test("patrol circles the nest at the patrol radius", function()
	local brain = GuardianBrain.new(NEST_X, NEST_Z, 0)
	for _ = 1, 90 do
		GuardianBrain.step(brain, idle())
		T.expectNear(Layout.planarDistance(brain.x, brain.z, NEST_X, NEST_Z), G.patrolRadius, 0.05)
	end
	T.expectEqual(brain.mode, "patrol")
end)

T.test("a carrier in the field wakes her, and she chases after the MRRP pause", function()
	local brain = GuardianBrain.new(NEST_X, NEST_Z, 0)
	GuardianBrain.step(brain, carrierAt(NEST_X - 30, 0, true))
	T.expectEqual(brain.mode, "waking")
	run(brain, carrierAt(NEST_X - 30, 0, true), G.wakeDelay * 0.5)
	T.expectEqual(brain.mode, "waking")
	run(brain, carrierAt(NEST_X - 30, 0, true), G.wakeDelay * 0.6)
	T.expectEqual(brain.mode, "chase")
end)

T.test("chase starts slow and ramps to the zone speed", function()
	local brain = GuardianBrain.new(NEST_X, NEST_Z, 0)
	local far = carrierAt(NEST_X - 60, 0, true)
	run(brain, far, G.wakeDelay + 3 * DT)
	T.expectEqual(brain.mode, "chase")
	GuardianBrain.step(brain, far)
	T.expectTrue(brain.speed < ZONE_SPEED * (G.rampStartFactor + 0.1), "slow first roll: " .. brain.speed)
	run(brain, far, G.rampSeconds)
	T.expectNear(brain.speed, ZONE_SPEED, 1e-6)
end)

T.test("never enters the base district, even chasing a carrier hugging the curb", function()
	local brain = GuardianBrain.new(Config.Base.curbRadius + 40, 0, math.pi)
	local minRing = Config.Base.curbRadius + G.radius - 1e-6
	local angle = 0
	for _ = 1, 600 do
		angle += 0.01
		local r = Config.Base.curbRadius + 0.5 -- just outside the curb, still in the field
		GuardianBrain.step(brain, carrierAt(r * math.cos(angle), r * math.sin(angle), true))
		T.expectTrue(Layout.planarDistance(0, 0, brain.x, brain.z) >= minRing, "entered the curb")
	end
end)

T.test("catching the carrier reports 'caught' and sends her home", function()
	local brain = GuardianBrain.new(NEST_X, NEST_Z, 0)
	T.expectTrue(runUntil(brain, carrierAt(NEST_X + G.patrolRadius + 2, 0, true), 3, "caught"), "caught")
	T.expectEqual(brain.mode, "return")
end)

T.test("she gives up when the carrier reaches home, then resumes patrol", function()
	local brain = GuardianBrain.new(NEST_X, NEST_Z, 0)
	run(brain, carrierAt(NEST_X - 50, 0, true), G.wakeDelay + 0.5)
	T.expectEqual(brain.mode, "chase")
	GuardianBrain.step(brain, carrierAt(10, 0, false))
	T.expectEqual(brain.mode, "return")
	run(brain, idle(), 20)
	T.expectEqual(brain.mode, "patrol")
end)

T.test("a re-grab during return wakes her again", function()
	local brain = GuardianBrain.new(NEST_X, NEST_Z, 0)
	T.expectTrue(runUntil(brain, carrierAt(NEST_X + G.patrolRadius + 2, 0, true), 3, "caught"), "caught")
	GuardianBrain.step(brain, idle()) -- the burrito was dropped: nobody is carrying it
	T.expectTrue(brain.mode == "return" or brain.mode == "patrol", "calmed down: " .. brain.mode)
	GuardianBrain.step(brain, carrierAt(NEST_X - 20, 0, true))
	T.expectEqual(brain.mode, "waking")
end)

return {}
