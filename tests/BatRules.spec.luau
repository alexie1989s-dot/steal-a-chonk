local T = require("./TestLib")
local BatRules = require("../src/shared/BatRules")

local function attacker(x, z, lx, lz, carrying)
	return { x = x, z = z, lookX = lx, lookZ = lz, carrying = carrying or false }
end

local function carrier(id, x, z, inField)
	return { id = id, x = x, z = z, carrying = true, inField = inField ~= false }
end

T.test("hits a carrier in front, in range, in the field", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { carrier(7, 5, 0) }), 7)
end)

T.test("ignores carriers inside the base district", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { carrier(7, 5, 0, false) }), nil)
end)

T.test("ignores players who are not carrying", function()
	T.expectEqual(
		BatRules.pickTarget(attacker(0, 0, 1, 0), { { id = 7, x = 5, z = 0, carrying = false, inField = true } }),
		nil
	)
end)

T.test("out of range misses", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { carrier(7, 30, 0) }), nil)
end)

T.test("behind you misses unless point blank", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { carrier(7, -6, 0) }), nil)
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { carrier(7, -2, 0) }), 7)
end)

T.test("a carrier cannot bat", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0, true), { carrier(7, 5, 0) }), nil)
end)

T.test("picks the nearest valid target", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { carrier(1, 7, 0), carrier(2, 4, 1) }), 2)
end)

T.test("an unnormalised look vector still works", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 10, 0), { carrier(7, 5, 0) }), 7)
end)

return {}
