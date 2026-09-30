-- Helpers for slot maps with holes (Vault pads, porch slots): slot number -> occupant. Pure.
local Slots = {}

function Slots.count(map: { [number]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

-- The lowest empty slot in 1..capacity, or nil when every slot is taken.
function Slots.firstFree(map: { [number]: any }, capacity: number): number?
	for slot = 1, capacity do
		if map[slot] == nil then
			return slot
		end
	end
	return nil
end

return Slots
