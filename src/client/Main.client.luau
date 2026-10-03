local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Version"))
local Client = script.Parent

require(Client.Hud).start()
require(Client.CameraFx).start()
require(Client.Effects).start()
require(Client.Reveal).start()
require(Client.Input).start()
require(Client.PromptFilter).start()
require(Client.Idle).start()
require(Client.NameTags).start()

print(`[{Version.name}] client booted ({Version.stage})`)
