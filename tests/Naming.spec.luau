local T = require("./TestLib")
local Naming = require("../src/shared/Naming")
local Catalog = require("../src/shared/Catalog")

T.test("six size stamps in spec order", function()
	T.expectEqual(Naming.sizeStamp(1), "A Fine Boi")
	T.expectEqual(Naming.sizeStamp(2), "He Chomnk")
	T.expectEqual(Naming.sizeStamp(3), "A Heckin' Chonker")
	T.expectEqual(Naming.sizeStamp(4), "HEFTYCHONK")
	T.expectEqual(Naming.sizeStamp(5), "MEGACHONKER")
	T.expectEqual(Naming.sizeStamp(6), "OH LAWD HE COMIN")
end)

T.test("display name: mutation prefixes, size suffixes", function()
	local e = { id = "x", species = "Cat", tier = "Common", name = "Beans", bio = "b", color = { 1, 2, 3 } }
	T.expectEqual(Naming.displayName(e, 4, "Cosmic"), "Cosmic Beans the HEFTYCHONK")
	T.expectEqual(Naming.displayName(e, 1, nil), "Beans, A Fine Boi")
end)

T.test("every catalog entry names cleanly at every size", function()
	for _, e in Catalog.entries do
		for size = 1, 6 do
			T.expectTrue(#Naming.displayName(e, size, nil) > #e.name, e.id)
		end
	end
end)

return {}
