-- Where the touch Bat button goes (spec §19: big one-thumb buttons in the lower corners). It is
-- placed against Roblox's own jump button, which the PlayerModule moves and resizes with the
-- screen, so the two never overlap. Pure: plain numbers in screen pixels.
local TouchLayout = {}

export type Circle = { x: number, y: number, radius: number }

-- Roblox's touch controls switch to their small layout at or below this short side; so does the Bat.
TouchLayout.SMALL_SCREEN = 500
-- How far the Bat's lip and shadow hang below its face, in pixels.
TouchLayout.LIP = 10

local GAP = 16 -- clear space between the Bat and the jump button
local MARGIN = 12 -- from the screen edges

-- The Bat's centre and radius for a screen `width` x `height`, beside `jump` (nil when there is no
-- jump button: jumping is off, or the controls are not built yet).
function TouchLayout.bat(width: number, height: number, jump: Circle?): Circle
	local small = math.min(width, height) <= TouchLayout.SMALL_SCREEN
	local radius = if small then 40 else 48
	local x, y
	if jump then
		-- Level with the jump button and to its left, where the thumb rolls from one to the other.
		x = jump.x - jump.radius - GAP - radius
		y = jump.y
	else
		x = width - MARGIN - 64 - radius
		y = height - MARGIN - TouchLayout.LIP - 48 - radius
	end
	x = math.clamp(x, MARGIN + radius, width - MARGIN - radius)
	y = math.clamp(y, MARGIN + radius, height - MARGIN - TouchLayout.LIP - radius)
	return { x = x, y = y, radius = radius }
end

return TouchLayout
