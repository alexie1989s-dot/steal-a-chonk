-- Display names and size stamps (spec §8 naming grammar). Pure.
local Strings = require("./Strings")

local Naming = {}

local function clampSize(size: number): number
	return math.clamp(math.floor(size), 1, #Strings.SizeStamps)
end

function Naming.sizeStamp(size: number): string
	return Strings.SizeStamps[clampSize(size)]
end

-- "Cosmic Beans the HEFTYCHONK": mutation prefixes the name, size suffixes it.
function Naming.displayName(entry: { name: string }, size: number, mutation: string?): string
	local name = entry.name .. Strings.SizeSuffix[clampSize(size)]
	if mutation then
		name = `{mutation} {name}`
	end
	return name
end

return Naming
