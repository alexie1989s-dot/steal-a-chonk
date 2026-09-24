-- Studio-only test entry point. The Studio MCP's execute_luau runs outside the game's script VM,
-- so it reaches running services through this BindableFunction: ServerStorage.DevHooks:Invoke(action, ...).
-- Never created in live servers.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DevHooks = {}

local actions: { [string]: (...any) -> ...any } = {}

function DevHooks.register(name: string, fn: (...any) -> ...any)
	actions[name] = fn
end

function DevHooks.start()
	if not RunService:IsStudio() then
		return
	end
	local existing = ServerStorage:FindFirstChild("DevHooks")
	if existing then
		existing:Destroy()
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "DevHooks"
	hook.OnInvoke = function(action: string, ...: any)
		local fn = actions[action]
		if not fn then
			error(`unknown DevHooks action "{tostring(action)}"`)
		end
		return fn(...)
	end
	hook.Parent = ServerStorage
end

return DevHooks
