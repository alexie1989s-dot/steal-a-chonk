-- Who a bat swing hits (spec §11, §13): the nearest burrito carrier in the field, in range and in
-- front of the swinger (or point blank). Carriers have their hands full and cannot swing. Pure.
local Config = require("./Config")

local BatRules = {}

export type BatAttacker = { x: number, z: number, lookX: number, lookZ: number, carrying: boolean }
export type BatCandidate = { id: number, x: number, z: number, carrying: boolean, inField: boolean }

function BatRules.pickTarget(attacker: BatAttacker, candidates: { BatCandidate }): number?
	if attacker.carrying then
		return nil
	end
	local rules = Config.Bat
	local lookLength = math.sqrt(attacker.lookX ^ 2 + attacker.lookZ ^ 2)
	local lookX = if lookLength > 1e-6 then attacker.lookX / lookLength else 0
	local lookZ = if lookLength > 1e-6 then attacker.lookZ / lookLength else 0

	local best, bestDistance = nil, math.huge
	for _, candidate in candidates do
		if candidate.carrying and candidate.inField then
			local dx, dz = candidate.x - attacker.x, candidate.z - attacker.z
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance <= rules.range then
				local inFront = distance <= rules.pointBlank
					or (distance > 1e-6 and (dx * lookX + dz * lookZ) / distance >= rules.arcDot)
				if inFront and distance < bestDistance then
					best, bestDistance = candidate.id, distance
				end
			end
		end
	end
	return best
end

return BatRules
