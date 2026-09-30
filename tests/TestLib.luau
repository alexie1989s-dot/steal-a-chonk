-- Minimal test API for Lune. Spec files register tests with `test`; tests/run.luau executes them.
local TestLib = {}

type TestCase = { suite: string, name: string, fn: () -> () }

local cases: { TestCase } = {}
local currentSuite = "?"

function TestLib.setSuite(name: string)
	currentSuite = name
end

function TestLib.test(name: string, fn: () -> ())
	table.insert(cases, { suite = currentSuite, name = name, fn = fn })
end

local function describe(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function TestLib.expectEqual(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "expectEqual"}: expected {describe(expected)}, got {describe(actual)}`, 2)
	end
end

function TestLib.expectNear(actual: number, expected: number, eps: number, msg: string?)
	if type(actual) ~= "number" or math.abs(actual - expected) > eps then
		error(`{msg or "expectNear"}: expected {expected} ± {eps}, got {describe(actual)}`, 2)
	end
end

function TestLib.expectTrue(v: any, msg: string?)
	if not v then
		error(`{msg or "expectTrue"}: got {describe(v)}`, 2)
	end
end

-- Runs every registered test and returns (passed, failed, failure lines).
function TestLib.runAll(): (number, number, { string })
	local passed, failed, lines = 0, 0, {}
	for _, case in cases do
		local ok, err = pcall(case.fn)
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(lines, `FAIL {case.suite} > {case.name}: {err}`)
		end
	end
	return passed, failed, lines
end

return TestLib
