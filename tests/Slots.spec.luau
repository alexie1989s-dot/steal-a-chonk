local T = require("./TestLib")
local Slots = require("../src/shared/Slots")

T.test("count ignores holes", function()
	T.expectEqual(Slots.count({ [1] = "a", [3] = "b" }), 2)
	T.expectEqual(Slots.count({}), 0)
end)

T.test("firstFree returns the lowest empty slot within capacity", function()
	T.expectEqual(Slots.firstFree({ [1] = "a", [3] = "b" }, 4), 2)
	T.expectEqual(Slots.firstFree({}, 2), 1)
	T.expectEqual(Slots.firstFree({ [1] = "a", [2] = "b" }, 2), nil)
end)

return {}
