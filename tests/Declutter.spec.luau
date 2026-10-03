local T = require("./TestLib")
local Declutter = require("../src/shared/Declutter")

-- A plate centred at (x, y) on screen, 100 x 30 pixels, `depth` studs from the camera.
local function plate(key: string, x: number, y: number, depth: number, shown: boolean?)
	return { key = key, x = x, y = y, w = 100, h = 30, depth = depth, shown = shown ~= false }
end

T.test("plates that do not touch all show", function()
	local shown = Declutter.choose({ plate("a", 0, 0, 10), plate("b", 200, 0, 20) }, 4)
	T.expectEqual(shown.a, true)
	T.expectEqual(shown.b, true)
end)

T.test("of two overlapping plates the nearer one wins, whatever order they arrive in", function()
	local shown = Declutter.choose({ plate("far", 40, 10, 30), plate("near", 0, 0, 10) }, 4)
	T.expectEqual(shown.near, true)
	T.expectEqual(shown.far, false)
end)

T.test("a hidden plate does not hide anything behind it", function()
	-- b is hidden by a; c overlaps only b, so it has a clear spot and shows.
	local shown = Declutter.choose({ plate("a", 0, 0, 10), plate("b", 60, 0, 20), plate("c", 120, 0, 30) }, 4)
	T.expectEqual(shown.a, true)
	T.expectEqual(shown.b, false)
	T.expectEqual(shown.c, true)
end)

T.test("a shown plate rides out a small overlap, so a slow orbit does not make it flicker", function()
	-- 98 apart on a 100-wide plate: 2 pixels of overlap, inside the 4-pixel margin.
	local shown = Declutter.choose({ plate("a", 0, 0, 10), plate("b", 98, 0, 20, true) }, 4)
	T.expectEqual(shown.b, true)
end)

T.test("a hidden plate needs clear space before it comes back", function()
	-- 102 apart: 2 pixels of gap, less than the 4-pixel margin a hidden plate must clear.
	local hidden = Declutter.choose({ plate("a", 0, 0, 10), plate("b", 102, 0, 20, false) }, 4)
	T.expectEqual(hidden.b, false)
	local clear = Declutter.choose({ plate("a", 0, 0, 10), plate("b", 106, 0, 20, false) }, 4)
	T.expectEqual(clear.b, true)
end)

T.test("overlap is checked on both axes", function()
	-- Same column, stacked: 30 tall plates 40 apart do not touch.
	local stacked = Declutter.choose({ plate("a", 0, 0, 10), plate("b", 0, 40, 20) }, 4)
	T.expectEqual(stacked.b, true)
	local touching = Declutter.choose({ plate("a", 0, 0, 10), plate("b", 0, 20, 20) }, 4)
	T.expectEqual(touching.b, false)
end)
