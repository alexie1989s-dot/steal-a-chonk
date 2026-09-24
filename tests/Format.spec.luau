local T = require("./TestLib")
local Format = require("../src/shared/Format")

T.test("small numbers print whole with thousands separators", function()
	T.expectEqual(Format.number(0), "0")
	T.expectEqual(Format.number(999.9), "999")
	T.expectEqual(Format.number(1234), "1,234")
	T.expectEqual(Format.number(9999), "9,999")
end)

T.test("large numbers abbreviate with one decimal", function()
	T.expectEqual(Format.number(12345), "12.3K")
	T.expectEqual(Format.number(1500000), "1.5M")
	T.expectEqual(Format.number(2e9), "2B")
	T.expectEqual(Format.number(3.25e12), "3.2T")
end)

T.test("rates keep one decimal when it matters", function()
	T.expectEqual(Format.rate(1.5), "1.5")
	T.expectEqual(Format.rate(1), "1")
	T.expectEqual(Format.rate(62.5), "62.5")
	T.expectEqual(Format.rate(12345), "12.3K")
end)

T.test("negative and non-finite values do not crash the HUD", function()
	T.expectEqual(Format.number(-5), "0")
	T.expectEqual(Format.number(0 / 0), "0")
end)

return {}
