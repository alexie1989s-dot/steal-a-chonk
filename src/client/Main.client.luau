local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Version"))
local Client = script.Parent

-- Sounds first: the HUD, the reveal card and the buttons all play through it.
require(Client.Sfx).start()
require(Client.Hud).start()
require(Client.CameraFx).start()
require(Client.Effects).start()
require(Client.Reveal).start()
require(Client.Input).start()
require(Client.PromptFilter).start()
require(Client.Prompts).start()
require(Client.Idle).start()
require(Client.NameTags).start()
require(Client.Wheels).start()

print(`[{Version.name}] client booted ({Version.stage})`)
