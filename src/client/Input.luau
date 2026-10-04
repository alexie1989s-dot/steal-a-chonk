-- Field buttons (spec §19). The bat is F on keyboard, X on gamepad and a thumb button on touch.
-- Grab uses the burrito's ProximityPrompt, which already has its own touch button.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Ui = require(script.Parent.Ui)

local Input = {}

local BAT_RED = Color3.fromRGB(240, 92, 72)

function Input.start()
	local batSwing = Remotes.get("BatSwing")
	ContextActionService:BindAction("Bat", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			batSwing:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	-- Touch gets the game's own button in place of the stock grey circle, where a right thumb rests.
	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "FieldButtons"
		gui.ResetOnSpawn = false
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local bat = Ui.button({
			name = "Bat",
			size = UDim2.fromOffset(84, 84),
			position = UDim2.new(1, -170, 1, -150),
			color = BAT_RED,
			text = Strings.Bat.button,
			round = true,
			parent = gui,
		})
		bat.Activated:Connect(function()
			batSwing:FireServer()
		end)
	end
end

return Input
