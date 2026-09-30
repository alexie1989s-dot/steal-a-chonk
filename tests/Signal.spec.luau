local T = require("./TestLib")
local Signal = require("../src/shared/Signal")

T.test("fire reaches listeners; disconnect stops them", function()
	local s, got = Signal.new(), {}
	local off = s:Connect(function(v)
		table.insert(got, v)
	end)
	s:Fire(1)
	off()
	s:Fire(2)
	T.expectEqual(#got, 1)
	T.expectEqual(got[1], 1)
end)

T.test("a listener that disconnects another mid-fire does not break the loop", function()
	local s, calls = Signal.new(), 0
	local offB
	s:Connect(function()
		calls += 1
		offB()
	end)
	offB = s:Connect(function()
		calls += 1
	end)
	s:Fire()
	T.expectTrue(calls >= 1)
	s:Fire()
end)

return {}
