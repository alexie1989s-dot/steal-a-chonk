-- Which world labels to show when their plates would overlap on screen. Pure.
--
-- Nearest first: a plate shows if it clears every plate already shown, so the Chonk you are
-- standing next to always keeps its tag and the row behind it gives way. A hidden plate blocks
-- nothing. `margin` is hysteresis in pixels: a shown plate rides out that much overlap and a hidden
-- one needs that much clear space, so a slow camera orbit does not make tags flicker at the edge.
local Declutter = {}

export type Plate = {
	key: any,
	x: number, -- centre, pixels
	y: number,
	w: number,
	h: number,
	depth: number, -- distance from the camera
	shown: boolean, -- what it was last time
}

function Declutter.choose(plates: { Plate }, margin: number): { [any]: boolean }
	local order = table.clone(plates)
	table.sort(order, function(a, b)
		return a.depth < b.depth
	end)
	local kept: { Plate } = {}
	local result = {}
	for _, p in order do
		local slack = if p.shown then -margin else margin
		local clear = true
		for _, q in kept do
			if math.abs(p.x - q.x) < (p.w + q.w) / 2 + slack and math.abs(p.y - q.y) < (p.h + q.h) / 2 + slack then
				clear = false
				break
			end
		end
		result[p.key] = clear
		if clear then
			table.insert(kept, p)
		end
	end
	return result
end

return Declutter
