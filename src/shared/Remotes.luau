-- RemoteEvent registry (spec §20: clients send intents, the server decides).
-- The server creates the events at boot; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- BatSwing: client → server, no arguments.
-- Reveal: server → client, card payload table.
-- Toast: server → client, (text).
-- Knockback: server → client, (dirX, dirZ).
-- Celebrate: server → client, no arguments.
Remotes.Names = { "BatSwing", "Reveal", "Toast", "Knockback", "Celebrate" }

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.get(name: string): RemoteEvent
	local root = folder()
	local existing = root:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = root
		return remote
	end
	return root:WaitForChild(name) :: RemoteEvent
end

function Remotes.createAll()
	for _, name in Remotes.Names do
		Remotes.get(name)
	end
end

return Remotes
