-- Field buttons (spec §19). The bat is F on keyboard, X on gamepad and a thumb button on touch.
-- Grab uses the burrito's ProximityPrompt, which already has its own touch button.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local TouchLayout = require(ReplicatedStorage.Shared.TouchLayout)
local Ui = require(script.Parent.Ui)

local Input = {}

local BAT_RED = Color3.fromRGB(240, 92, 72)

-- Keeps the Bat (`holder`, a Ui.button in `gui`) beside Roblox's jump button, which the
-- PlayerModule builds on touch devices (TouchGui > TouchControlFrame > JumpButton) and moves and
-- resizes with the screen. Both are measured in absolute pixels, so the screen inset cancels out.
function Input.placeBat(gui: ScreenGui, holder: Frame)
	local jumpButton: GuiObject? = nil
	local function place()
		local origin, view = gui.AbsolutePosition, gui.AbsoluteSize
		local jump: TouchLayout.Circle? = nil
		if jumpButton and jumpButton.Parent and jumpButton.Visible and jumpButton.AbsoluteSize.X > 0 then
			local at, size = jumpButton.AbsolutePosition - origin, jumpButton.AbsoluteSize
			jump = { x = at.X + size.X / 2, y = at.Y + size.Y / 2, radius = size.X / 2 }
		end
		local spot = TouchLayout.bat(view.X, view.Y, jump)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Size = UDim2.fromOffset(spot.radius * 2, spot.radius * 2)
		holder.Position = UDim2.fromOffset(spot.x, spot.y)
	end
	local function adopt(candidate: Instance)
		if
			candidate.Name == "JumpButton"
			and candidate:IsA("GuiObject")
			and candidate:FindFirstAncestor("TouchGui")
		then
			jumpButton = candidate
			for _, property in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
				candidate:GetPropertyChangedSignal(property):Connect(place)
			end
			place()
		end
	end
	local playerGui = gui.Parent :: Instance
	playerGui.DescendantAdded:Connect(adopt)
	for _, d in playerGui:GetDescendants() do
		adopt(d)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
end

function Input.start()
	local batSwing = Remotes.get("BatSwing")
	ContextActionService:BindAction("Bat", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			batSwing:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	-- Touch gets the game's own button in place of the stock grey circle, beside the jump button.
	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "FieldButtons"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local bat = Ui.button({
			name = "Bat",
			size = UDim2.fromOffset(96, 96),
			position = UDim2.fromScale(1, 1),
			anchor = Vector2.new(0.5, 0.5),
			color = BAT_RED,
			text = Strings.Bat.button,
			round = true,
			parent = gui,
		})
		bat.Activated:Connect(function()
			batSwing:FireServer()
		end)
		Input.placeBat(gui, bat.Parent :: Frame)
	end
end

return Input
