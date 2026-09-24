-- Runs all pure-module specs headlessly: `lune run tests/run`
local process = require("@lune/process")
local T = require("./TestLib")

-- Each suite is loaded inside pcall so a missing module is reported, not fatal.
local suites: { { name: string, load: () -> () } } = {
	{
		name = "Formulas",
		load = function()
			require("./Formulas.spec")
		end,
	},
	{
		name = "Catalog",
		load = function()
			require("./Catalog.spec")
		end,
	},
	{
		name = "Naming",
		load = function()
			require("./Naming.spec")
		end,
	},
	{
		name = "Rolls",
		load = function()
			require("./Rolls.spec")
		end,
	},
	{
		name = "Signal",
		load = function()
			require("./Signal.spec")
		end,
	},
	{
		name = "Layout",
		load = function()
			require("./Layout.spec")
		end,
	},
	{
		name = "Format",
		load = function()
			require("./Format.spec")
		end,
	},
	{
		name = "GuardianBrain",
		load = function()
			require("./GuardianBrain.spec")
		end,
	},
	{
		name = "VaultRules",
		load = function()
			require("./VaultRules.spec")
		end,
	},
	{
		name = "BatRules",
		load = function()
			require("./BatRules.spec")
		end,
	},
}

local loadFailures = {}
for _, suite in suites do
	T.setSuite(suite.name)
	local ok, err = pcall(suite.load)
	if not ok then
		table.insert(loadFailures, `FAIL {suite.name} (load): {err}`)
	end
end

local passed, failed, lines = T.runAll()
for _, line in loadFailures do
	print(line)
end
for _, line in lines do
	print(line)
end
failed += #loadFailures
print(`{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
