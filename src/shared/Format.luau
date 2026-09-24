-- Number formatting for the HUD and cards. Pure.
local Format = {}

local SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

function Format.number(n: number): string
	if n ~= n or n < 0 then
		return "0"
	end
	if n == math.huge then
		return "∞"
	end
	if n < 1e4 then
		local digits = tostring(math.floor(n))
		local grouped = (digits:reverse():gsub("(%d%d%d)", "%1,")):reverse()
		if grouped:sub(1, 1) == "," then
			grouped = grouped:sub(2)
		end
		return grouped
	end
	for _, pair in SUFFIXES do
		if n >= pair[1] then
			local value = math.floor(n / pair[1] * 10) / 10
			return (string.format("%.1f", value):gsub("%.0$", "")) .. pair[2]
		end
	end
	return tostring(math.floor(n))
end

-- Per-second rates: small values keep one decimal (a size-2 Common earns 1.5/s, not 1/s).
function Format.rate(n: number): string
	if n == n and n >= 0 and n < 100 and n ~= math.floor(n) then
		return (string.format("%.1f", math.floor(n * 10) / 10):gsub("%.0$", ""))
	end
	return Format.number(n)
end

return Format
