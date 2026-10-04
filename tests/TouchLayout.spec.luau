local T = require("./TestLib")
local TouchLayout = require("../src/shared/TouchLayout")

-- Roblox's own jump button, as the PlayerModule's TouchJump lays it out (read from Studio,
-- 2026-10-04): the current layout and the legacy one, on a phone and on a tablet. Centres and
-- radii in screen pixels.
local function jumpAt(w: number, h: number, size: number, fromRight: number, fromBottom: number): TouchLayout.Circle
	return { x = w - fromRight + size / 2, y = h - fromBottom + size / 2, radius = size / 2 }
end

local PHONE_W, PHONE_H = 844, 390
local TABLET_W, TABLET_H = 1366, 1024
local LAYOUTS = {
	{ name = "phone, current", w = PHONE_W, h = PHONE_H, jump = jumpAt(PHONE_W, PHONE_H, 72, 136, 136) },
	{ name = "tablet, current", w = TABLET_W, h = TABLET_H, jump = jumpAt(TABLET_W, TABLET_H, 120, 220, 232) },
	{ name = "phone, legacy", w = PHONE_W, h = PHONE_H, jump = jumpAt(PHONE_W, PHONE_H, 70, 95, 90) },
	{ name = "tablet, legacy", w = TABLET_W, h = TABLET_H, jump = jumpAt(TABLET_W, TABLET_H, 120, 170, 210) },
}

local function onScreen(c: TouchLayout.Circle, w: number, h: number): boolean
	-- The lip and shadow hang below the face, so the bottom needs the extra room.
	return c.x - c.radius >= 0 and c.x + c.radius <= w and c.y - c.radius >= 0 and c.y + c.radius + TouchLayout.LIP <= h
end

T.test("the Bat never overlaps Roblox's jump button", function()
	for _, layout in LAYOUTS do
		local bat = TouchLayout.bat(layout.w, layout.h, layout.jump)
		local apart = math.sqrt((bat.x - layout.jump.x) ^ 2 + (bat.y - layout.jump.y) ^ 2)
		T.expectTrue(apart >= bat.radius + layout.jump.radius + 8, layout.name .. ": the Bat overlaps the jump button")
	end
end)

T.test("the Bat stays on screen, lip included", function()
	for _, layout in LAYOUTS do
		T.expectTrue(onScreen(TouchLayout.bat(layout.w, layout.h, layout.jump), layout.w, layout.h), layout.name)
	end
	T.expectTrue(onScreen(TouchLayout.bat(PHONE_W, PHONE_H, nil), PHONE_W, PHONE_H), "phone, no jump button")
end)

T.test("the Bat sits in the lower right, within a thumb's reach of the jump button", function()
	for _, layout in LAYOUTS do
		local bat = TouchLayout.bat(layout.w, layout.h, layout.jump)
		T.expectTrue(bat.x > layout.w / 2 and bat.y > layout.h / 2, layout.name .. ": not in the lower right quarter")
		local apart = math.sqrt((bat.x - layout.jump.x) ^ 2 + (bat.y - layout.jump.y) ^ 2)
		T.expectTrue(apart <= bat.radius + layout.jump.radius + 40, layout.name .. ": too far from the jump button")
	end
end)

T.test("a bigger Bat on a tablet than on a phone", function()
	local phone = TouchLayout.bat(PHONE_W, PHONE_H, LAYOUTS[1].jump)
	local tablet = TouchLayout.bat(TABLET_W, TABLET_H, LAYOUTS[2].jump)
	T.expectTrue(tablet.radius > phone.radius, "tablet Bat should be bigger")
	T.expectTrue(phone.radius * 2 >= 72, "a phone Bat is still a big one-thumb button (spec §19)")
end)
