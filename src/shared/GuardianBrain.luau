-- Patroller Mama Chonk decisions (spec §7, §18), on the ground plane and free of Roblox APIs.
-- patrol:  waddles a circle around her nest.
-- waking:  her burrito's carrier is in the field; she says "MRRP" for wakeDelay.
-- chase:   rolls straight at the carrier, starting slow and ramping to the zone speed.
-- return:  the carrier got home, dropped it, or was caught; she heads back to her circle.
-- She never enters the base district: every move is clamped outside the curb.
local Config = require("./Config")
local Layout = require("./Layout")

local GuardianBrain = {}

export type Mode = "patrol" | "waking" | "chase" | "return"
export type Brain = {
	mode: Mode,
	x: number,
	z: number,
	nestX: number,
	nestZ: number,
	angle: number,
	modeTime: number,
	speed: number,
	headingX: number,
	headingZ: number,
	moved: number,
}
export type Input = {
	carrierX: number?,
	carrierZ: number?,
	carrierInField: boolean,
	dt: number,
	zoneSpeed: number,
}

local function patrolPoint(brain: Brain): (number, number)
	local r = Config.Guardian.patrolRadius
	return brain.nestX + r * math.cos(brain.angle), brain.nestZ + r * math.sin(brain.angle)
end

local function setMode(brain: Brain, mode: Mode)
	brain.mode = mode
	brain.modeTime = 0
end

-- Moves to (x, z) through the curb clamp, recording heading and distance moved.
local function place(brain: Brain, x: number, z: number)
	x, z = Layout.clampOutsideCurb(x, z, Config.Guardian.radius)
	local dx, dz = x - brain.x, z - brain.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d > 1e-6 then
		brain.headingX, brain.headingZ = dx / d, dz / d
	end
	brain.moved = d
	brain.x, brain.z = x, z
end

-- Steps toward (tx, tz) by at most maxStep. Returns the distance left before the step.
local function stepToward(brain: Brain, tx: number, tz: number, maxStep: number): number
	local dx, dz = tx - brain.x, tz - brain.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= 1e-6 then
		brain.moved = 0
		return 0
	end
	local step = math.min(d, maxStep)
	place(brain, brain.x + dx / d * step, brain.z + dz / d * step)
	return d
end

function GuardianBrain.new(nestX: number, nestZ: number, angle: number): Brain
	local brain: Brain = {
		mode = "patrol",
		x = 0,
		z = 0,
		nestX = nestX,
		nestZ = nestZ,
		angle = angle,
		modeTime = 0,
		speed = 0,
		headingX = 1,
		headingZ = 0,
		moved = 0,
	}
	brain.x, brain.z = patrolPoint(brain)
	return brain
end

-- Advances one tick. Returns "woke" when she notices a carrier, "caught" when she catches one.
function GuardianBrain.step(brain: Brain, input: Input): string?
	local G = Config.Guardian
	local dt = input.dt
	local hasCarrier = input.carrierX ~= nil and input.carrierZ ~= nil and input.carrierInField
	brain.modeTime += dt

	if brain.mode == "patrol" or brain.mode == "return" then
		if hasCarrier then
			setMode(brain, "waking")
			brain.speed = 0
			brain.moved = 0
			return "woke"
		end
	end

	if brain.mode == "patrol" then
		brain.angle += G.patrolSpeed / G.patrolRadius * dt
		brain.speed = G.patrolSpeed
		place(brain, patrolPoint(brain))
	elseif brain.mode == "waking" then
		brain.speed = 0
		brain.moved = 0
		if not hasCarrier then
			setMode(brain, "return")
		elseif brain.modeTime >= G.wakeDelay then
			setMode(brain, "chase")
		end
	elseif brain.mode == "chase" then
		if not hasCarrier then
			setMode(brain, "return")
			return nil
		end
		local cx, cz = input.carrierX :: number, input.carrierZ :: number
		local ramp = math.clamp(brain.modeTime / G.rampSeconds, 0, 1)
		brain.speed = input.zoneSpeed * (G.rampStartFactor + (1 - G.rampStartFactor) * ramp)
		stepToward(brain, cx, cz, brain.speed * dt)
		if Layout.planarDistance(brain.x, brain.z, cx, cz) <= G.catchDistance then
			setMode(brain, "return")
			return "caught"
		end
	elseif brain.mode == "return" then
		brain.speed = G.returnSpeed
		local px, pz = patrolPoint(brain)
		local remaining = stepToward(brain, px, pz, G.returnSpeed * dt)
		if remaining <= G.returnSpeed * dt then
			setMode(brain, "patrol")
		end
	end
	return nil
end

return GuardianBrain
