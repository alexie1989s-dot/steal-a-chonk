-- Field buttons (spec §19). The bat is F on keyboard, X on gamepad and a thumb button on touch.
-- Grab uses the burrito's ProximityPrompt, which already has its own touch button.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Input = {}

function Input.start()
	local batSwing = Remotes.get("BatSwing")
	ContextActionService:BindAction("Bat", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			batSwing:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("Bat", Strings.Bat.button)
	ContextActionService:SetPosition("Bat", UDim2.new(1, -170, 1, -150))
end

return Input
